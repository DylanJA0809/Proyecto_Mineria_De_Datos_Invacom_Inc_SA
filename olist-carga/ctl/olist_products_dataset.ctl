-- Carga de olist_products_dataset.csv en OLIST_SRC.olist_products_dataset con SQL*Loader.
-- CSV WITH EMBEDDED: acepta comillas opcionales y saltos de línea dentro de un campo.
OPTIONS (SKIP=1, ERRORS=100000, DIRECT=TRUE)
LOAD DATA
CHARACTERSET AL32UTF8
INFILE '/opt/oracle/import/olist/olist_products_dataset.csv' 
BADFILE '/opt/oracle/import/olist_logs/olist_products_dataset.bad'
TRUNCATE
INTO TABLE olist_products_dataset
FIELDS CSV WITH EMBEDDED
TRAILING NULLCOLS
(
  product_id, product_category_name, product_name_lenght, product_description_lenght,
  product_photos_qty, product_weight_g, product_length_cm, product_height_cm, product_width_cm
)
