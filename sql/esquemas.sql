-- Esquemas de staging y DW. Correr como SYSTEM en XEPDB1.
-- Se entra por proxy: usuario[olist_stg] o usuario[olist_dw]

create user olist_stg no authentication
  default tablespace users quota unlimited on users;
create user olist_dw no authentication
  default tablespace users quota unlimited on users;

grant create session, create table, create view, create sequence to olist_stg;
grant create session, create table, create view, create sequence,
      create materialized view to olist_dw;

-- staging lee de la fuente
grant olist_lector to olist_stg;
-- el DW la lee para sql/validacion.sql
grant olist_lector to olist_dw;

-- proxy
alter user olist_stg grant connect through josue;
alter user olist_stg grant connect through karol;
alter user olist_stg grant connect through katherine;
alter user olist_stg grant connect through dylan;
alter user olist_stg grant connect through glue_etl;

alter user olist_dw grant connect through josue;
alter user olist_dw grant connect through karol;
alter user olist_dw grant connect through katherine;
alter user olist_dw grant connect through dylan;
alter user olist_dw grant connect through glue_etl;

-- las tablas van en olist_stg / olist_dw, no en los esquemas personales
revoke create table, create view from josue;
revoke create table, create view from karol;
revoke create table, create view from katherine;
revoke create table, create view from dylan;
