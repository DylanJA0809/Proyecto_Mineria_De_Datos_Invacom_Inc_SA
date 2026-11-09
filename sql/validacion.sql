-- Validación del DW contra la fuente.
-- Correr como usuario[olist_dw] en XEPDB1 (OLIST_DW lee OLIST_SRC por el rol olist_lector).
-- Una fila por prueba: OK si lo obtenido es igual a lo esperado.

with pruebas as (
    -- 1. Conteos
    select 1 n, 'dim_fecha: un dia por fila, 2016 a 2018' prueba,
           date '2018-12-31' - date '2016-01-01' + 1 esperado,
           (select count(*) from dim_fecha) obtenido
    from dual
    union all
    select 2, 'dim_cliente: una fila por customer_unique_id',
           (select count(distinct customer_unique_id) from olist_src.olist_customers_dataset),
           (select count(*) from dim_cliente)
    from dual
    union all
    select 3, 'dim_producto: una fila por producto',
           (select count(*) from olist_src.olist_products_dataset),
           (select count(*) from dim_producto)
    from dual
    union all
    select 4, 'dim_vendedor: una fila por vendedor',
           (select count(*) from olist_src.olist_sellers_dataset),
           (select count(*) from dim_vendedor)
    from dual
    union all
    select 5, 'fact_ventas: una fila por item de pedido',
           (select count(*) from olist_src.olist_order_items_dataset),
           (select count(*) from fact_ventas)
    from dual
    union all
    select 6, 'fact_ventas: pedidos distintos',
           (select count(distinct order_id) from olist_src.olist_order_items_dataset),
           (select count(distinct order_id) from fact_ventas)
    from dual
    -- 2. Llaves sin duplicados
    union all
    select 7, 'fact_ventas: order_id + order_item_id repetidos', 0,
           (select count(*) from (select order_id, order_item_id from fact_ventas
                                  group by order_id, order_item_id having count(*) > 1))
    from dual
    union all
    select 8, 'dim_cliente: customer_unique_id repetidos', 0,
           (select count(*) from (select customer_unique_id from dim_cliente
                                  group by customer_unique_id having count(*) > 1))
    from dual
    union all
    select 9, 'dim_producto: product_id repetidos', 0,
           (select count(*) from (select product_id from dim_producto
                                  group by product_id having count(*) > 1))
    from dual
    union all
    select 10, 'dim_vendedor: seller_id repetidos', 0,
           (select count(*) from (select seller_id from dim_vendedor
                                  group by seller_id having count(*) > 1))
    from dual
    -- 3. Llaves huérfanas en el hecho
    union all
    select 11, 'fact_ventas: fecha_key sin dim_fecha', 0,
           (select count(*) from fact_ventas f
            where not exists (select 1 from dim_fecha d where d.fecha_key = f.fecha_key))
    from dual
    union all
    select 12, 'fact_ventas: cliente_key sin dim_cliente', 0,
           (select count(*) from fact_ventas f
            where not exists (select 1 from dim_cliente d where d.cliente_key = f.cliente_key))
    from dual
    union all
    select 13, 'fact_ventas: producto_key sin dim_producto', 0,
           (select count(*) from fact_ventas f
            where not exists (select 1 from dim_producto d where d.producto_key = f.producto_key))
    from dual
    union all
    select 14, 'fact_ventas: vendedor_key sin dim_vendedor', 0,
           (select count(*) from fact_ventas f
            where not exists (select 1 from dim_vendedor d where d.vendedor_key = f.vendedor_key))
    from dual
    union all
    select 15, 'fact_ventas: llave que apunta a otro cliente, producto o vendedor', 0,
           (select count(*)
            from fact_ventas f
            join olist_src.olist_order_items_dataset i
              on i.order_id = f.order_id and i.order_item_id = f.order_item_id
            join olist_src.olist_orders_dataset o on o.order_id = i.order_id
            join olist_src.olist_customers_dataset c on c.customer_id = o.customer_id
            join dim_cliente dc on dc.cliente_key = f.cliente_key
            join dim_producto dp on dp.producto_key = f.producto_key
            join dim_vendedor dv on dv.vendedor_key = f.vendedor_key
            where dc.customer_unique_id <> c.customer_unique_id
               or dp.product_id <> i.product_id
               or dv.seller_id <> i.seller_id)
    from dual
    -- 4. Sumas contra la fuente
    union all
    select 16, 'suma de precio',
           (select sum(price) from olist_src.olist_order_items_dataset),
           (select sum(precio) from fact_ventas)
    from dual
    union all
    select 17, 'suma de flete',
           (select sum(freight_value) from olist_src.olist_order_items_dataset),
           (select sum(flete) from fact_ventas)
    from dual
    -- 5. Reglas de limpieza (docs/calidad-datos.md)
    union all
    select 18, 'regla 4: productos en sin_categoria',
           (select count(*) from olist_src.olist_products_dataset where product_category_name is null),
           (select count(*) from dim_producto where categoria = 'sin_categoria')
    from dual
    union all
    select 19, 'regla 5: productos sin categoria en ingles', 0,
           (select count(*) from dim_producto where categoria is null)
    from dual
    union all
    select 20, 'regla 6: productos sin peso (nulo o 0)',
           (select count(*) from olist_src.olist_products_dataset where nvl(product_weight_g, 0) = 0),
           (select count(*) from dim_producto where peso_g is null and rango_peso = 'Sin peso')
    from dual
    union all
    select 21, 'clientes con recompra',
           (select count(*) from (select c.customer_unique_id
                                  from olist_src.olist_customers_dataset c
                                  join olist_src.olist_orders_dataset o on o.customer_id = c.customer_id
                                  group by c.customer_unique_id having count(*) > 1)),
           (select count(*) from dim_cliente where recompra = 'S')
    from dual
    union all
    select 22, 'reglas 3 y 16: items sin fecha de entrega',
           (select count(*) from olist_src.olist_order_items_dataset i
            join olist_src.olist_orders_dataset o on o.order_id = i.order_id
            where o.order_delivered_customer_date is null),
           (select count(*) from fact_ventas where dias_entrega is null)
    from dual
    union all
    select 23, 'a_tiempo que no coincide con dias_atraso', 0,
           (select count(*) from fact_ventas
            where (a_tiempo = 'S' and dias_atraso > 0)
               or (a_tiempo = 'N' and dias_atraso <= 0)
               or (a_tiempo is null and dias_atraso is not null)
               or (a_tiempo is not null and dias_atraso is null))
    from dual
    union all
    select 24, 'dias_entrega negativos', 0,
           (select count(*) from fact_ventas where dias_entrega < 0)
    from dual
    union all
    select 25, 'puntaje_resena fuera de 1 a 5', 0,
           (select count(*) from fact_ventas where puntaje_resena not between 1 and 5)
    from dual
    union all
    select 26, 'regla 12: items de pedidos sin resena',
           (select count(*) from olist_src.olist_order_items_dataset i
            where not exists (select 1 from olist_src.olist_order_reviews_dataset r
                              where r.order_id = i.order_id)),
           (select count(*) from fact_ventas where puntaje_resena is null)
    from dual
)
select n, prueba, esperado, obtenido,
       case when esperado = obtenido then 'OK' else 'FALLA' end as resultado
from pruebas
order by n;
