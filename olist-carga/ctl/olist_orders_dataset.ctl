-- Carga de olist_orders_dataset.csv en OLIST_SRC.olist_orders_dataset con SQL*Loader.
-- CSV WITH EMBEDDED: acepta comillas opcionales y saltos de línea dentro de un campo.
OPTIONS (SKIP=1, ERRORS=100000, DIRECT=TRUE)
LOAD DATA
CHARACTERSET AL32UTF8
INFILE '/opt/oracle/import/olist/olist_orders_dataset.csv' 
BADFILE '/opt/oracle/import/olist_logs/olist_orders_dataset.bad'
TRUNCATE
INTO TABLE olist_orders_dataset
FIELDS CSV WITH EMBEDDED
TRAILING NULLCOLS
(
  order_id, customer_id, order_status,
  order_purchase_timestamp       DATE "YYYY-MM-DD HH24:MI:SS",
  order_approved_at              DATE "YYYY-MM-DD HH24:MI:SS",
  order_delivered_carrier_date   DATE "YYYY-MM-DD HH24:MI:SS",
  order_delivered_customer_date  DATE "YYYY-MM-DD HH24:MI:SS",
  order_estimated_delivery_date  DATE "YYYY-MM-DD HH24:MI:SS"
)
