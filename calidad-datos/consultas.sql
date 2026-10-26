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

-- =====================================================================================
-- 6. FECHAS INCONSISTENTES
-- =====================================================================================

-- 6.1 Pedidos entregados al transportista ANTES de ser aprobados.
-- Resultado: 1359 pedidos.
select count(*) carrier_antes_de_aprobar
from   olist_orders_dataset
where  order_delivered_carrier_date < order_approved_at;

-- 6.2 Pedidos entregados al cliente ANTES de salir con el transportista.
-- Resultado: 23 pedidos.
select count(*) entregado_antes_de_enviar
from   olist_orders_dataset
where  order_delivered_customer_date < order_delivered_carrier_date;

-- 6.3 Pedidos "delivered" sin fecha de entrega al cliente.
-- Esperado: 8 pedidos.
select order_id, order_status, order_purchase_timestamp, order_delivered_carrier_date,
       order_delivered_customer_date
from   olist_orders_dataset
where  order_status = 'delivered'
and    order_delivered_customer_date is null;

-- 6.4 Pedidos que NO están "delivered" pero sí tienen fecha de entrega al cliente.
-- Resultado: 6 pedidos. Son pedidos que no fueron entregados pero que tienen fecha de entrega 
-- (error de registro o cancelado despues de entregarse)
select order_id, order_status, order_delivered_customer_date
from   olist_orders_dataset
where  order_status <> 'delivered'
and    order_delivered_customer_date is not null;


-- 6.6 Reseñas respondidas antes de crearse ( Resultado 0).
select count(*) respuesta_antes_de_creacion
from   olist_order_reviews_dataset
where  review_answer_timestamp < review_creation_date;

-- 6.7 Reseñas creadas antes de la compra del pedido. ( Resultado 64).
select count(*) resena_antes_de_compra
from   olist_order_reviews_dataset r
join   olist_orders_dataset        o on o.order_id = r.order_id
where  r.review_creation_date < trunc(o.order_purchase_timestamp);


-- 6.8 Cantidad de pedidos por mes.
--      Sirve para ver en qué meses hay datos completos y en cuáles no. Un mes con muy pocos
--      pedidos (o ninguno) no significa que el negocio vendió poco, sino que los datos están
--      incompletos, y eso distorsiona los reportes por mes.
-- Esperado: 25 meses. Los datos normales van de 2017-01 a 2018-08. Los extremos tienen casi nada:
--           2016-09 (4 pedidos), 2016-12 (1), 2018-09 (16) y 2018-10 (4). 2016-11 no aparece
--           porque ese mes no tiene ningún pedido.
select to_char(order_purchase_timestamp, 'YYYY-MM') anio_mes,
       count(*)                                     cantidad_pedidos
from   olist_orders_dataset
group  by to_char(order_purchase_timestamp, 'YYYY-MM')
order  by anio_mes;


-- =====================================================================================
-- 7. VALORES INVÁLIDOS O RAROS
-- =====================================================================================

-- 7.1 Estados de pedido y su peso (algunos casi no aparecen).
-- Resultado: delivered 96478, shipped 1107, canceled 625, unavailable 609, invoiced 314,
--           processing 301, created 5, approved 2. PCT= %
select order_status, count(*) pedidos,
       round(count(*) * 100 / (select count(*) from olist_orders_dataset), 2) pct
from   olist_orders_dataset
group  by order_status
order  by pedidos desc;

-- 7.2 Tipos de pago. "not_defined" no es un medio de pago real.
-- Resultado: credit_card 76795, boleto 19784, voucher 5775, debit_card 1529, not_defined 3. 
-- (Decidir que hacer con not defined para el DWH)
select payment_type, count(*) pagos, round(sum(payment_value), 2) monto
from   olist_order_payments_dataset
group  by payment_type
order  by pagos desc;

-- 7.3 Pagos con valor cero.
-- Resultado: 9 pagos.
-- 3 pagados con valor 0 pero fueron cancelados
-- 6 pagados en 0 pero por cupones
select p.payment_type,
       o.order_status,
       count(*) pagos_en_cero
from   olist_order_payments_dataset p
join   olist_orders_dataset         o on o.order_id = p.order_id
where  p.payment_value = 0
group  by p.payment_type, o.order_status
order  by p.payment_type, o.order_status;

-- 7.4 Ítems con precio cero o negativo (se espera 0) y con flete en cero.
-- Resultado: flete_cero 383.
select sum(case when price <= 0         then 1 else 0 end) items_vendidos_con_precio_cero_o_negativo,
       sum(case when freight_value = 0  then 1 else 0 end) items_costo_envio_cero,
       sum(case when freight_value < 0  then 1 else 0 end) costo_envio_negativo
from   olist_order_items_dataset;

-- 7.5 Ítems con flete mayor al precio del producto (posible error o producto muy barato).
select count(*) flete_mayor_que_precio
from   olist_order_items_dataset
where  freight_value > price;

-- 7.7 Reseñas con calificación fuera de 1 a 5 (R 0).
select review_score, count(*) resenas
from   olist_order_reviews_dataset
group  by review_score
order  by review_score;

-- 7.8 Códigos postales que no tienen 5 dígitos (Resultado 0).
select 'customers' tabla, count(*) zips_invalidos
from   olist_customers_dataset where length(customer_zip_code_prefix) <> 5
union all
select 'sellers', count(*)
from   olist_sellers_dataset where length(seller_zip_code_prefix) <> 5
union all
select 'geolocation', count(*)
from   olist_geolocation_dataset where length(geolocation_zip_code_prefix) <> 5;

-- 7.9 Estados que no son un código de 2 letras en mayúscula (se espera 0).
select 'customers' tabla, customer_state estado, count(*) filas
from   olist_customers_dataset
where  not regexp_like(customer_state, '^[A-Z]{2}$')
group  by customer_state
union all
select 'sellers', seller_state, count(*)
from   olist_sellers_dataset
where  not regexp_like(seller_state, '^[A-Z]{2}$')
group  by seller_state
union all
select 'geolocation', geolocation_state, count(*)
from   olist_geolocation_dataset
where  not regexp_like(geolocation_state, '^[A-Z]{2}$')
group  by geolocation_state;

-- 7.10 Ciudades de clientes y vendedores con caracteres raros (números, símbolos, tildes mal cargadas).
select 'customers' tabla, customer_city ciudad, count(*) filas
from   olist_customers_dataset
where  regexp_like(customer_city, '[^a-z '' -]')
group  by customer_city
union all
select 'sellers', seller_city, count(*)
from   olist_sellers_dataset
where  regexp_like(seller_city, '[^a-z '' -]')
group  by seller_city
order  by filas desc;

-- 7.11 Ciudades escritas de varias formas (mismo nombre sin espacios ni signos, escrito distinto).
select replace(replace(lower(customer_city), ' ', ''), '-', '') ciudad_normalizada,
       count(distinct customer_city) variantes
from   olist_customers_dataset
group  by replace(replace(lower(customer_city), ' ', ''), '-', '')
having count(distinct customer_city) > 1
order  by variantes desc;

-- 7.12 Productos con medidas o peso extremos (los 10 más pesados).
select *
from  (select product_id, product_category_name, product_weight_g,
              product_length_cm, product_height_cm, product_width_cm
       from   olist_products_dataset
       order  by product_weight_g desc nulls last)
where rownum <= 10;

-- 7.14 Productos con 0 fotos (Resultado 0).
select sum(case when product_photos_qty = 0 then 1 else 0 end) con_cero_fotos
from   olist_products_dataset;


-- =====================================================================================
-- 8. GEOLOCALIZACIÓN (Con esto podemos fundamentar el por que no se uso geolocalizacion)
-- =====================================================================================

-- 8.1 Clientes cuyo código postal no existe en geolocation (no se les puede poner en el mapa).
-- Resultado: 278 clientes.
select count(*) clientes_sin_coordenadas,
       count(distinct c.customer_zip_code_prefix) zips_distintos
from   olist_customers_dataset c
where  not exists (select 1
                   from   olist_geolocation_dataset g
                   where  g.geolocation_zip_code_prefix = c.customer_zip_code_prefix);

-- 8.2 Vendedores cuyo código postal no existe en geolocation.
-- Resultado: 7 vendedores.
select s.seller_id, s.seller_zip_code_prefix, s.seller_city, s.seller_state
from   olist_sellers_dataset s
where  not exists (select 1
                   from   olist_geolocation_dataset g
                   where  g.geolocation_zip_code_prefix = s.seller_zip_code_prefix);

-- =====================================================================================
-- 9. RESUMEN DE TODOS LOS PROBLEMAS
-- =====================================================================================

-- 9.1 Una sola tabla con el conteo de cada problema.

select 'Productos sin categoría' problema, count(*) filas
from   olist_products_dataset where product_category_name is null
union all
select 'Productos con categoría sin traducción', count(*)
from   olist_products_dataset p
where  p.product_category_name is not null
and    not exists (select 1 from product_category_name_translation t
                   where t.product_category_name = p.product_category_name)
union all
select 'Productos con peso nulo o cero', count(*)
from   olist_products_dataset where product_weight_g is null or product_weight_g = 0
union all
select 'Geolocation: filas idénticas repetidas',
       count(*) - count(distinct geolocation_zip_code_prefix || '|' || geolocation_lat || '|' ||
                                 geolocation_lng || '|' || geolocation_city || '|' || geolocation_state)
from   olist_geolocation_dataset
union all
select 'Geolocation: coordenadas fuera de Brasil', count(*)
from   olist_geolocation_dataset
where  geolocation_lat not between -34 and 5.5 or geolocation_lng not between -74 and -34
union all
select 'Reseñas: review_id repetido', count(*) - count(distinct review_id)
from   olist_order_reviews_dataset
union all
select 'Pedidos sin ítems', count(*)
from   olist_orders_dataset o
where  not exists (select 1 from olist_order_items_dataset i where i.order_id = o.order_id)
union all
select 'Pedidos sin pagos', count(*)
from   olist_orders_dataset o
where  not exists (select 1 from olist_order_payments_dataset p where p.order_id = o.order_id)
union all
select 'Pedidos sin reseña', count(*)
from   olist_orders_dataset o
where  not exists (select 1 from olist_order_reviews_dataset r where r.order_id = o.order_id)
union all
select 'Pedidos delivered sin fecha de entrega', count(*)
from   olist_orders_dataset where order_status = 'delivered' and order_delivered_customer_date is null
union all
select 'Pedidos no delivered con fecha de entrega', count(*)
from   olist_orders_dataset where order_status <> 'delivered' and order_delivered_customer_date is not null
union all
select 'Pedidos con transportista antes de aprobación', count(*)
from   olist_orders_dataset where order_delivered_carrier_date < order_approved_at
union all
select 'Pedidos con entrega al cliente antes del transportista', count(*)
from   olist_orders_dataset where order_delivered_customer_date < order_delivered_carrier_date
union all
select 'Pagos con valor cero', count(*)
from   olist_order_payments_dataset where payment_value = 0
union all
select 'Pagos con 0 cuotas', count(*)
from   olist_order_payments_dataset where payment_installments = 0
union all
select 'Pagos tipo not_defined', count(*)
from   olist_order_payments_dataset where payment_type = 'not_defined'
union all
select 'Clientes sin coordenadas en geolocation', count(*)
from   olist_customers_dataset c
where  not exists (select 1 from olist_geolocation_dataset g
                   where g.geolocation_zip_code_prefix = c.customer_zip_code_prefix)
union all
select 'Vendedores sin coordenadas en geolocation', count(*)
from   olist_sellers_dataset s
where  not exists (select 1 from olist_geolocation_dataset g
                   where g.geolocation_zip_code_prefix = s.seller_zip_code_prefix);



-- =====================================================================================
-- 10. POR QUÉ NO SE USA LA TABLA olist_geolocation_dataset
-- =====================================================================================
-- Esta tabla se revisó, pero no se va a usar en el modelo. Los motivos son estos:
--
-- 1. No tiene llave primaria. El código postal (zip) se repite muchas veces, así que ninguna
--    columna identifica una fila. Por eso no se puede declarar una llave foránea desde
--    clientes ni vendedores hacia esta tabla.
--
-- 2. Un zip no es un solo lugar. Tiene 1.000.163 filas, pero solo 19.015 zips distintos
--    (unas 53 filas por zip en promedio, y hasta 1.146 en el zip con más filas). Si se une
--    con clientes o vendedores por el zip, cada uno se multiplicaría por esas filas y se
--    inflarían los conteos y las ventas. (Consulta 3.2)
--
-- 3. Tiene muchas filas repetidas. 261.831 filas (26,2 %) son copias exactas de otra: mismo
--    zip, latitud, longitud, ciudad y estado. (Consulta 3.1)
--
-- 4. Es la tabla más pesada (61 MB en CSV, más del triple que la de pedidos, que pesa 17,7 MB)
--    y no tiene datos de ventas. Solo agrega coordenadas.
--
-- 5. No cubre a todos los clientes y vendedores. 278 clientes y 7 vendedores tienen un zip
--    que no existe en esta tabla, así que de todos modos quedarían sin coordenadas.
--    (Consultas 8.1 y 8.2)
--
-- 6. Tiene coordenadas inválidas: 42 filas están fuera de Brasil, y los nombres de ciudad
--    traen tildes y caracteres que no coinciden con los de las otras tablas.
--
-- 7. La ubicación ya está en otras tablas. Clientes y vendedores traen ciudad, estado y zip,
--    que alcanza para analizar ventas por región. Las coordenadas solo harían falta para
--    dibujar un mapa.