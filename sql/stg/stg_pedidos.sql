-- Tabla de staging de pedidos: una fila por order_id con los datos del pedido que van en fact_ventas.
-- Correr como [olist_stg], una sola vez, antes del job glue/stg_pedidos.py.
-- La tabla se vacía y recarga en cada ejecución del job.
-- Los nombres y tamaños son los de fact_ventas en sql/dw/01_tablas.sql.

CREATE TABLE stg_pedidos (
    order_id            VARCHAR2(32)  NOT NULL,
    customer_unique_id  VARCHAR2(32)  NOT NULL,   -- la persona, no el customer_id del pedido
    estado_pedido       VARCHAR2(12)  NOT NULL,
    fecha_key           NUMBER(8)     NOT NULL,   -- fecha de compra como AAAAMMDD
    hora_compra         NUMBER(2)     NOT NULL,   -- 0 a 23
    -- Vacías si el pedido no tiene fecha de entrega al cliente (reglas 3 y 16)
    dias_entrega        NUMBER(4),
    dias_atraso         NUMBER(4),                -- negativo si llegó antes de lo prometido
    a_tiempo            CHAR(1),
    -- Vacía si el pedido no tiene reseña (regla 12); si tiene varias, la más reciente (regla 9a)
    puntaje_resena      NUMBER(3,2),
    CONSTRAINT pk_stg_pedidos PRIMARY KEY (order_id),
    CONSTRAINT ck_stg_pedidos_a_tiempo CHECK (a_tiempo IN ('S','N'))
);
