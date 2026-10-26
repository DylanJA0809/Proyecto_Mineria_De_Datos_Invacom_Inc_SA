# Preguntas de negocio — Invacom Inc. S.A.

## 1. ¿Qué categorías de producto venden más por mes?

- **Medidas:** monto vendido (`price`), unidades vendidas (cantidad de ítems), número de pedidos.
- **Por:** categoría de producto (en inglés), año, mes.
- **Tablas:** `olist_order_items_dataset`, `olist_products_dataset`, `product_category_name_translation`, `olist_orders_dataset` (fecha de compra).
- **Ojo:** hay 610 productos sin categoría y 13 productos de 2 categorías sin traducción (`pc_gamer`, `portateis_cozinha_e_preparadores_de_alimentos`); el ETL tiene que decidir cómo nombrarlos (consultas 4.1 y 4.3 de `calidad-datos/consultas.sql`).

## 2. ¿En qué estados (y ciudades) de Brasil se compra más?

- **Medidas:** monto vendido, número de pedidos, clientes únicos, ticket promedio.
- **Por:** estado, ciudad, año, mes.
- **Tablas:** `olist_customers_dataset`, `olist_orders_dataset`, `olist_order_items_dataset`.
- **Ojo:** contar clientes con `customer_unique_id` (96 096 clientes reales), no con `customer_id` (99 441, uno por pedido). Hay ciudades escritas de varias formas que el ETL debe unificar (consulta 7.11). La geografía sale de la ciudad y el estado del cliente; `olist_geolocation_dataset` no se usa (sección 10 de `consultas.sql`).

## 3. ¿Las entregas atrasadas bajan el puntaje de las reseñas?

- **Medidas:** puntaje promedio de reseña, % de pedidos con reseña de 1–2 estrellas, días de atraso.
- **Por:** entregado a tiempo vs. atrasado, rangos de días de atraso, estado del cliente.
- **Tablas:** `olist_orders_dataset` (`order_delivered_customer_date` vs. `order_estimated_delivery_date`), `olist_order_reviews_dataset`.
- **Ojo:** solo aplica a pedidos con estado `delivered` y fecha de entrega real (8 `delivered` no la tienen). Una misma reseña puede aparecer en varios pedidos (814 `review_id` repetidos), 547 pedidos tienen más de una reseña y 768 no tienen ninguna; hay que decidir si se promedian.

## 4. ¿Cuánto tarda en llegar un pedido y dónde se atrasa más?

- **Medidas:** días promedio de compra a entrega, días de aprobación, días en manos de la transportista, % de pedidos atrasados.
- **Por:** estado del cliente, estado del vendedor, mismo estado vs. distinto estado, año, mes.
- **Tablas:** `olist_orders_dataset`, `olist_order_items_dataset`, `olist_sellers_dataset`, `olist_customers_dataset`.
- **Ojo:** hay fechas fuera de orden: 1 359 pedidos pasan a la transportista antes de aprobarse y 23 llegan al cliente antes de salir con la transportista (consultas 6.1 y 6.2). El ETL debe decidir si los excluye de los cálculos de tiempos por etapa.

## 5. ¿Cómo pagan los clientes?

- **Medidas:** monto pagado, número de pagos, promedio de cuotas.
- **Por:** tipo de pago (tarjeta, boleto, voucher, débito), número de cuotas, año, mes, estado del cliente.
- **Tablas:** `olist_order_payments_dataset`, `olist_orders_dataset`, `olist_customers_dataset`.
- **Ojo:** un pedido puede tener varios pagos (`payment_sequential`). En 249 pedidos el total pagado no cuadra con `price + freight_value` (diferencia mayor a 1), 1 pedido entregado no tiene pagos y hay 3 pagos `not_defined` (consultas 5.2, 5.6 y 7.2).

## 6. ¿Qué vendedores tienen mejor y peor desempeño?

- **Medidas:** monto vendido, pedidos, puntaje promedio de reseña, % de envíos atrasados respecto a `shipping_limit_date`.
- **Por:** vendedor, estado del vendedor, categoría, año, mes.
- **Tablas:** `olist_order_items_dataset`, `olist_sellers_dataset`, `olist_orders_dataset`, `olist_order_reviews_dataset`.

## 7. ¿Cuánto pesa el flete sobre el precio del producto?

- **Medidas:** flete total, flete promedio, % flete / precio.
- **Por:** categoría, estado del cliente, estado del vendedor, rangos de peso del producto.
- **Tablas:** `olist_order_items_dataset`, `olist_products_dataset`, `olist_customers_dataset`, `olist_sellers_dataset`.

## 8. ¿Los clientes vuelven a comprar?

- **Medidas:** % de clientes con más de un pedido, pedidos por cliente, tiempo entre compras.
- **Por:** estado del cliente, categoría de la primera compra, año de la primera compra.
- **Tablas:** `olist_customers_dataset` (`customer_unique_id`), `olist_orders_dataset`.

## 9. ¿En qué días y horas se compra más?

- **Medidas:** número de pedidos, monto vendido, ticket promedio.
- **Por:** día de la semana, hora del día, mes, fin de semana vs. entre semana.
- **Tablas:** `olist_orders_dataset` (`order_purchase_timestamp`), `olist_order_items_dataset`.
- **Ojo:** la hora se conserva: el `.ctl` de pedidos carga las fechas con formato `YYYY-MM-DD HH24:MI:SS`. Conviene una dimensión de tiempo con día de la semana y la hora como atributo aparte (o su propia dimensión).

## 10. ¿Qué categorías tienen las reseñas más bajas?

- **Medidas:** puntaje promedio de reseña, % de reseñas de 1–2 estrellas, % de reseñas con comentario escrito.
- **Por:** categoría de producto, año, mes, estado del cliente.
- **Tablas:** `olist_order_reviews_dataset`, `olist_order_items_dataset`, `olist_products_dataset`, `product_category_name_translation`.
- **Ojo:** la reseña es por pedido, no por producto; si un pedido trae productos de varias categorías, la reseña cuenta para cada una. Aplican las mismas notas de la pregunta 1 (610 productos sin categoría) y de la 3 (reseñas repetidas). Conviene un mínimo de reseñas por categoría para que el promedio signifique algo.

---

## Evaluación: relevancia y factibilidad

Evaluación hecha contra los datos de `OLIST_SRC` y los resultados de `calidad-datos/consultas.sql`. Los pedidos van de septiembre 2016 a octubre 2018, pero los meses con datos completos son de enero 2017 a agosto 2018. Los extremos casi no tienen pedidos (2016-09: 4, 2016-12: 1, 2018-09: 16, 2018-10: 4; 2016-11 no tiene ninguno), así que los análisis por mes deberían limitarse a ese rango (consulta 6.8).

| # | Pregunta | Relevancia | Factibilidad |
|---|---|---|---|
| 1 | Categorías que más venden por mes | **Alta**: guía inventario, marketing y compras. | **Alta**: datos completos. Solo hay que tratar los 610 productos sin categoría y las 2 categorías sin traducción. |
| 2 | Estados/ciudades donde se compra más | **Alta**: define dónde invertir en publicidad y logística. | **Alta**: todos los clientes tienen estado y ciudad. Algunas ciudades vienen con tildes o escritura inconsistente. |
| 3 | Atrasos vs. puntaje de reseñas | **Alta**: conecta la operación con la satisfacción del cliente. | **Alta**: solo 768 pedidos no tienen reseña, y casi todos tienen fecha real y estimada. Se limita a pedidos `delivered` con fecha de entrega. |
| 4 | Tiempo de entrega y dónde se atrasa | **Alta**: identifica cuellos de botella logísticos por región. | **Alta**: las fechas están. Hay que filtrar los 8 `delivered` sin fecha de entrega y tratar las fechas fuera de orden (1 359 + 23 pedidos). |
| 5 | Cómo pagan los clientes | **Media**: útil para finanzas y para promociones en cuotas. | **Alta**: tabla de pagos casi limpia: 3 `not_defined`, 1 pedido sin pagos y 249 pedidos descuadrados. |
| 6 | Desempeño de vendedores | **Alta**: permite premiar o sancionar vendedores del marketplace. | **Media**: muchos vendedores tienen muy pocos pedidos; hay que poner un mínimo de ventas para que los promedios signifiquen algo. |
| 7 | Peso del flete sobre el precio | **Media**: ayuda a revisar la política de envíos y precios por región. | **Alta**: precio y flete vienen por ítem. Solo 2 productos sin peso y 4 con peso 0; 383 ítems tienen flete 0. |
| 8 | Recompra de clientes | **Alta**: la fidelización es clave en un e-commerce. | **Media**: se calcula con `customer_unique_id`, pero solo alrededor del 3% de clientes recompra, así que el resultado será pequeño (igual es un hallazgo válido). |
| 9 | Días y horas de compra | **Media**: sirve para programar campañas y soporte. | **Alta**: la carga conservó la hora de compra (formato `HH24:MI:SS` en el `.ctl`). |
| 10 | Categorías con reseñas más bajas | **Alta**: señala qué categorías generan clientes insatisfechos (calidad del producto, descripciones, devoluciones). | **Alta**: 99 224 reseñas, todas con puntaje de 1 a 5 (consulta 7.7), unidas a la categoría por los ítems del pedido. Solo hay que tratar los productos sin categoría y las reseñas repetidas. |
