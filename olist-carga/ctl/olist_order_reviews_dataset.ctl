-- Carga de olist_order_reviews_dataset.csv en OLIST_SRC.olist_order_reviews_dataset con SQL*Loader.
-- CSV WITH EMBEDDED: acepta comillas opcionales y saltos de línea dentro de un campo.
OPTIONS (SKIP=1, ERRORS=100000, DIRECT=TRUE)
LOAD DATA
CHARACTERSET AL32UTF8
INFILE '/opt/oracle/import/olist/olist_order_reviews_dataset.csv' 
BADFILE '/opt/oracle/import/olist_logs/olist_order_reviews_dataset.bad'
TRUNCATE
INTO TABLE olist_order_reviews_dataset
FIELDS CSV WITH EMBEDDED
TRAILING NULLCOLS
(
  review_id, order_id, review_score, review_comment_title,
  review_comment_message   CHAR(1000),   -- sin esto SQL*Loader corta en 255 bytes, y hay uno de 269 (emojis)
  review_creation_date     DATE "YYYY-MM-DD HH24:MI:SS",
  review_answer_timestamp  DATE "YYYY-MM-DD HH24:MI:SS"
)
