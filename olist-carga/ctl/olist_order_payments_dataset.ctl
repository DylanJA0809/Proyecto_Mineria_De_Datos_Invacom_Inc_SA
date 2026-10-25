-- Carga de olist_order_payments_dataset.csv en OLIST_SRC.olist_order_payments_dataset con SQL*Loader.
-- CSV WITH EMBEDDED: acepta comillas opcionales y saltos de línea dentro de un campo.
OPTIONS (SKIP=1, ERRORS=100000, DIRECT=TRUE)
LOAD DATA
CHARACTERSET AL32UTF8
INFILE '/opt/oracle/import/olist/olist_order_payments_dataset.csv' 
BADFILE '/opt/oracle/import/olist_logs/olist_order_payments_dataset.bad'
TRUNCATE
INTO TABLE olist_order_payments_dataset
FIELDS CSV WITH EMBEDDED
TRAILING NULLCOLS
(
  order_id, payment_sequential, payment_type, payment_installments, payment_value
)
