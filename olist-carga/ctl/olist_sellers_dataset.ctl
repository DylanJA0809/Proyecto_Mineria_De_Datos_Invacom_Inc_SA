-- Carga de olist_sellers_dataset.csv en OLIST_SRC.olist_sellers_dataset con SQL*Loader.
-- CSV WITH EMBEDDED: acepta comillas opcionales y saltos de línea dentro de un campo.
OPTIONS (SKIP=1, ERRORS=100000, DIRECT=TRUE)
LOAD DATA
CHARACTERSET AL32UTF8
INFILE '/opt/oracle/import/olist/olist_sellers_dataset.csv' 
BADFILE '/opt/oracle/import/olist_logs/olist_sellers_dataset.bad'
TRUNCATE
INTO TABLE olist_sellers_dataset
FIELDS CSV WITH EMBEDDED
TRAILING NULLCOLS
(
  seller_id, seller_zip_code_prefix, seller_city, seller_state
)
