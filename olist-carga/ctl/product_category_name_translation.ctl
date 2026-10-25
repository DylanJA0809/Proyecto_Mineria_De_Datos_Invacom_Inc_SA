-- Carga de product_category_name_translation.csv en OLIST_SRC.product_category_name_translation con SQL*Loader.
-- Este archivo viene con fin de línea de Windows (CRLF) y BOM: por eso el STR '\r\n'.
-- CSV WITH EMBEDDED: acepta comillas opcionales y saltos de línea dentro de un campo.
OPTIONS (SKIP=1, ERRORS=100000, DIRECT=TRUE)
LOAD DATA
CHARACTERSET AL32UTF8
INFILE '/opt/oracle/import/olist/product_category_name_translation.csv' "STR '\r\n'"
BADFILE '/opt/oracle/import/olist_logs/product_category_name_translation.bad'
TRUNCATE
INTO TABLE product_category_name_translation
FIELDS CSV WITH EMBEDDED
TRAILING NULLCOLS
(
  product_category_name, product_category_name_english
)
