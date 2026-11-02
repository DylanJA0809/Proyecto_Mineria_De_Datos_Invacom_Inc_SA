# Preguntas de negocio — Invacom Inc. S.A.

Cada pregunta junta varias medidas y varias dimensiones, para que su tabla dinámica traiga muchos
datos y se pueda filtrar y bajar de nivel (de año a mes, de estado a ciudad). Todas se responden con
el modelo estrella de `docs/modelo-dimensional.md`.

Los análisis por mes van de **enero 2017 a agosto 2018**, los meses con datos completos. Los extremos
casi no tienen pedidos (2016-09: 4, 2016-12: 1, 2018-09: 16, 2018-10: 4; 2016-11 no tiene ninguno),
según la consulta 6.8 de `calidad-datos/consultas.sql`.

---

## 1. ¿Cómo evolucionaron, mes a mes, las ventas de cada categoría en cada estado de Brasil, de enero 2017 a agosto 2018?

- **Medidas:** monto (`precio`), unidades, pedidos distintos, ticket promedio y `flete`.
- **Filas:** categoría (74).
- **Columnas:** año → mes (20).
- **Filtros:** estado del cliente (27) → ciudad (4 119).
- **Tamaño:** 74 × 20 × 27 ≈ 40 000 combinaciones.
- **Ojo:** los 610 productos sin categoría y los 13 sin traducción se resuelven en staging. Hay
  ciudades escritas de varias formas que el ETL debe unificar (consulta 7.11).

## 2. ¿Cómo cambian el tiempo de entrega, los atrasos y el puntaje de las reseñas según la ruta del envío, la categoría y el mes?

- **Medidas:** promedio de `dias_entrega` y `dias_atraso`, % de pedidos a tiempo, promedio de
  `puntaje_resena` y % de pedidos con reseña de 1 o 2 estrellas.
- **Filas:** estado del vendedor (23) → estado del cliente (27): hasta 621 rutas.
- **Columnas:** año → mes (20).
- **Filtros:** categoría · `estado_pedido` = `delivered`.
- **Tamaño:** 621 rutas × 20 meses ≈ 12 400 combinaciones, por categoría.
- **Ojo:** 8 pedidos `delivered` no tienen fecha de entrega, y hay fechas fuera de orden (1 359
  pedidos pasan a la transportista antes de aprobarse y 23 llegan antes de salir; consultas 6.1 a
  6.3). Si un pedido tiene varias reseñas, se usa el promedio (547 pedidos); 768 no tienen ninguna.

## 3. ¿Qué vendedores rinden mejor y peor en ventas, puntualidad y satisfacción, por estado y categoría?

- **Medidas:** monto, pedidos distintos, promedio de `puntaje_resena`, % de pedidos a tiempo y flete
  promedio.
- **Filas:** estado del vendedor (23) → vendedor (3 095).
- **Filtros:** categoría · año.
- **Tamaño:** 3 095 vendedores.
- **Ojo:** muchos vendedores tienen muy pocos pedidos; hay que poner un mínimo de pedidos para que
  el promedio valga.

## 4. ¿Dónde están los clientes, cuánto gasta cada uno y cuántos vuelven a comprar?

- **Medidas:** clientes únicos, pedidos por cliente, gasto por cliente y % de clientes con
  `recompra` = S.
- **Filas:** estado (27) → ciudad (4 119).
- **Columnas:** año (2016 a 2018).
- **Filtros:** categoría.
- **Tamaño:** 96 096 clientes repartidos en 4 119 ciudades.
- **Ojo:** los clientes se cuentan con `customer_unique_id` (96 096), no con `customer_id` (99 441,
  uno por pedido). Solo alrededor del 3 % recompra: el resultado será pequeño, pero es un hallazgo
  válido.

## 5. ¿Qué día y a qué hora se compra más, y cuánto pesa el flete sobre el precio, por categoría y rango de peso?

- **Medidas:** pedidos distintos, monto, ticket promedio y % de flete sobre el precio (suma de
  `flete` ÷ suma de `precio`).
- **Filas:** `nombre_dia` (7) o `rango_peso`.
- **Columnas:** `hora_compra` (24).
- **Filtros:** categoría · `fin_de_semana`.
- **Tamaño:** 7 × 24 = 168 franjas por categoría.
- **Ojo:** la carga conservó la hora de compra (formato `HH24:MI:SS` en el `.ctl`). Solo 2 productos
  no tienen peso y 4 tienen peso 0; 383 ítems tienen flete 0.

---

## Evaluación: relevancia y factibilidad

| # | Pregunta | Relevancia | Factibilidad |
|---|---|---|---|
| 1 | Ventas por categoría, mes y estado | **Alta**: guía inventario, marketing y dónde invertir en publicidad y logística. | **Alta**: datos completos; solo hay que resolver categorías y ciudades en staging. |
| 2 | Entregas, atrasos y reseñas por ruta | **Alta**: conecta la logística con la satisfacción del cliente. | **Alta**: casi todos los pedidos tienen fechas y reseña; hay que filtrar los casos anotados. |
| 3 | Desempeño de vendedores | **Alta**: permite premiar o sancionar vendedores del marketplace. | **Media**: los vendedores con pocos pedidos necesitan un mínimo para que los promedios signifiquen algo. |
| 4 | Ubicación, gasto y recompra de clientes | **Alta**: muestra dónde está el mercado y qué tanto se fideliza. | **Media**: la recompra es baja (alrededor del 3 %), aunque se calcula sin problema. |
| 5 | Día, hora y peso del flete | **Media**: sirve para programar campañas y revisar la política de envíos. | **Alta**: la hora se conservó y casi todos los productos tienen peso. |

## Cómo salen de las preguntas anteriores

El primer borrador tenía 10 preguntas más específicas. Las 5 de arriba las juntan:

| Pregunta nueva | Junta las anteriores |
|---|---|
| 1 | Categorías que más venden por mes · Estados donde se compra más |
| 2 | Atrasos vs. reseñas · Tiempo de entrega · Categorías con reseñas más bajas |
| 3 | Desempeño de vendedores |
| 4 | Estados donde se compra más · Recompra de clientes |
| 5 | Peso del flete sobre el precio · Días y horas de compra |

Queda fuera **cómo pagan los clientes**: los pagos son por pedido, un pedido puede tener varios, y no
entran en la estrella, cuyo grano es un producto por fila.
