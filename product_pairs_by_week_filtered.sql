/*
Retail Product Association Analysis — с фильтрацией
Задача: Найти пару товаров, чаще всего купленных вместе в одном чеке — по каждой неделе.

Фильтрация:
- Только топ-1000 самых популярных товаров за неделю (по числу покупок)
- Только пары, встретившиеся минимум 2 раза за неделю (устойчивые ассоциации)

Поддержка: PostgreSQL, BigQuery
*/

WITH weekly_top_products AS (
  -- Топ-1000 товаров по популярности за каждую неделю
  SELECT
    EXTRACT(YEAR FROM purchase_date) AS year_num,
    EXTRACT(ISOWEEK FROM purchase_date) AS week_num,
    product,
    COUNT(*) AS product_count
  FROM purchases
  GROUP BY year_num, week_num, product
),
top_products_filtered AS (
  SELECT
    year_num,
    week_num,
    product
  FROM weekly_top_products
  WHERE product_count >= 5  -- опционально: минимальная активность товара
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY year_num, week_num
    ORDER BY product_count DESC
  ) <= 1000  -- лимит популярных товаров (настраивается)
),

-- Отфильтрованный набор покупок
filtered_purchases AS (
  SELECT p.*
  FROM purchases p
  JOIN top_products_filtered t
    ON EXTRACT(YEAR FROM p.purchase_date) = t.year_num
    AND EXTRACT(ISOWEEK FROM p.purchase_date) = t.week_num
    AND p.product = t.product
),

-- Генерация пар внутри чеков (только по отфильтрованным товарам)
weekly_pairs AS (
  SELECT
    EXTRACT(YEAR FROM t1.purchase_date) AS year_num,
    EXTRACT(ISOWEEK FROM t1.purchase_date) AS week_num,
    t1.product AS product_a,
    t2.product AS product_b,
    COUNT(*) AS pair_count
  FROM filtered_purchases t1
  JOIN filtered_purchases t2
    ON t1.check_id = t2.check_id
    AND t1.purchase_date = t2.purchase_date
    AND t1.product < t2.product
  GROUP BY year_num, week_num, product_a, product_b
  HAVING COUNT(*) >= 2  -- только пары, встретившиеся минимум 2 раза
),

-- Ранжирование пар внутри недели
ranked_pairs AS (
  SELECT
    year_num,
    week_num,
    product_a,
    product_b,
    pair_count,
    ROW_NUMBER() OVER (
      PARTITION BY year_num, week_num
      ORDER BY pair_count DESC, product_a, product_b
    ) AS rn
  FROM weekly_pairs
)

-- Итог: топ-1 пара за неделю
SELECT
  year_num,
  week_num,
  product_a,
  product_b,
  pair_count AS times_bought_together
FROM ranked_pairs
WHERE rn = 1
ORDER BY year_num, week_num;
