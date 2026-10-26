-- =====================================================================================
-- CALIDAD DE DATOS - base FUENTE OLIST_SRC
-- Archivo: calidad-datos/consultas.sql
--
-- Contenido:
--   1. Volumen por tabla
--   2. Nulos
--   3. Duplicados
--   4. Productos sin categoría / sin traducción
--   5. Integridad entre tablas (huérfanos y pedidos incompletos)
--   6. Fechas inconsistentes
--   7. Valores inválidos o raros
--   8. Geolocalización
--   9. Resumen de todos los problemas
--	10. Por qué no se usara la tabla olist_geolocation_dataset

-- =====================================================================================
-- 1. VOLUMEN POR TABLA
-- =====================================================================================

-- 1.1 Filas por tabla (para comparar contra el CSV y contra el DWH después del ETL).
-- Resultado: customers 99441, geolocation 1000163, orders 99441, order_items 112650,
--           payments 103886, reviews 99224, products 32951, sellers 3095, translation 71.
select 'olist_customers_dataset' tabla, count(*) filas from olist_customers_dataset
union all select 'olist_geolocation_dataset',      count(*) from olist_geolocation_dataset
union all select 'olist_orders_dataset',           count(*) from olist_orders_dataset
union all select 'olist_order_items_dataset',      count(*) from olist_order_items_dataset
union all select 'olist_order_payments_dataset',   count(*) from olist_order_payments_dataset
union all select 'olist_order_reviews_dataset',    count(*) from olist_order_reviews_dataset
union all select 'olist_products_dataset',         count(*) from olist_products_dataset
union all select 'olist_sellers_dataset',          count(*) from olist_sellers_dataset
union all select 'product_category_name_translation', count(*) from product_category_name_translation;


-- =====================================================================================
-- 2. NULOS
-- =====================================================================================

-- 2.1 Pedidos: fechas nulas. Algunas son normales (un pedido cancelado nunca se entrega),
--     otras no (ver 6.4 y 6.5).
-- Resultado: sin_aprobacion 160, sin_entrega_transportista 1783, sin_entrega_cliente 2965.
select count(*)                                                       total_pedidos,
       sum(case when order_approved_at             is null then 1 else 0 end) sin_aprobacion,
       sum(case when order_delivered_carrier_date  is null then 1 else 0 end) sin_entrega_transportista,
       sum(case when order_delivered_customer_date is null then 1 else 0 end) sin_entrega_cliente
from   olist_orders_dataset;

-- 2.2 Pedidos con fecha nula, según el estado del pedido.
select order_status,
       count(*)                                                       pedidos,
       sum(case when order_approved_at             is null then 1 else 0 end) sin_aprobacion,
       sum(case when order_delivered_carrier_date  is null then 1 else 0 end) sin_transportista,
       sum(case when order_delivered_customer_date is null then 1 else 0 end) sin_entrega_cliente
from   olist_orders_dataset
group  by order_status
order  by pedidos desc;

-- 2.3 Productos: columnas nulas.
-- Resultado: sin_categoria 610, sin_nombre_lenght 610, sin_descripcion_lenght 610,
--           sin_fotos 610, sin_peso 2, sin_largo 2, sin_alto 2, sin_ancho 2.
select count(*)                                                        total_productos,
       sum(case when product_category_name      is null then 1 else 0 end) sin_categoria,
       sum(case when product_name_lenght        is null then 1 else 0 end) sin_nombre_lenght,
       sum(case when product_description_lenght is null then 1 else 0 end) sin_descripcion_lenght,
       sum(case when product_photos_qty         is null then 1 else 0 end) sin_fotos,
       sum(case when product_weight_g           is null then 1 else 0 end) sin_peso,
       sum(case when product_length_cm          is null then 1 else 0 end) sin_largo,
       sum(case when product_height_cm          is null then 1 else 0 end) sin_alto,
       sum(case when product_width_cm           is null then 1 else 0 end) sin_ancho
from   olist_products_dataset;

-- 2.4 Reseñas: título y mensaje vacíos (son opcionales, pero hay que tenerlo presente).
--     Nota: en Oracle una cadena vacía se guarda como NULL.
-- Resultado: sin_titulo 87656, sin_mensaje 58247.
select count(*)                                                        total_resenas,
       sum(case when review_comment_title   is null then 1 else 0 end) sin_titulo,
       sum(case when review_comment_message is null then 1 else 0 end) sin_mensaje
from   olist_order_reviews_dataset;

-- 2.5 Conteo de nulos en el resto de tablas (resultado 0 en todas).
select 'customers' tabla,
       sum(case when customer_unique_id       is null then 1 else 0 end)
     + sum(case when customer_zip_code_prefix is null then 1 else 0 end)
     + sum(case when customer_city            is null then 1 else 0 end)
     + sum(case when customer_state           is null then 1 else 0 end) nulos
from   olist_customers_dataset
union all
select 'sellers',
       sum(case when seller_zip_code_prefix is null then 1 else 0 end)
     + sum(case when seller_city            is null then 1 else 0 end)
     + sum(case when seller_state           is null then 1 else 0 end)
from   olist_sellers_dataset
union all
select 'order_items',
       sum(case when price         is null then 1 else 0 end)
     + sum(case when freight_value is null then 1 else 0 end)
     + sum(case when shipping_limit_date is null then 1 else 0 end)
from   olist_order_items_dataset
union all
select 'payments',
       sum(case when payment_type         is null then 1 else 0 end)
     + sum(case when payment_installments is null then 1 else 0 end)
     + sum(case when payment_value        is null then 1 else 0 end)
from   olist_order_payments_dataset
union all
select 'geolocation',
       sum(case when geolocation_lat  is null then 1 else 0 end)
     + sum(case when geolocation_lng  is null then 1 else 0 end)
     + sum(case when geolocation_city is null then 1 else 0 end)
from   olist_geolocation_dataset;


-- =====================================================================================
-- 3. DUPLICADOS
-- =====================================================================================

-- 3.1 Geolocalización: filas completamente idénticas (no tiene PK).
-- Resultado: filas_repetidas 261831 (de 1000163 filas).
select count(*) - count(distinct geolocation_zip_code_prefix || '|' || geolocation_lat || '|' ||
                                 geolocation_lng || '|' || geolocation_city || '|' || geolocation_state)
       filas_repetidas
from   olist_geolocation_dataset;

-- 3.2 Geolocalización: zips con muchas coordenadas (por eso no puede ser llave).
-- Los 15 zips con más filas.
select *
from  (select geolocation_zip_code_prefix zip,
              count(*)                                filas,
              count(distinct geolocation_lat || geolocation_lng) coordenadas_distintas
       from   olist_geolocation_dataset
       group  by geolocation_zip_code_prefix
       order  by filas desc)
where rownum <= 15;

-- 3.3 Reseñas: review_id repetido (la misma reseña ligada a varios pedidos).
-- Resultado: 814 filas de más (por eso la PK es review_id + order_id).
select count(*) - count(distinct review_id) review_id_repetidos
from   olist_order_reviews_dataset;

-- 3.4 Detalle de los review_id repetidos (los primeros 20).
select *
from  (select review_id, count(*) veces, count(distinct order_id) pedidos
       from   olist_order_reviews_dataset
       group  by review_id
       having count(*) > 1
       order  by veces desc)
where rownum <= 20;

-- 3.5 Pedidos con más de una reseña.
-- Resultado: 547 pedidos.
select count(*) pedidos_con_varias_resenas
from  (select order_id
       from   olist_order_reviews_dataset
       group  by order_id
       having count(*) > 1);

-- 3.6 Clientes: customer_unique_id repetido. Es normal (el mismo cliente real tiene un
--     customer_id distinto en cada compra), pero para eñ DWH debemos contar clientes con unique_id.
-- Resultado: clientes_reales 96096 vs customer_id 99441.
select count(distinct customer_unique_id) clientes_reales,
       count(distinct customer_id)        customer_id_distintos
from   olist_customers_dataset;

-- 3.7 Clientes reales con más de un customer_id (los que más compraron, se les genera un custumer_id por compra).
select *
from  (select customer_unique_id, count(*) customer_ids
       from   olist_customers_dataset
       group  by customer_unique_id
       having count(*) > 1
       order  by customer_ids desc)
where rownum <= 15;

-- =====================================================================================
-- 4. PRODUCTOS SIN CATEGORÍA / SIN TRADUCCIÓN
-- =====================================================================================

-- 4.1 Productos sin categoría.
-- Resultado: 610 productos
select count(*) sin_categoria
from   olist_products_dataset
where  product_category_name is null;

-- 4.2 Productos sin categoría que sí se vendieron (estos afectan los reportes de ventas por categoría).
select count(distinct p.product_id) productos_vendidos_sin_categoria,
       count(*)                     items_vendidos,
       sum(i.price)                 monto_vendido
from   olist_order_items_dataset i
join   olist_products_dataset    p on p.product_id = i.product_id
where  p.product_category_name is null;

-- 4.3 Categorías de productos que no tienen traducción al inglés.
-- Resultado: 13 productos de 2 categorías (pc_gamer y portateis_cozinha_e_preparadores_de_alimentos).
select p.product_category_name, count(*) productos
from   olist_products_dataset p
where  p.product_category_name is not null
and    not exists (select 1
                   from   product_category_name_translation t
                   where  t.product_category_name = p.product_category_name)
group  by p.product_category_name
order  by productos desc;

-- 4.4 Productos sin categoría Y sin datos de nombre/descripción/fotos (a los 610 les falta eso).
-- Resultado: 610 (los nulos vienen todos en las mismas filas).
select count(*) productos_sin_metadatos
from   olist_products_dataset
where  product_category_name      is null
and    product_name_lenght        is null
and    product_description_lenght is null
and    product_photos_qty         is null;

-- 4.5 Productos con peso o medidas nulas o en cero (no sirven para calcular flete ni volumen).
-- Resultado: 2 con peso nulo y 4 con peso 0.
select sum(case when product_weight_g  is null then 1 else 0 end) peso_nulo,
       sum(case when product_weight_g  = 0     then 1 else 0 end) peso_cero,
       sum(case when product_length_cm is null then 1 else 0 end) largo_nulo,
       sum(case when product_height_cm is null then 1 else 0 end) alto_nulo,
       sum(case when product_width_cm  is null then 1 else 0 end) ancho_nulo
from   olist_products_dataset;

-- 4.6 Traducciones que ningún producto usa (se resultado 0).
select t.product_category_name
from   product_category_name_translation t
where  not exists (select 1
                   from   olist_products_dataset p
                   where  p.product_category_name = t.product_category_name);


-- =====================================================================================
-- 5. INTEGRIDAD ENTRE TABLAS (HUÉRFANOS Y PEDIDOS INCOMPLETOS)
-- =====================================================================================

-- 5.1 Pedidos sin ningún ítem.
-- Resultado: 775 pedidos, unavailable: 603, canceled: 164, created: 5, invoiced: 2, shipped: 1.
select o.order_status, count(*) pedidos_sin_items
from   olist_orders_dataset o
where  not exists (select 1 from olist_order_items_dataset i where i.order_id = o.order_id)
group  by o.order_status
order  by pedidos_sin_items desc;

-- 5.2 Pedidos sin pagos.
-- Resultado: 1 pedido
-- Esta en delivered y tiene 3 ítems, pero no tiene ningún pago registrado
-- Para el ETL, la decisión está en qué hacer con el:
-- Dejarlo y que su monto pagado quede en cero o nulo.
-- Descartarlo del DWH, porque es un solo pedido y no pesa en los resultados.
select o.order_id, o.order_status, o.order_purchase_timestamp
from   olist_orders_dataset o
where  not exists (select 1 from olist_order_payments_dataset p where p.order_id = o.order_id);

-- 5.3 Pedidos sin reseña.
-- Resultado: 768 pedidos.
select count(*) pedidos_sin_resena
from   olist_orders_dataset o
where  not exists (select 1 from olist_order_reviews_dataset r where r.order_id = o.order_id);

-- 5.4 Pedidos sin reseña, por estado (los entregados sin reseña es lo mas normal).
select o.order_status, count(*) pedidos
from   olist_orders_dataset o
where  not exists (select 1 from olist_order_reviews_dataset r where r.order_id = o.order_id)
group  by o.order_status
order  by pedidos desc;

-- 5.5 Vendedores sin ventas.
select count(*) vendedores_sin_ventas
from   olist_sellers_dataset s
where  not exists (select 1 from olist_order_items_dataset i where i.seller_id = s.seller_id);

-- 5.6 Pedidos donde lo cobrado no cuadra con lo vendido (suma de price + freight vs suma de pagos).
-- Se tolera 1 unidad de diferencia por redondeo.
-- Resultado: 249 pedidos con diferencia mayor a 1.
select count(*) pedidos_descuadrados
from  (select i.order_id, i.total_items, p.total_pagos
       from  (select order_id, sum(price + freight_value) total_items
              from   olist_order_items_dataset group by order_id) i
       join  (select order_id, sum(payment_value) total_pagos
              from   olist_order_payments_dataset group by order_id) p
         on  p.order_id = i.order_id
       where abs(i.total_items - p.total_pagos) > 1);

-- 5.7 Detalle de los 20 pedidos con mayor diferencia.
select *
from  (select i.order_id, i.total_items, p.total_pagos,
              round(p.total_pagos - i.total_items, 2) diferencia
       from  (select order_id, sum(price + freight_value) total_items
              from   olist_order_items_dataset group by order_id) i
       join  (select order_id, sum(payment_value) total_pagos
              from   olist_order_payments_dataset group by order_id) p
         on  p.order_id = i.order_id
       where abs(i.total_items - p.total_pagos) > 1
       order by abs(p.total_pagos - i.total_items) desc)
where rownum <= 20;


