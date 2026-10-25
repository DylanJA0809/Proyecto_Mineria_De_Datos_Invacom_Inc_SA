-- Carga de olist_customers_dataset.csv en OLIST_SRC.olist_customers_dataset con SQL*Loader.
-- CSV WITH EMBEDDED: acepta comillas opcionales y saltos de línea dentro de un campo.
OPTIONS (SKIP=1, ERRORS=100000, DIRECT=TRUE)
LOAD DATA
CHARACTERSET AL32UTF8
INFILE '/opt/oracle/import/olist/olist_customers_dataset.csv' 
BADFILE '/opt/oracle/import/olist_logs/olist_customers_dataset.bad'
TRUNCATE
INTO TABLE olist_customers_dataset
FIELDS CSV WITH EMBEDDED
TRAILING NULLCOLS
(
  customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state
)
