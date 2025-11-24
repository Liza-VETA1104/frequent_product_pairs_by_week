WITH weekly_pairs AS (
  -- самоджойн по чеку и неделе, чтобы получить все пары товаров
  SELECT
    EXTRACT(ISOWEEK FROM t1.purchase_date) AS week_num,
    EXTRACT(YEAR FROM t1.purchase_date) AS year_num,  -- важно: неделя 1 в 2024 ≠ неделе 1 в 2025
    t1.product AS product_a,
    t2.product AS product_b,
    COUNT(*) AS pair_count
  FROM purchases t1
  JOIN purchases t2
    ON t1.check_id = t2.check_id
    AND t1.product < t2.product  -- гарантирует уникальность пары: (A,B), исключает (B,A) и (A,A)
  GROUP BY
    year_num,
    week_num,
    product_a,
    product_b
),
ranked_pairs AS (
  -- ранжируем пары по частоте внутри каждой недели
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
--: берём только самую частую пару за неделю
SELECT
  year_num,
  week_num,
  product_a,
  product_b,
  pair_count AS times_bought_together
FROM ranked_pairs
WHERE rn = 1
ORDER BY year_num, week_num;
