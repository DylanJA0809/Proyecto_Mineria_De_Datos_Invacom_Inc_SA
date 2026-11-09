# Job de Glue (parte B, STG -> DW): fact_ventas
# Une los items de pedido (v_fact_ventas) con las medidas del pedido (stg_pedidos) y les pone las
# llaves sustitutas de las dimensiones. Una fila por item: order_id + order_item_id.
# Antes hay que correr stg_pedidos y los jobs de las 3 dimensiones (dim_fecha ya viene cargada).

import sys
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql import functions as F

args = getResolvedOptions(sys.argv, ["JOB_NAME", "ORA_URL", "ORA_USER", "ORA_PASSWORD"])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

URL = args["ORA_URL"]
PASSWORD = args["ORA_PASSWORD"]
USUARIO = {
    "stg": args["ORA_USER"] + "[olist_stg]",  # ve OLIST_SRC y OLIST_STG
    "dw": args["ORA_USER"] + "[olist_dw]",
}


def conexion(esquema):
    return {
        "url": URL,
        "driver": "oracle.jdbc.OracleDriver",
        "user": USUARIO[esquema],
        "password": PASSWORD,
    }


def consultar(sql, esquema):
    return (
        spark.read.format("jdbc")
        .options(**conexion(esquema))
        .option("query", sql)
        .option("fetchsize", 5000)
        .load()
    )


def leer(sql, esquema="stg"):
    df = consultar(sql, esquema).cache()
    print("filas leidas:", df.count())
    return df


def ejecutar(sql, esquema="dw"):
    # para sentencias que Spark no hace solo (MERGE, DROP)
    jvm = spark.sparkContext._gateway.jvm
    props = jvm.java.util.Properties()
    props.setProperty("user", USUARIO[esquema])
    props.setProperty("password", PASSWORD)
    conn = jvm.oracle.jdbc.OracleDriver().connect(URL, props)
    try:
        st = conn.createStatement()
        filas = st.executeUpdate(sql)
        st.close()
        return filas
    finally:
        conn.close()


def escribir(df, tabla, esquema="stg"):
    # la tabla tiene que existir con su DDL, si no Spark la crea con otros tipos
    existe = consultar(
        f"select 1 from user_tables where table_name = '{tabla.upper()}'", esquema
    ).count()
    if not existe:
        raise Exception(f"{tabla} no existe en olist_{esquema}, correr antes su DDL")
    (
        df.write.format("jdbc")
        .options(**conexion(esquema))
        .option("dbtable", tabla)
        .option("truncate", "true")
        .mode("overwrite")
        .save()
    )
    print(f"filas escritas en {tabla}:", df.count())


def cargar_dimension(df, tabla, llave, columnas):
    # MERGE por la llave natural: no cambia la llave sustituta ni rompe fact_ventas
    llave = llave.upper()
    columnas = [c.upper() for c in columnas]
    df = df.toDF(*[c.upper() for c in df.columns]).select(llave, *columnas)

    if df.count() != df.select(llave).distinct().count():
        raise Exception(f"{llave} viene repetida, tiene que ser una fila por {llave}")

    tmp = "tmp_" + tabla
    (
        df.write.format("jdbc")
        .options(**conexion("dw"))
        .option("dbtable", tmp)
        .mode("overwrite")
        .save()
    )

    actualizar = ", ".join("d." + c + " = s." + c for c in columnas)
    insertar = ", ".join(columnas)
    valores = ", ".join("s." + c for c in columnas)
    filas = ejecutar(f"""
        merge into {tabla} d
        using {tmp} s
        on (d.{llave} = s.{llave})
        when matched then update set {actualizar}
        when not matched then insert ({llave}, {insertar})
        values (s.{llave}, {valores})
    """)
    ejecutar(f"drop table {tmp} purge")
    print(f"filas actualizadas o insertadas en {tabla}:", filas)


# ---------- B. stg_pedidos + items (STG) -> fact_ventas (DW) ----------

items = leer("""
    select order_id, order_item_id, product_id, seller_id, precio, flete
    from olist_src.v_fact_ventas
""")

pedidos = leer("""
    select order_id, customer_unique_id, estado_pedido, fecha_key, hora_compra,
           dias_entrega, dias_atraso, a_tiempo, puntaje_resena
    from stg_pedidos
""")

# llaves sustitutas de cada dimension
clientes = leer("select customer_unique_id, cliente_key from dim_cliente", "dw")
productos = leer("select product_id, producto_key from dim_producto", "dw")
vendedores = leer("select seller_id, vendedor_key from dim_vendedor", "dw")
fechas = leer("select fecha_key, 1 as en_dim_fecha from dim_fecha", "dw")

for nombre, dim in [("dim_cliente", clientes), ("dim_producto", productos),
                    ("dim_vendedor", vendedores), ("dim_fecha", fechas)]:
    if dim.count() == 0:
        raise Exception(f"{nombre} esta vacia, correr antes su job")

# left join para poder contar lo que no encuentra su llave
df = (
    items.join(pedidos, "ORDER_ID", "left")
    .join(clientes, "CUSTOMER_UNIQUE_ID", "left")
    .join(productos, "PRODUCT_ID", "left")
    .join(vendedores, "SELLER_ID", "left")
    .join(fechas, "FECHA_KEY", "left")
    .cache()
)

faltan = {
    "pedido en stg_pedidos": df.filter(F.col("ESTADO_PEDIDO").isNull()).count(),
    "cliente_key": df.filter(F.col("CLIENTE_KEY").isNull()).count(),
    "producto_key": df.filter(F.col("PRODUCTO_KEY").isNull()).count(),
    "vendedor_key": df.filter(F.col("VENDEDOR_KEY").isNull()).count(),
    "fecha_key en dim_fecha": df.filter(F.col("EN_DIM_FECHA").isNull()).count(),
}
if any(faltan.values()):
    raise Exception(f"items sin su llave: {faltan}")

# una fila por item
if df.count() != df.select("ORDER_ID", "ORDER_ITEM_ID").distinct().count():
    raise Exception("order_id + order_item_id viene repetida")

# cuadre con la fuente: mismas filas, mismo precio y mismo flete
fuente = consultar("""
    select count(*) n, sum(price) precio, sum(freight_value) flete
    from olist_src.olist_order_items_dataset
""", "stg").first()
total = df.agg(F.count("*").alias("n"), F.sum("PRECIO").alias("precio"), F.sum("FLETE").alias("flete")).first()
if (total["n"], total["precio"], total["flete"]) != (fuente["N"], fuente["PRECIO"], fuente["FLETE"]):
    raise Exception(f"no cuadra con la fuente: {total} contra {fuente}")
print("items:", total["n"], "precio:", total["precio"], "flete:", total["flete"])

# tipos y columnas de fact_ventas
df = df.select(
    F.col("FECHA_KEY").cast("int"),
    F.col("CLIENTE_KEY").cast("long"),
    F.col("PRODUCTO_KEY").cast("long"),
    F.col("VENDEDOR_KEY").cast("long"),
    "ORDER_ID",
    F.col("ORDER_ITEM_ID").cast("int"),
    "ESTADO_PEDIDO",
    F.col("PRECIO").cast("decimal(10,2)"),
    F.col("FLETE").cast("decimal(10,2)"),
    F.col("HORA_COMPRA").cast("int"),
    F.col("DIAS_ENTREGA").cast("int"),
    F.col("DIAS_ATRASO").cast("int"),
    "A_TIEMPO",
    F.col("PUNTAJE_RESENA").cast("decimal(3,2)"),
)

# una sola conexion: con los indices bitmap, varias escribiendo a la vez se bloquean
df = df.coalesce(1).cache()

escribir(df, "fact_ventas", "dw")


job.commit()
