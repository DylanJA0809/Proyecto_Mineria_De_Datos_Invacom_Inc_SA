-- Vistas de extraccion: una por tabla del DW (dim_fecha no lleva, se genera).
-- Correr como OLIST_SRC en XEPDB1.
--
-- Cada vista tiene la forma de su tabla en OLIST_DW: una fila por llave natural y los nombres del
-- DDL. En vez de las llaves sustitutas van las naturales; el job de hechos las busca en las
-- dimensiones.
-- La limpieza de docs/calidad-datos.md la hace Glue (sin_categoria, traducciones que faltan,
-- NULLIF del peso, ciudades), por eso aqui todavia salen los datos como vienen.

create or replace view v_dim_cliente as
select customer_unique_id,
       ciudad,
       estado,
       case when pedidos > 1 then 'S' else 'N' end as recompra
from (
    select c.customer_unique_id,
           c.customer_city  as ciudad,
           c.customer_state as estado,
           count(*) over (partition by c.customer_unique_id) as pedidos,
           -- la ciudad y el estado salen del pedido mas reciente
           row_number() over (partition by c.customer_unique_id
                              order by o.order_purchase_timestamp desc, o.order_id desc) as n
    from olist_customers_dataset c
    join olist_orders_dataset o on o.customer_id = c.customer_id
)
where n = 1;

create or replace view v_dim_vendedor as
select seller_id,
       seller_city  as ciudad,
       seller_state as estado
from olist_sellers_dataset;

create or replace view v_dim_producto as
select p.product_id,
       t.product_category_name_english as categoria,
       p.product_weight_g as peso_g,
       case
           when nvl(p.product_weight_g, 0) = 0 then 'Sin peso'
           when p.product_weight_g < 500       then '< 500 g'
           when p.product_weight_g < 2000      then '500g - 2kg'
           when p.product_weight_g < 10000     then '2kg - 10kg'
           else '10kg o más'
       end as rango_peso
from olist_products_dataset p
left join product_category_name_translation t
       on t.product_category_name = p.product_category_name;

create or replace view v_fact_ventas as
with resena as (
    -- si el pedido tiene varias resenas, la mas reciente (problema 9a)
    select order_id,
           review_score,
           row_number() over (partition by order_id
                              order by review_creation_date desc,
                                       review_answer_timestamp desc,
                                       review_id desc) as n
    from olist_order_reviews_dataset
)
select to_number(to_char(o.order_purchase_timestamp, 'YYYYMMDD')) as fecha_key,
       c.customer_unique_id,
       i.product_id,
       i.seller_id,
       i.order_id,
       i.order_item_id,
       o.order_status  as estado_pedido,
       i.price         as precio,
       i.freight_value as flete,
       to_number(to_char(o.order_purchase_timestamp, 'HH24')) as hora_compra,
       trunc(o.order_delivered_customer_date) - trunc(o.order_purchase_timestamp)       as dias_entrega,
       trunc(o.order_delivered_customer_date) - trunc(o.order_estimated_delivery_date)  as dias_atraso,
       case
           when o.order_delivered_customer_date is null then null
           when trunc(o.order_delivered_customer_date) <= trunc(o.order_estimated_delivery_date) then 'S'
           else 'N'
       end as a_tiempo,
       r.review_score as puntaje_resena
from olist_order_items_dataset i
join olist_orders_dataset o    on o.order_id = i.order_id
join olist_customers_dataset c on c.customer_id = o.customer_id
left join resena r             on r.order_id = i.order_id and r.n = 1;

-- Glue y el grupo leen por el rol
grant select on v_dim_cliente  to olist_lector;
grant select on v_dim_vendedor to olist_lector;
grant select on v_dim_producto to olist_lector;
grant select on v_fact_ventas  to olist_lector;
