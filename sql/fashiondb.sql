CREATE OR REPLACE VIEW vw_fashion_final AS
WITH bc_avg AS (
  SELECT brand, category, AVG(NULLIF(customer_rating,'')) AS avg_rating
  FROM fashion_dataset
  WHERE NULLIF(customer_rating,'') IS NOT NULL
  GROUP BY brand, category
),
glob AS (
  SELECT AVG(NULLIF(customer_rating,'')) AS global_avg
  FROM fashion_dataset
  WHERE NULLIF(customer_rating,'') IS NOT NULL
)
SELECT
  f.product_id,
  f.category,
  
  -- Brand cleaning
  CASE
    WHEN LOWER(TRIM(REPLACE(f.brand,'_',' '))) IN ('hm','h&m','h and m') THEN 'H&M'
    WHEN LOWER(TRIM(REPLACE(f.brand,'_',' '))) = 'banana republic'       THEN 'Banana Republic'
    WHEN LOWER(TRIM(REPLACE(f.brand,'_',' '))) IN ('forever 21','forever21') THEN 'Forever21'
    WHEN LOWER(TRIM(REPLACE(f.brand,'_',' '))) IN ('ann taylor','anntaylor') THEN 'Ann Taylor'
    ELSE CONCAT(
           UPPER(LEFT(LOWER(TRIM(REPLACE(f.brand,'_',' '))),1)),
           SUBSTRING(LOWER(TRIM(REPLACE(f.brand,'_',' '))),2)
         )
  END AS brand_clean,

  f.season,
  f.size_imputed,
  f.color,
  f.original_price,
  f.markdown_percentage,
  f.current_price,
  f.purchase_date,
  f.stock_quantity,
  
  -- Rating imputation
  COALESCE(NULLIF(f.customer_rating,''), bc_avg.avg_rating, glob.global_avg) AS customer_rating,

  f.is_returned,

  -- Return reason cleaning
  CASE
    WHEN LOWER(TRIM(REPLACE(f.return_reason,'_',' '))) = 'size issue'     THEN 'Size Issue'
    WHEN LOWER(TRIM(REPLACE(f.return_reason,'_',' '))) = 'quality issue'  THEN 'Quality Issue'
    WHEN LOWER(TRIM(REPLACE(f.return_reason,'_',' '))) = 'color mismatch' THEN 'Color Mismatch'
    WHEN LOWER(TRIM(REPLACE(f.return_reason,'_',' '))) = 'damaged'        THEN 'Damaged'
    WHEN LOWER(TRIM(REPLACE(f.return_reason,'_',' '))) = 'changed mind'   THEN 'Changed Mind'
    WHEN LOWER(TRIM(REPLACE(f.return_reason,'_',' '))) = 'wrong item'     THEN 'Wrong Item'
    ELSE CONCAT(
           UPPER(LEFT(LOWER(TRIM(REPLACE(f.return_reason,'_',' '))),1)),
           SUBSTRING(LOWER(TRIM(REPLACE(f.return_reason,'_',' '))),2)
         )
  END AS return_reason_clean,

  -- Markdown normalization + price audit
  CASE WHEN f.markdown_percentage > 1 THEN f.markdown_percentage/100 ELSE f.markdown_percentage END AS md_fraction,
  ROUND(f.original_price * (1 - (CASE WHEN f.markdown_percentage > 1 THEN f.markdown_percentage/100 ELSE f.markdown_percentage END)), 2) AS expected_price,
  ROUND(f.current_price - ROUND(f.original_price * (1 - (CASE WHEN f.markdown_percentage > 1 THEN f.markdown_percentage/100 ELSE f.markdown_percentage END)), 2), 2) AS price_delta,
  CASE 
    WHEN ABS(f.current_price - ROUND(f.original_price * (1 - (CASE WHEN f.markdown_percentage > 1 THEN f.markdown_percentage/100 ELSE f.markdown_percentage END)), 2)) <= 0.05
    THEN 'OK' ELSE 'Mismatch'
  END AS price_flag

FROM fashion_dataset f
LEFT JOIN bc_avg ON f.brand=bc_avg.brand AND f.category=bc_avg.category
CROSS JOIN glob;

SELECT * FROM vw_fashion_kpis;

SELECT f.*, k.total_rows, k.avg_original_price, k.avg_current_price, 
       k.avg_rating AS kpi_avg_rating, k.return_rate, k.sell_through_rate, k.price_mismatch_rate
FROM vw_fashion_final f
LEFT JOIN vw_fashion_kpis k
  ON f.brand_clean = k.brand_clean
 AND f.category = k.category
 AND f.season = k.season;
 
update fashion_dataset SET size_imputed = 'Unknown' WHERE size_imputed IS NULL OR size_imputed IN ('N/A', 'NA', 'na');



