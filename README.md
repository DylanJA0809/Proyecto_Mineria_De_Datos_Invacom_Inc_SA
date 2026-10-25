# Data Warehouse para Invacom Inc S.A.

Proyecto #1 del curso **ISW-911 Minería de Datos** (3C2026), grupo 01.

Invacom quiere un data warehouse para analizar las ventas de un marketplace. Este repo tiene los
scripts SQL, los jobs de ETL y la documentación con que se construye.

**Integrantes:** Josué, Karol, Katherine y Dylan.

## La base: Olist

*Brazilian E-Commerce Public Dataset by Olist*: un marketplace brasileño con compras reales de 2016
a 2018, vendedores externos, logística, pagos y reseñas de clientes. Viene en 9 CSV, que **no están
en el repo** (pesan 121 MB). Se descargan de
[Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce).

| Tabla | Filas |
|---|---|
| `olist_orders_dataset` | 99 441 |
| `olist_order_items_dataset` | 112 650 |
| `olist_order_payments_dataset` | 103 886 |
| `olist_order_reviews_dataset` | 99 224 |
| `olist_customers_dataset` | 99 441 |
| `olist_sellers_dataset` | 3 095 |
| `olist_products_dataset` | 32 951 |
| `olist_geolocation_dataset` | 1 000 163 |
| `product_category_name_translation` | 71 |

## Arquitectura

```
CSV de Kaggle ──► OLIST_SRC ──► AWS Glue ──► OLIST_STG ──► AWS Glue ──► OLIST_DW ──► Excel
                  (fuente)      (limpia)     (staging)     (carga)      (estrella)   (tablas dinámicas)
```

- **Motor:** Oracle Database 21c XE, en la PDB `XEPDB1`.
- **Las tres bases son tres esquemas** del mismo Oracle, porque en Oracle esquema y usuario son lo
  mismo:

| Esquema | Etapa | Qué tiene |
|---|---|---|
| `OLIST_SRC` | Extracción | Los CSV tal cual, sin limpiar, y las vistas de extracción |
| `OLIST_STG` | Transformación | Los datos que limpió Glue: sin duplicados, con los nulos resueltos y las categorías traducidas |
| `OLIST_DW` | Carga | El modelo estrella: primero las dimensiones y después los hechos |

- **ETL:** AWS Glue, con Script Editor y Spark. Los jobs se guardan como `.py` en este repo.
- **Reportes:** tablas dinámicas de Excel conectadas a `OLIST_DW`.

## Estructura del repo

```
olist-carga/          Carga de OLIST_SRC con SQL*Loader
├── 01_tablas.sql     Crea las 9 tablas
├── 02_llaves.sql     Llaves primarias y foráneas
├── cargar.sh         Corre las 9 cargas de una vez
└── ctl/              Un archivo de control por CSV
```

Las carpetas de staging, del DW y de los jobs de Glue se agregan a medida que avanza el proyecto.

## Cómo se cargó `OLIST_SRC`

Cada línea de un CSV tenía que quedar como una fila de su tabla. Eso lo hace **SQL\*Loader**
(`sqlldr`), la herramienta de Oracle para cargar archivos de texto:

- **Un `.ctl` le dice cómo cargar un CSV:** qué archivo abrir, en qué tabla meterlo, que se salte la
  fila de títulos, cómo vienen separados los campos y en qué columna va cada valor.
- **`cargar.sh` corre los 9 `.ctl` de una vez** y muestra cuántas filas se cargaron y cuántas se
  rechazaron en cada tabla.

Orden:

1. `01_tablas.sql`, conectado como `OLIST_SRC`.
2. `cargar.sh`, dentro del contenedor de Oracle. La contraseña le llega por la entrada estándar, así
   que no queda escrita en ningún archivo.
3. `02_llaves.sql`, conectado como `OLIST_SRC`.

**Resultado:** las 9 tablas con las mismas filas que el Excel de asignación del profesor y 0 rechazos.

Decisiones de la carga:
- **Los datos se cargaron sin limpiar.** La limpieza le toca al ETL.
- `olist_geolocation_dataset` no tiene llave primaria: el código postal se repite, porque cada uno
  trae varias coordenadas.
- La FK de productos a la traducción de categorías es **declarativa** (`DISABLE NOVALIDATE`): 13
  productos tienen una categoría sin traducción. Oracle no la valida, pero queda en el diagrama.
- Para recargar hay que desactivar antes las FK. Con ellas activas, el `TRUNCATE` de una tabla padre
  falla (`ORA-02266`).

## Forma de trabajo

- **Scrum con sprints de una semana.** El tablero Kanban está en Trello.
- **Cada integrante sube sus propios commits**, con su cuenta.
- **Nunca se suben contraseñas ni datos.** El `.gitignore` deja fuera los CSV, los `.env` y las
  salidas de SQL\*Loader.
- **Los scripts que corren en Linux** (`.sh`, `.ctl`, `.sql`, `.py`) se guardan con saltos de línea
  LF. Lo fuerza el `.gitattributes`, aunque se editen en Windows.
