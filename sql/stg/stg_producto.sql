-- DDL de la tabla de staging de productos.
-- Correr como olist_stg (o glue_etl[olist_stg] por proxy) en XEPDB1.
-- La tabla se vacía y recarga en cada ejecución del job stg_producto.py.

CREATE TABLE stg_producto (
    product_id  VARCHAR2(32)  NOT NULL,
    categoria   VARCHAR2(60),
    peso_g      NUMBER(6),
    rango_peso  VARCHAR2(12),
    CONSTRAINT pk_stg_producto PRIMARY KEY (product_id)
);