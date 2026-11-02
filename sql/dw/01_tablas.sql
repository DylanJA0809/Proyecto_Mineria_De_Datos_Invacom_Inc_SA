-- =====================================================================
-- Modelo estrella de ventas Olist (Invacom Inc. S.A.)
-- Esquema: OLIST_DW 
-- Orden: primero las dimensiones y al final la tabla de hechos
-- =====================================================================

-------------------------------------------------------------
-- DIMENSIÓN FECHA
-- La llave es la fecha como número: 20180519
-- ---------------------------------------------------------------------
CREATE TABLE dim_fecha (
    fecha_key       NUMBER(8)     NOT NULL,
    fecha           DATE          NOT NULL,
    anio            NUMBER(4)     NOT NULL,
    trimestre       NUMBER(1)     NOT NULL,
    mes             NUMBER(2)     NOT NULL,
    nombre_mes      VARCHAR2(10)  NOT NULL,
    dia_semana      NUMBER(1)     NOT NULL,
    nombre_dia      VARCHAR2(10)  NOT NULL,
    fin_de_semana   CHAR(1)       NOT NULL,
    CONSTRAINT pk_dim_fecha PRIMARY KEY (fecha_key),
    CONSTRAINT uq_dim_fecha_fecha UNIQUE (fecha),
    CONSTRAINT ck_dim_fecha_fin CHECK (fin_de_semana IN ('S','N'))
);

-- ---------------------------------------------------------------------
-- DIMENSIÓN PRODUCTO
-- Categoría en inglés, los sin categoría o sin traducción se
-- resuelven en staging
-- ---------------------------------------------------------------------
CREATE TABLE dim_producto (
    producto_key    NUMBER(10)    GENERATED ALWAYS AS IDENTITY,
    product_id      VARCHAR2(32)  NOT NULL,
    categoria       VARCHAR2(60),
    peso_g          NUMBER(6),
    rango_peso      VARCHAR2(12),
    CONSTRAINT pk_dim_producto PRIMARY KEY (producto_key),
    CONSTRAINT uq_dim_producto_id UNIQUE (product_id)
);

-- ---------------------------------------------------------------------
-- DIMENSION CLIENTE
-- recompra = 'S' si tiene más de un pedido (la va a calcular el ETL)
-- ---------------------------------------------------------------------
CREATE TABLE dim_cliente (
    cliente_key         NUMBER(10)    GENERATED ALWAYS AS IDENTITY,
    customer_unique_id  VARCHAR2(32)  NOT NULL,
    ciudad              VARCHAR2(40),
    estado              CHAR(2),
    recompra            CHAR(1)       NOT NULL,
    CONSTRAINT pk_dim_cliente PRIMARY KEY (cliente_key),
    CONSTRAINT uq_dim_cliente_unico UNIQUE (customer_unique_id),
    CONSTRAINT ck_dim_cliente_recompra CHECK (recompra IN ('S','N'))
);

-- ---------------------------------------------------------------------
-- DIMENSIÓN VENDEDOR
-- ---------------------------------------------------------------------
CREATE TABLE dim_vendedor (
    vendedor_key    NUMBER(10)    GENERATED ALWAYS AS IDENTITY,
    seller_id       VARCHAR2(32)  NOT NULL,
    ciudad          VARCHAR2(40),
    estado          CHAR(2),
    CONSTRAINT pk_dim_vendedor PRIMARY KEY (vendedor_key),
    CONSTRAINT uq_dim_vendedor_id UNIQUE (seller_id)
);

-- ---------------------------------------------------------------------
-- TABLA DE HECHOS: VENTAS
-- PK compuesta: order_id + order_item_id
-- ---------------------------------------------------------------------
CREATE TABLE fact_ventas (
    -- Llaves a las dimensiones
    fecha_key       NUMBER(8)     NOT NULL,
    cliente_key     NUMBER(10)    NOT NULL,
    producto_key    NUMBER(10)    NOT NULL,
    vendedor_key    NUMBER(10)    NOT NULL,

    -- Dimensiones degeneradas (se quedan en el hecho)
    order_id        VARCHAR2(32)  NOT NULL,
    order_item_id   NUMBER(3)     NOT NULL,
    estado_pedido   VARCHAR2(12)  NOT NULL,

    -- Medidas del producto
    precio          NUMBER(10,2)  NOT NULL,
    flete           NUMBER(10,2)  NOT NULL,
    hora_compra     NUMBER(2),

    -- Medidas del pedido
    -- Pueden quedar vacías: pedidos sin entregar o sin reseña
    dias_entrega    NUMBER(4),
    dias_atraso     NUMBER(4),
    a_tiempo        CHAR(1),
    puntaje_resena  NUMBER(3,2),

    CONSTRAINT pk_fact_ventas PRIMARY KEY (order_id, order_item_id),
    CONSTRAINT fk_fact_fecha    FOREIGN KEY (fecha_key)    REFERENCES dim_fecha (fecha_key),
    CONSTRAINT fk_fact_cliente  FOREIGN KEY (cliente_key)  REFERENCES dim_cliente (cliente_key),
    CONSTRAINT fk_fact_producto FOREIGN KEY (producto_key) REFERENCES dim_producto (producto_key),
    CONSTRAINT fk_fact_vendedor FOREIGN KEY (vendedor_key) REFERENCES dim_vendedor (vendedor_key),
    CONSTRAINT ck_fact_a_tiempo CHECK (a_tiempo IN ('S','N'))
);


-- =====================================================================
-- CARGA DE DIM_FECHA
-- =====================================================================
-- Que hace?
--   Llena la tabla dim_fecha con un día por fila, desde el 01/01/2016
--   hasta el 31/12/2018 (1 096 filas).
--   El CREATE TABLE solo crea la tabla vacía, por eso se necesita
--   este INSERT. Sin esto el, fact_ventas no tendria con que unirse
--   por fecha_key.
--
-- Para que sirve?
--   En fact_ventas solo se guarda la fecha como número (ejem 20180519)
--   Con el join a dim_fecha se obtiene año, trimestre, mes, nombre
--   del día y si fue fin de semana, sin calcularlo en cada consulta
--
-- Si quieren verificar lo que hace pueden ejecutar:
--   SELECT * FROM dim_fecha WHERE fecha_key = 20180519;
--     deberia darnos: Mayo, Sábado, dia_semana = 6, fin_de_semana = 'S'
-- =====================================================================
 
INSERT INTO dim_fecha
    (fecha_key, fecha, anio, trimestre, mes, nombre_mes,
     dia_semana, nombre_dia, fin_de_semana)
SELECT
    TO_NUMBER(TO_CHAR(d, 'YYYYMMDD')),
    d,
    EXTRACT(YEAR FROM d),
    TO_NUMBER(TO_CHAR(d, 'Q')),
    EXTRACT(MONTH FROM d),
    INITCAP(TRIM(TO_CHAR(d, 'Month', 'NLS_DATE_LANGUAGE=SPANISH'))),
    (d - TRUNC(d, 'IW')) + 1,
    INITCAP(TRIM(TO_CHAR(d, 'Day', 'NLS_DATE_LANGUAGE=SPANISH'))),
    CASE WHEN (d - TRUNC(d, 'IW')) + 1 IN (6, 7) THEN 'S' ELSE 'N' END
FROM (
    SELECT DATE '2016-01-01' + LEVEL - 1 AS d
    FROM dual
    CONNECT BY LEVEL <= DATE '2018-12-31' - DATE '2016-01-01' + 1
)

COMMIT -- Es una linea que se ejecuta despues del insert


