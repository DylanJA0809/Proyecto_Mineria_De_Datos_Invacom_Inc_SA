# Job de Glue (parte A, SRC -> STG): stg_pedidos
# Lee la vista v_fact_ventas de OLIST_SRC (una fila por producto), la agrupa por pedido y deja en
# stg_pedidos una fila por order_id con los datos del pedido que van en fact_ventas: estado, fecha y
# hora de compra, dias_entrega, dias_atraso, a_tiempo y puntaje_resena.
# Antes hay que correr sql/stg/stg_pedidos.sql (crea stg_pedidos en OLIST_STG)

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


# ---------- A. v_fact_ventas (OLIST_SRC) -> stg_pedidos (OLIST_STG) ----------
# La vista ya calcula las medidas del pedido:
#   - dias_entrega, dias_atraso y a_tiempo quedan vacios si no hay fecha de entrega (reglas 3 y 16)
#   - dias_atraso es negativo si el pedido llego antes de la fecha prometida
#   - puntaje_resena es la resena mas reciente (regla 9a) y queda vacio si no hay (regla 12)
# Como la vista viene por producto, esos datos se repiten en cada producto del mismo pedido.

df = leer("""
    select order_id, customer_unique_id, estado_pedido, fecha_key, hora_compra,
           dias_entrega, dias_atraso, a_tiempo, puntaje_resena
    from olist_src.v_fact_ventas
""")

# columnas en mayuscula, como las crea Oracle
df = df.toDF(*[c.upper() for c in df.columns])

# tipos de la tabla de staging (Oracle los entrega como NUMBER sin precision)
df = (
    df.withColumn("FECHA_KEY", F.col("FECHA_KEY").cast("int"))
    .withColumn("HORA_COMPRA", F.col("HORA_COMPRA").cast("int"))
    .withColumn("DIAS_ENTREGA", F.col("DIAS_ENTREGA").cast("int"))
    .withColumn("DIAS_ATRASO", F.col("DIAS_ATRASO").cast("int"))
    .withColumn("PUNTAJE_RESENA", F.col("PUNTAJE_RESENA").cast("decimal(3,2)"))
)

# agrupar por pedido: una fila por order_id
df = df.distinct()

# si un pedido trajera datos distintos en sus productos, aqui saldria repetido
if df.count() != df.select("ORDER_ID").distinct().count():
    raise Exception("order_id viene repetida, tiene que ser una fila por order_id")

# sin customer_unique_id el job de hechos no sabe de quien es la venta
sin_cliente = df.filter(F.col("CUSTOMER_UNIQUE_ID").isNull()).count()
if sin_cliente:
    raise Exception(f"{sin_cliente} pedidos sin customer_unique_id")

# que el estado quepa en VARCHAR2(12)
largos = df.filter(F.length("ESTADO_PEDIDO") > 12).count()
if largos:
    raise Exception(f"{largos} pedidos con estado_pedido de mas de 12 caracteres")

# cuadre con la fuente: los pedidos con al menos un producto (los 775 sin productos no entran, regla 10)
pedidos_fuente = consultar(
    "select count(distinct order_id) n from olist_src.olist_order_items_dataset", "stg"
).first()[0]
if df.count() != pedidos_fuente:
    raise Exception(f"no cuadra: {df.count()} pedidos en staging y {pedidos_fuente} en la fuente")

# resumen para el log
print("pedidos:", df.count())
print("sin fecha de entrega:", df.filter(F.col("DIAS_ENTREGA").isNull()).count())
print("sin resena:", df.filter(F.col("PUNTAJE_RESENA").isNull()).count())
df.groupBy("A_TIEMPO").count().show()

df = df.select(
    "ORDER_ID", "CUSTOMER_UNIQUE_ID", "ESTADO_PEDIDO", "FECHA_KEY", "HORA_COMPRA",
    "DIAS_ENTREGA", "DIAS_ATRASO", "A_TIEMPO", "PUNTAJE_RESENA",
)

escribir(df, "stg_pedidos")


job.commit()
