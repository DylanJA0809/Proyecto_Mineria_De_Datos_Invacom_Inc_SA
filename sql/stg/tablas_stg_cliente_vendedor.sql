-- Tablas de staging de cliente y vendedor.
-- Correr como [olist_stg], una sola vez, antes de los jobs glue/stg_cliente.py y glue/stg_vendedor.py.


CREATE TABLE stg_cliente (
    customer_unique_id  VARCHAR2(32)  NOT NULL,
    ciudad              VARCHAR2(40),
    estado              CHAR(2),
    recompra            CHAR(1)       NOT NULL,
    CONSTRAINT pk_stg_cliente PRIMARY KEY (customer_unique_id)
);

CREATE TABLE stg_vendedor (
    seller_id   VARCHAR2(32)  NOT NULL,
    ciudad      VARCHAR2(40),
    estado      CHAR(2),
    CONSTRAINT pk_stg_vendedor PRIMARY KEY (seller_id)
);

