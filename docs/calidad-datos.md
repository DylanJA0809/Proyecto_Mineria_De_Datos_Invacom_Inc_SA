# Calidad de Datos y Estrategia de Limpieza — OLIST_SRC

**Script de auditoría:** [`calidad-datos/consultas.sql`](../calidad-datos/consultas.sql)  
**Documento de negocio de referencia:** [`docs/preguntas-de-negocio.md`](preguntas-de-negocio.md)

---

## 1. Volumen de la fuente

Conteo de filas por tabla en `OLIST_SRC` como línea base para verificar cuadres y pérdidas durante el proceso de limpieza y carga (consulta 1.1).

| Tabla | Filas | Rol en el proyecto |
|---|---|---|
| `olist_customers_dataset` | 99 441 | Carga y limpieza en STG |
| `olist_orders_dataset` | 99 441 | Carga y limpieza en STG |
| `olist_order_items_dataset` | 112 650 | Carga y limpieza en STG |
| `olist_order_payments_dataset` | 103 886 | Carga y limpieza en STG |
| `olist_order_reviews_dataset` | 99 224 | Carga y limpieza en STG |
| `olist_products_dataset` | 32 951 | Carga y limpieza en STG |
| `olist_sellers_dataset` | 3 095 | Carga y limpieza en STG |
| `product_category_name_translation` | 71 | Carga y limpieza en STG |
| `olist_geolocation_dataset` | 1 000 163 | **Descartada** (ver justificación en problemas 7 y 8) |

---

## 2. Estrategia de limpieza

**Leyenda de pasos:**
- **STG** → la regla se aplica al cargar de `OLIST_SRC` a `OLIST_STG` (limpieza técnica y estandarización).
- **DW** → la regla se aplica al estructurar los datos para el modelo final (reglas analíticas y medidas calculadas).
- **N/A** → no requiere acción (la tabla fue descartada, el campo no entra al DW o la prueba arrojó 0 errores).

| # | Problema detectado | Filas afectadas | Regla de Limpieza / ETL | Paso | Pregunta de Negocio protegida |
|---|---|---|---|---|---|
| 1 | Pedidos sin fecha de aprobación | 160 | Sin impacto en el DW: la fecha de aprobación no entra al modelo (el DW solo mide entrega total al cliente) | N/A | **P2** (entregas, atrasos y reseñas) |
| 2 | Pedidos sin fecha de entrega al transportista | 1 783 | Sin impacto en el DW: la fecha de despacho no entra al modelo (no se modelan etapas intermedias) | N/A | **P2** (entregas, atrasos y reseñas) |
| 3 | Pedidos sin fecha de entrega al cliente | 2 965 | Carga con `NULL`; pedidos no entregados o cancelados | STG | **P2** (entregas, atrasos y reseñas) |
| 4 | Productos sin categoría y sin metadatos | 610 | Homologar nombre a `'sin_categoria'` | STG | **P1, P2, P5** (ventas, reseñas y flete por categoría)|
| 5 | Categorías sin traducción al inglés | 13 productos (2 categorías) | Insertar traducciones oficiales: `pc_gamer` y `portable_kitchen_and_food_preparers` | STG | **P1, P2** (ventas y reseñas por categoría) |
| 6 | Productos con peso nulo o cero | 2 nulos + 4 en cero | Aplicar `NULLIF(product_weight_g, 0)`. Rango de peso en `dim_producto.rango_peso` (`VARCHAR2(12)`): `'< 500 g'` (menos de 500), `'500g - 2kg'` (500 a menos de 2 000), `'2kg - 10kg'` (2 000 a menos de 10 000), `'10kg o más'` (10 000 o más) y `'Sin peso'` (peso `NULL`). Ninguna etiqueta pasa de 12 caracteres | STG / DW | **P5** (peso vs. flete)|
| 7 | Geolocalización: filas duplicadas exactas | 261 831 | Tabla descartada del modelo (no aporta a preguntas de negocio) | N/A | **P4** (análisis geográfico) |
| 8 | Geolocalización: coordenadas fuera de Brasil | 42 | Tabla descartada del modelo | N/A | **P4** (análisis geográfico) |
| 9a | Pedidos con más de una reseña registrada | 547 pedidos | Seleccionar la última opinión emitida por el cliente usando la fecha más reciente (`review_creation_date` DESC) | DW | **P2, P3** (puntaje de satisfacción) |
| 9b | Reseñas con `review_id` repetido | 814 filas sobrantes | La clave única de la reseña debe ser la combinación `(review_id, order_id)` | STG / DW | **P2** (integridad de reseñas) |
| 10 | Pedidos sin ningún ítem vendido | 775 pedidos | Excluir de ventas (no tienen precio ni producto). Conservar en pedidos para medir tasa de cancelación | DW | **P1, P4** (monto vendido y clientes recurrentes) |
| 11 | Pedido `delivered` con 3 ítems sin pagos | 1 pedido | **Conservar en ventas** (los productos se vendieron y entregaron). Dejar monto cobrado en `NULL` y reportar en log de excepciones | DW | **P1, P5** (ventas totales y flete) |
| 12 | Pedidos sin reseña registrada | 768 pedidos | Carga con `review_score = NULL`. No incluir en el denominador al promediar satisfacción | STG / DW | **P2, P3** (promedio de estrellas) |
| 13 | Monto cobrado no cuadra con ítems + flete | 249 pedidos | Conservar montos originales de ítems y pagos sin alterar. Registrar diferencia explicada por intereses de cuotas y cupones | DW | **Fuera del DW** (pagos no entra al DW) |
| 14 | Despacho a transportista antes de aprobación | 1 359 pedidos | Sin impacto en el DW: no se modelan etapas intermedias ni banderas; solo se mide compra a entrega al cliente | N/A | **P2** (tiempos de entrega) |
| 15 | Entrega al cliente antes del despacho | 23 pedidos | Sin impacto en el DW: no se modelan etapas intermedias; `dias_entrega` (compra a entrega al cliente) es positivo y válido | N/A | **P2** (tiempos de entrega) |
| 16 | Pedidos `delivered` sin fecha de entrega | 8 pedidos (subconjunto del #3) | Conservar estado `delivered`, fecha en `NULL`; excluir de cálculo de días reales de entrega | STG / DW | **P2** (atrasos en entregas) |
| 17 | Pedidos no `delivered` con fecha de entrega | 6 pedidos | Conservar datos originales; auditable por consulta (`estado_pedido <> 'delivered'`) sin requerir columna bandera | DW | **P2** (auditoría de entregas) |
| 18 | Reseña registrada antes de la fecha de compra | 64 pedidos | Conservar la reseña más reciente según regla 9a; representa el 0.06 % y no distorsiona el promedio de satisfacción | DW | **P2** (atrasos vs. puntaje) |
| 19 | Pagos con medio de pago `not_defined` | 3 registros | Homologar como `'no_definido'`. Corresponden a los 3 pedidos cancelados con monto 0 | STG | **Fuera del DW** (pagos no entra al DW) |
| 20 | Pagos con valor cero | 9 registros | Conservar sin modificar (6 son cupones de descuento 100 % y 3 son cancelados) | STG | **Fuera del DW** (pagos no entra al DW) |
| 21 | Ítems con costo de flete en cero | 383 ítems | Conservar en 0 (representan envíos gratuitos válidos de la plataforma) | STG | **P5** (porcentaje de flete sobre precio) |
| 22 | Ciudades con escritura inconsistente | 400+ variantes | Normalizar con `LOWER(TRIM(ciudad))`, remover acentos y agrupar siempre por la combinación `(ciudad, estado)` | STG | **P1, P4** (ventas y clientes por ciudad/estado) |
| 23 | Reseñas sin título ni comentario escrito | 87 656 / 58 247 | Cargar como `NULL`. El puntaje numérico de satisfacción (1–5) siempre está presente | STG | **P2** (análisis de comentarios vs. estrellas) |
| 24 | Clientes sin código postal en geolocalización | 278 clientes | Sin impacto (tabla descartada; ubicación sale de `customer_city` y `customer_state`) | N/A | **P4** (clientes por ciudad/estado) |
| 25 | Vendedores sin código postal en geolocalización | 7 vendedores | Sin impacto (tabla descartada; ubicación sale de `seller_city` y `seller_state`) | N/A | **P2, P3** (desempeño geográfico del vendedor) |
| 26 | Pagos registrados con 0 cuotas | 2 filas | Asignar 1 cuota si hubo monto pagado o `NULL` si el pago es 0 | STG | **Fuera del DW** (pagos no entra al DW) |
| 27 | Meses extremos con datos incompletos | 5 meses con <20 pedidos | Definir filtro para análisis mensuales limitándose a meses completos (2017-01 a 2018-08) | DW | **P1, P2, P3** (tendencias mensuales) |
| 28 | Pedidos cancelados o no disponibles con ítems | 625 cancelados, 609 indisponibles | Crear filtro de "venta efectiva" solo para pedidos `delivered` o `shipped` para no sumar ventas que no ingresaron | DW | **P1, P3, P5** (ingresos reales por ventas) |
| 29 | Ítems con flete mayor al precio del producto | 3 800+ ítems | Válido para productos muy económicos. En P5 calcular ratio flete/precio como `SUM(flete) / SUM(precio)` a nivel general | DW | **P5** (peso del flete sobre precio) |
| 30 | Vendedores registrados sin ventas | 0 vendedores | Confirmado en consulta 5.5: todos los vendedores en catálogo tienen al menos 1 ítem | N/A | **P3** (desempeño de vendedores) |
| 31 | Códigos postales con formato inválido | 0 filas | Confirmado en consulta 7.8: todos tienen 5 dígitos | N/A | **P1, P4** (geografía limpia) |
| 32 | Estados que no son código de 2 letras | 0 filas | Confirmado en consulta 7.9: todos los estados son válidos (código de 2 letras) | N/A | **P1, P4** (geografía limpia) |
| 33 | Reseñas con calificación fuera del rango 1–5 | 0 filas | Confirmado en consulta 7.7: todas las calificaciones son válidas | N/A | **P2** (satisfacción limpia) |
| 34 | Reseñas respondidas antes de crearse | 0 filas | Confirmado en consulta 6.6: orden cronológico válido | N/A | **P2** (tiempos de respuesta válidos) |
| 35 | Productos con cantidad de fotos igual a 0 | 0 filas | Confirmado en consulta 7.14: productos con fotos tienen >= 1 | N/A | **P1** (catálogo de productos) |
| 36 | Ítems con precio menor o igual a cero | 0 filas | Confirmado en consulta 7.4: no hay precios negativos ni regalados sin flete | N/A | **P1, P5** (ingresos sin valores negativos) |

---

## 3. Anexo — Detalle y justificación de cada decisión

### 3.1 Nulos en fechas de etapa (problemas 1, 2, 3 y 16)
- **Consultas asociadas:** 2.1, 2.2, 6.3
- **Qué pasa en los datos:** 160 pedidos no tienen fecha de aprobación, 1 783 no tienen fecha de despacho y 2 965 no tienen fecha de entrega al cliente.
- **Por qué no se imputan fechas falsas:** Estos nulos son esperables en el ciclo de vida de un pedido: si un cliente cancela antes de que la orden sea aprobada o despachada, ese evento nunca ocurrió. Poner una fecha inventada distorsionaría por completo la **Pregunta 2** (*¿Cómo cambian el tiempo de entrega, los atrasos y el puntaje de las reseñas?*) inflando o reduciendo los días reales de entrega.
- **Alcance en el modelo dimensional:** En `fact_ventas` **no se incluyen fechas ni tiempos de etapas intermedias** (`order_approved_at` ni `order_delivered_carrier_date`), ya que el análisis de negocio evalúa únicamente la entrega total al cliente (`order_delivered_customer_date` vs. `order_purchase_timestamp`). Por tanto, los nulos de aprobación y despacho (problemas 1 y 2) no entran ni afectan al DW.
- **Caso especial 16 (8 pedidos `delivered` sin fecha de entrega):** Son un subconjunto de los 2 965 pedidos. El estado dice "entregado" pero se omitió registrar la fecha final. Se conservan como válidos para ventas, pero sus métricas de tiempo (`dias_entrega`, `dias_atraso`, `a_tiempo`) quedan en `NULL`, excluyéndose automáticamente de los cálculos de promedios de la **Pregunta 2** sin generar errores matemáticos.

---

### 3.2 Productos sin categoría y categorías sin traducción (problemas 4 y 5)
- **Consultas asociadas:** 2.3, 4.1, 4.2, 4.3, 4.4
- **Qué pasa en los datos:** 610 productos no tienen categoría registrada (tampoco tienen nombre, descripción ni fotos). Además, 13 productos vendidos pertenecen a 2 categorías que no tienen traducción al inglés en la tabla oficial: `pc_gamer` y `portateis_cozinha_e_preparadores_de_alimentos`.
- **Justificación de negocio:** La consulta 4.2 demuestra que los 610 productos sin categoría **sí se vendieron** (generaron ingresos reales). Eliminarlos haría que la **Pregunta 1** (*ventas por categoría, mes y estado*) y la **Pregunta 2** (*entregas, atrasos y reseñas, donde el filtro por categoría es clave*) pierdan ventas y calificaciones reales.
- **Regla aplicada:**
  1. En STG, los 610 productos se homologan con la categoría `'sin_categoria'`.
  2. En la tabla de traducción se agregan las 2 categorías faltantes en minúsculas y con guiones bajos (`snake_case`) para respetar el estándar de la tabla:
     - `pc_gamer` → `pc_gamer`
     - `portateis_cozinha_e_preparadores_de_alimentos` → `portable_kitchen_and_food_preparers`

---

### 3.3 Pesos nulos y productos con peso cero (problema 6)
- **Consultas asociadas:** 2.3, 4.5, 7.12, 9.1
- **Qué pasa en los datos:** 2 productos tienen peso nulo y 4 productos tienen registrado un peso de 0 gramos.
- **Por qué se aplica `NULLIF`:** Ningún producto físico puede pesar 0 gramos. Si calculamos el costo de flete por kilo en la **P5** (*día, hora y flete*), dividir entre 0 rompería las fórmulas matemáticas o arrojaría infinitos.
- **Regla aplicada:** Se limpia con `NULLIF(product_weight_g, 0)` para que quede en `NULL`. El peso se clasifica en `dim_producto.rango_peso`, que es `VARCHAR2(12)`:
  | Rango | Etiqueta | Caracteres |
  |---|---|---|
  | Menos de 500 g | `< 500 g` | 7 |
  | De 500 g a menos de 2 000 g | `500g - 2kg` | 10 |
  | De 2 000 g a menos de 10 000 g | `2kg - 10kg` | 10 |
  | 10 000 g o más | `10kg o más` | 10 |
  | Peso nulo (incluye los ceros convertidos) | `Sin peso` | 8 |

---

### 3.4 Descarte justificado de la tabla `olist_geolocation_dataset` (problemas 7, 8, 24 y 25)
- **Consultas asociadas:** 3.1, 3.2, 8.1, 8.2 y Sección 10 de `consultas.sql`
- **Por qué se descarta completamente la tabla:**
  1. **No tiene clave primaria:** un mismo código postal (`zip_code_prefix`) se repite hasta 1 146 veces con coordenadas ligeramente distintas. Si hacemos un `JOIN` con clientes o vendedores, las ventas se duplicarían o triplicarían artificialmente.
  2. **261 831 filas repetidas exactas (26,2 %):** Es una tabla extremadamente pesada y redundante.
  3. **42 coordenadas fuera de Brasil:** Registros con latitud y longitud inválidas.
  4. **Cobertura incompleta:** 278 clientes (problema 24) y 7 vendedores (problema 25) tienen códigos postales que ni siquiera existen en la tabla de geolocalización.
  5. **La información ya existe en tablas limpias:** `customer_city`, `customer_state`, `seller_city` y `seller_state` son 100 % completas y responden a la perfección la **Pregunta 1** (ventas por ciudad/estado), la **Pregunta 2** (rutas de envío entre estados), la **Pregunta 3** (vendedores por estado) y la **Pregunta 4** (ubicación de clientes).

---

### 3.5 Reseñas repetidas y múltiples opiniones por pedido (problemas 9a, 9b y 12)
- **Consultas asociadas:** 3.3, 3.4, 3.5, 5.3, 9.1
- **Qué pasa en los datos:** 
  - **9a:** 547 pedidos tienen más de una reseña registrada en el tiempo (un cliente que opinó varias veces sobre su compra).
  - **9b:** Hay 814 filas sobrantes porque un mismo código de reseña (`review_id`) fue asignado a varios pedidos (ocurre cuando un cliente compra varios ítems a la vez y la plataforma genera una sola reseña global).
- **Justificación de negocio:** Para la **Pregunta 2** (*entregas, atrasos y reseñas por ruta*), promediar múltiples opiniones del mismo pedido falsearía el resultado (por ejemplo, si el cliente dio 1 estrella al inicio y luego corrigió a 5 estrellas al recibir el paquete). La **Pregunta 3** (*desempeño de vendedores en satisfacción*) también se ve afectada.
- **Regla aplicada:**
  - Para métricas por pedido: se toma **la reseña más reciente** ordenando por `review_creation_date DESC` y desempatando por `review_answer_timestamp DESC` y `review_id DESC`.
  - En la tabla de reseñas: la clave primaria única es la combinación `(review_id, order_id)`.
  - Para los 768 pedidos sin reseña (problema 12): se cargan con `review_score = NULL`, asegurando que no se cuenten en el denominador al promediar estrellas.

---

### 3.6 Integridad de pedidos: sin ítems y pedido entregado sin pago (problemas 10 y 11)
- **Consultas asociadas:** 5.1, 5.2
- **Problema 10 (775 pedidos sin ítems):** La gran mayoría son pedidos con estado `unavailable` (603) o `canceled` (164). Al no tener ítems, no tienen precio ni flete. Se excluyen de la tabla de ventas para no generar filas vacías en la **Pregunta 1** (*ventas por categoría*), pero se conservan para contar el volumen total de cancelaciones y medir la recompra en la **Pregunta 4** (*clientes y recompra*).
- **Problema 11 (1 pedido entregado con 3 ítems pero sin pago):**
  - **Decisión clave:** **No se elimina de ventas**. El pedido fue entregado y contiene 3 productos reales con precio y flete. Si lo eliminamos, estaríamos falseando las unidades vendidas de la **Pregunta 1** (*ventas totales*) y el flete registrado de la **Pregunta 5** (*peso del flete*).
  - **Acción:** La venta se registra normalmente; el monto de cobro queda en `NULL` y se envía una notificación al registro de excepciones para que el área de negocio investigue por qué no se registró el pago.

---

### 3.7 Diferencias entre monto cobrado y total de productos + flete (problema 13)
- **Consultas asociadas:** 5.6, 5.7
- **Qué pasa en los datos:** En 249 pedidos la suma de los pagos difiere en más de 1 unidad respecto a la suma de `price + freight_value`.
- **Por qué no se modifican los montos:** En el comercio electrónico real, esta diferencia es completamente habitual: ocurre cuando el cliente paga en cuotas con tarjeta de crédito (acumulando intereses de financiamiento bancario que aumentan el cobro final) o cuando se aplican cupones de descuento a nivel de pedido. Los pagos quedan **fuera del DW** (el grano de la estrella es a nivel de producto/ítem en `fact_ventas`), por lo que esta regla aplica únicamente como validación de cuadres en el ETL.

---

### 3.8 Fechas fuera de orden cronológico (problemas 14, 15, 17 y 18)
- **Consultas asociadas:** 6.1, 6.2, 6.4, 6.7
- **Qué pasa en los datos:**
  - 1 359 pedidos pasan a la transportista antes de la fecha registrada de aprobación (problema 14).
  - 23 pedidos aparecen entregados al cliente antes de salir con el transportista (problema 15).
  - 6 pedidos no entregados tienen fecha de entrega (problema 17).
  - 64 reseñas tienen fecha de creación anterior a la fecha de compra (problema 18).
- **Decisión de diseño en el DW (sin banderas innecesarias):**
  - **Problemas 14 y 15 (etapas intermedias fuera de orden):** El modelo dimensional de `OLIST_DW` mide únicamente el tiempo total de entrega (`dias_entrega = trunc(order_delivered_customer_date) - trunc(order_purchase_timestamp)`) y el atraso frente a la estimación (`dias_atraso`). Al **no almacenar fechas ni calcular tiempos intermedios** (aprobación y despacho al transportista no entran a `fact_ventas`), estas inconsistencias de la fuente no generan días negativos ni distorsionan las métricas del DW. Por tanto, no se requieren columnas de bandera (`flags`) en la tabla de hechos.
  - **Problema 17 (pedidos no delivered con fecha de entrega):** Se cargan conservando el `estado_pedido` original y su fecha de entrega. No se agrega una columna bandera en `fact_ventas`; si se requiere auditar estos 6 casos, se filtran directamente por consulta (`WHERE estado_pedido <> 'delivered' AND dias_entrega IS NOT NULL`).
  - **Problema 18 (reseñas creadas antes de la compra):** Son únicamente 64 de 99 224 reseñas (0.06 %). Se procesan con la regla estándar 9a (tomando la reseña más reciente del pedido). No se excluyen mediante filtros adicionales en el ETL, ya que la calificación de satisfacción sigue siendo válida y su peso en los promedios de la **Pregunta 2** es estadísticamente imperceptible.

---

### 3.9 Transacciones atípicas y medios de pago (problemas 19, 20 y 26)
- **Consultas asociadas:** 7.2, 7.3, 9.1
- **Qué pasa en los datos:**
  - 3 pagos tienen medio de pago `not_defined` (problema 19). La consulta 7.3 confirma que son exactamente los 3 pedidos cancelados con monto igual a 0.
  - 9 pagos tienen monto 0 (problema 20): 6 corresponden a cupones (vouchers) que cubrieron el 100 % de la compra y 3 a pedidos cancelados.
  - 2 pagos tienen registradas 0 cuotas (problema 26).
- **Regla aplicada (validación en ETL, pagos fuera del DW):** 
  - Homologar `payment_type = 'no_definido'`.
  - Los pagos en 0 por cupones se conservan intactos porque representan compras válidas pagadas con puntos/descuento.
  - Para las 2 filas con 0 cuotas, se asigna 1 cuota si hubo dinero pagado. Esta validación aplica únicamente en el ETL; los pagos no entran al modelo estrella.

---

### 3.10 Ítems con flete en cero y fletes mayores al precio (problemas 21 y 29)
- **Consultas asociadas:** 7.4, 7.5
- **Problema 21 (383 ítems con flete 0):** Son envíos gratuitos promocionales. Es un dato válido que debe conservarse en 0.
- **Problema 29 (Flete mayor al precio):** Ocurre en más de 3 800 ítems (por ejemplo, accesorios pequeños o tornillos que cuestan $3 pero el envío cuesta $12).
- **Regla para la Pregunta 5 (*día, hora y peso del flete*):** El ratio de flete debe calcularse siempre de forma agregada como `SUM(flete) / SUM(precio)` y nunca promediando porcentajes individuales, lo que evita que estos casos pequeños distorsionen el resultado general.

---

### 3.11 Normalización de nombres de ciudades (problema 22)
- **Consultas asociadas:** 7.10, 7.11
- **Qué pasa en los datos:** Existen más de 400 variaciones de nombres de ciudades debido a tildes (`são paulo` vs `sao paulo`), mayúsculas/minúsculas y espacios accidentales.
- **Justificación de negocio:** La **Pregunta 1** (*ventas por categoría, estado y mes*) y la **Pregunta 4** (*ubicación y recompra de clientes*) agruparían erróneamente la misma ciudad en renglones separados si no se unifican.
- **Regla aplicada:** En STG se convierten a minúsculas, se eliminan acentos con funciones de traducción y se agrupa siempre por la combinación `(ciudad_normalizada, estado)` para no mezclar municipios con el mismo nombre en diferentes estados de Brasil.

---

### 3.12 Meses incompletos y pedidos cancelados (problemas 27 y 28)
- **Consultas asociadas:** 6.8, 7.1
- **Qué pasa en los datos:**
  - En la consulta 6.8 se evidencia que los pedidos van de sep-2016 a oct-2018, pero los únicos meses con datos comerciales completos van de **enero 2017 a agosto 2018** (20 meses). Los extremos tienen menos de 20 pedidos y nov-2016 no tiene ninguno.
  - En la consulta 7.1 hay 625 pedidos cancelados y 609 indisponibles que contienen ítems registrados.
- **Regla aplicada:**
  - Para las **Preguntas 1, 2, 3, 4 y 5** (análisis de tendencias mensuales), los reportes deben filtrar el rango de meses completos (2017-01 a 2018-08) para no mostrar caídas falsas de ventas.
  - Para evitar inflar los ingresos reales, se crea un filtro de "venta efectiva" que considere únicamente pedidos con estado `delivered` o `shipped`.

---

## 4. Tablas y campos de OLIST_SRC que alimentan el DW

| Tabla en OLIST_SRC | Campo fuente | Tabla en OLIST_DW | Campo destino |
|---|---|---|---|
| `olist_customers_dataset` | `customer_unique_id` | `dim_cliente` | `customer_unique_id` |
| `olist_customers_dataset` | `customer_unique_id` | `fact_ventas` | `cliente_key` (lookup) |
| `olist_customers_dataset` | `customer_city` | `dim_cliente` | `ciudad` |
| `olist_customers_dataset` | `customer_state` | `dim_cliente` | `estado` |
| `olist_sellers_dataset` | `seller_id` | `dim_vendedor` | `seller_id` |
| `olist_sellers_dataset` | `seller_city` | `dim_vendedor` | `ciudad` |
| `olist_sellers_dataset` | `seller_state` | `dim_vendedor` | `estado` |
| `olist_products_dataset` | `product_id` | `dim_producto` | `product_id` |
| `olist_products_dataset` | `product_category_name` | `dim_producto` | `categoria` (traducida al inglés) |
| `olist_products_dataset` | `product_weight_g` | `dim_producto` | `peso_g` |
| `product_category_name_translation` | `product_category_name_english` | `dim_producto` | `categoria` |
| `olist_orders_dataset` | `order_purchase_timestamp` | `fact_ventas` | `fecha_key` |
| `olist_orders_dataset` | `order_purchase_timestamp` | `fact_ventas` | `hora_compra` |
| `olist_orders_dataset` | `order_id` | `fact_ventas` | `order_id` |
| `olist_orders_dataset` | `order_status` | `fact_ventas` | `estado_pedido` |
| `olist_orders_dataset` | `order_delivered_customer_date` | `fact_ventas` | `dias_entrega` |
| `olist_orders_dataset` | `order_delivered_customer_date` | `fact_ventas` | `dias_atraso` |
| `olist_orders_dataset` | `order_estimated_delivery_date` | `fact_ventas` | `dias_atraso` |
| `olist_orders_dataset` | `order_delivered_customer_date` | `fact_ventas` | `a_tiempo` |
| `olist_orders_dataset` | `order_estimated_delivery_date` | `fact_ventas` | `a_tiempo` |
| `olist_order_items_dataset` | `order_id` | `fact_ventas` | `order_id` |
| `olist_order_items_dataset` | `order_item_id` | `fact_ventas` | `order_item_id` |
| `olist_order_items_dataset` | `product_id` | `fact_ventas` | `producto_key` (lookup) |
| `olist_order_items_dataset` | `seller_id` | `fact_ventas` | `vendedor_key` (lookup) |
| `olist_order_items_dataset` | `price` | `fact_ventas` | `precio` |
| `olist_order_items_dataset` | `freight_value` | `fact_ventas` | `flete` |
| `olist_order_reviews_dataset` | `review_score` | `fact_ventas` | `puntaje_resena` |

**Tablas de OLIST_SRC que no alimentan el DW:**

- `olist_order_payments_dataset`: no tiene columna propia en el DW; se usa solo en el ETL para validar montos.
- `olist_geolocation_dataset`: descartada (ver sección 3.4).


---

