-- Carga de olist_geolocation_dataset.csv en OLIST_SRC.olist_geolocation_dataset con SQL*Loader.
-- CSV WITH EMBEDDED: acepta comillas opcionales y saltos de línea dentro de un campo.
OPTIONS (SKIP=1, ERRORS=100000, DIRECT=TRUE)
LOAD DATA
CHARACTERSET AL32UTF8
INFILE '/opt/oracle/import/olist/olist_geolocation_dataset.csv' 
BADFILE '/opt/oracle/import/olist_logs/olist_geolocation_dataset.bad'
TRUNCATE
INTO TABLE olist_geolocation_dataset
FIELDS CSV WITH EMBEDDED
TRAILING NULLCOLS
(
  geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state
)
