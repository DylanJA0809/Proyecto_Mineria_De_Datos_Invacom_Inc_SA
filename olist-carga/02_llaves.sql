-- Llaves primarias y foráneas de OLIST_SRC, comprobadas contra los datos el 20 oct 2026.
-- No cambian ningún dato: solo documentan las relaciones (y así DBeaver dibuja el diagrama).
-- Se corre conectado como OLIST_SRC, después de 01_tablas.sql y de la carga.
--
-- Quedan fuera a propósito:
--   * geolocation no tiene PK: el zip se repite (varias coordenadas por zip).
--   * customers/sellers.zip -> geolocation: imposible sin PK, y hay zips sin coordenadas.
--
-- products.category -> translation va como FK declarativa (DISABLE NOVALIDATE): 13 productos de
-- 2 categorías no tienen traducción (pc_gamer, portateis_cozinha_e_preparadores_de_alimentos), así
-- que Oracle no la valida. Solo queda en el catálogo para que el diagrama muestre la relación.

-- Llaves primarias
alter table olist_customers_dataset           add constraint pk_customers   primary key (customer_id);
alter table olist_orders_dataset              add constraint pk_orders      primary key (order_id);
alter table olist_products_dataset            add constraint pk_products    primary key (product_id);
alter table olist_sellers_dataset             add constraint pk_sellers     primary key (seller_id);
alter table product_category_name_translation add constraint pk_translation primary key (product_category_name);
alter table olist_order_items_dataset         add constraint pk_order_items primary key (order_id, order_item_id);
alter table olist_order_payments_dataset      add constraint pk_payments    primary key (order_id, payment_sequential);
-- review_id solo se repite (814): la misma reseña aparece en varios pedidos.
alter table olist_order_reviews_dataset       add constraint pk_reviews     primary key (review_id, order_id);

-- Llaves foráneas
alter table olist_orders_dataset         add constraint fk_orders_customers foreign key (customer_id) references olist_customers_dataset (customer_id);
alter table olist_order_items_dataset    add constraint fk_items_orders     foreign key (order_id)    references olist_orders_dataset (order_id);
alter table olist_order_items_dataset    add constraint fk_items_products   foreign key (product_id)  references olist_products_dataset (product_id);
alter table olist_order_items_dataset    add constraint fk_items_sellers    foreign key (seller_id)   references olist_sellers_dataset (seller_id);
alter table olist_order_payments_dataset add constraint fk_payments_orders  foreign key (order_id)    references olist_orders_dataset (order_id);
alter table olist_order_reviews_dataset  add constraint fk_reviews_orders   foreign key (order_id)    references olist_orders_dataset (order_id);

-- Declarativa: no se valida (ver el encabezado).
alter table olist_products_dataset add constraint fk_products_translation foreign key (product_category_name)
  references product_category_name_translation (product_category_name) disable novalidate;
