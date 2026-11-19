{{ config(materialized='table') }}

select distinct
    customer_id,
    customer_name,
    country
from {{ ref('int_ecommerce_sales') }}