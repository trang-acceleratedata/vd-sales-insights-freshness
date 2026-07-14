{{ config(materialized='view') }}

WITH

source AS (
  SELECT * FROM {{ source('raw', 'orders') }}
),

renamed AS (
  SELECT
    order_id,
    customer_id,
    CAST(order_date AS DATE)        AS order_date,
    LOWER(order_status)             AS order_status,
    CAST(amount AS DECIMAL(12, 2))  AS amount
  FROM source
),

-- Revenue-bearing orders only: pending and cancelled orders are excluded
-- from revenue per the intent's acceptance rule (intents/sales-insights).
filtered AS (
  SELECT *
  FROM renamed
  WHERE order_status IN ('shipped', 'delivered', 'returned')
)

SELECT * FROM filtered
