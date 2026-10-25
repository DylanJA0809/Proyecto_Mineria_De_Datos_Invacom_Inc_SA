-- Esquema OLIST_SRC: la base FUENTE del proyecto (grupo 01, olist_ecommerce).
-- Las tablas reflejan los CSV tal cual: mismos nombres de tabla y columna (incluido el
-- "lenght" mal escrito de products) y sin limpiar nada. La limpieza le toca al ETL.
-- Se corre conectado como OLIST_SRC.

create table olist_customers_dataset (
  customer_id               varchar2(32),
  customer_unique_id        varchar2(32),
  customer_zip_code_prefix  varchar2(5),   -- texto: trae ceros a la izquierda
  customer_city             varchar2(100),
  customer_state            varchar2(2)
);

create table olist_geolocation_dataset (
  geolocation_zip_code_prefix  varchar2(5),
  geolocation_lat              number,
  geolocation_lng              number,
  geolocation_city             varchar2(100),
  geolocation_state            varchar2(2)
);

create table olist_orders_dataset (
  order_id                       varchar2(32),
  customer_id                    varchar2(32),
  order_status                   varchar2(20),
  order_purchase_timestamp       date,
  order_approved_at              date,
  order_delivered_carrier_date   date,
  order_delivered_customer_date  date,
  order_estimated_delivery_date  date
);

create table olist_order_items_dataset (
  order_id             varchar2(32),
  order_item_id        number(3),
  product_id           varchar2(32),
  seller_id            varchar2(32),
  shipping_limit_date  date,
  price                number(10,2),
  freight_value        number(10,2)
);

create table olist_order_payments_dataset (
  order_id              varchar2(32),
  payment_sequential    number(3),
  payment_type          varchar2(20),
  payment_installments  number(3),
  payment_value         number(10,2)
);

create table olist_order_reviews_dataset (
  review_id                varchar2(32),
  order_id                 varchar2(32),
  review_score             number(1),
  review_comment_title     varchar2(200),
  review_comment_message   varchar2(1000),
  review_creation_date     date,
  review_answer_timestamp  date
);

create table olist_products_dataset (
  product_id                  varchar2(32),
  product_category_name       varchar2(100),
  product_name_lenght         number(5),
  product_description_lenght  number(5),
  product_photos_qty          number(3),
  product_weight_g            number(7),
  product_length_cm           number(5),
  product_height_cm           number(5),
  product_width_cm            number(5)
);

create table olist_sellers_dataset (
  seller_id               varchar2(32),
  seller_zip_code_prefix  varchar2(5),
  seller_city             varchar2(100),
  seller_state            varchar2(2)
);

create table product_category_name_translation (
  product_category_name          varchar2(100),
  product_category_name_english  varchar2(100)
);
