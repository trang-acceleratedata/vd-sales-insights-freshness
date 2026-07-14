{{ config(materialized='table') }}

WITH

orders AS (
  SELECT * FROM {{ ref('stg_orders') }}
),

monthly AS (
  SELECT
    DATE_TRUNC('month', order_date)  AS sales_month,
    SUM(amount)                      AS total_revenue,
    COUNT(*)                         AS order_count
  FROM orders
  GROUP BY 1
),

final AS (
  -- one row per calendar month
  SELECT
    sales_month,
    total_revenue,
    order_count,
    CURRENT_TIMESTAMP                AS _loaded_at,
    '{{ invocation_id }}'            AS _dbt_invocation_id,
    '{{ var("git_sha") }}'           AS _git_sha
  FROM monthly
)

SELECT * FROM final
