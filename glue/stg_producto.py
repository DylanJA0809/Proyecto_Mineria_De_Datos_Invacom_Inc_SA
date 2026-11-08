# Job de Glue (parte A, SRC -> STG): stg_producto
# Lee la vista v_dim_producto de OLIST_SRC, aplica las reglas de limpieza (4, 5 y 6) y deja el resultado en stg_producto
# Antes hay que correr sql/stg/stg_producto.sql (crea stg_producto en OLIST_STG)

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
    # MERGE
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


# ---------- A. v_dim_producto (OLIST_SRC) -> stg_producto (OLIST_STG) ----------

df = leer("""
    select v.product_id,
           p.product_category_name,
           v.categoria,
           v.peso_g,
           v.rango_peso
    from olist_src.v_dim_producto v
    join olist_src.olist_products_dataset p on p.product_id = v.product_id
""")

# Regla 4 y 5: 610 sin categoria pasan a 'sin_categoria', y las 2 sin traduccion usan sus nombres oficiales
df = df.withColumn(
    "CATEGORIA",
    F.when(F.col("PRODUCT_CATEGORY_NAME").isNull(), F.lit("sin_categoria"))
    .when(F.col("PRODUCT_CATEGORY_NAME") == "pc_gamer", F.lit("pc_gamer"))
    .when(
        F.col("PRODUCT_CATEGORY_NAME") == "portateis_cozinha_e_preparadores_de_alimentos",
        F.lit("portable_kitchen_and_food_preparers"),
    )
    .otherwise(F.col("CATEGORIA")),
)

# Regla 6: peso 0 pasa a nulo (NULLIF)
df = df.withColumn(
    "PESO_G",
    F.when(F.col("PESO_G") == 0, F.lit(None)).otherwise(F.col("PESO_G")),
)

# Cortes de rango_peso segun como se reparten los pesos (ninguno supera 12 caracteres para VARCHAR2(12))
df = df.withColumn(
    "RANGO_PESO",
    F.when(F.col("PESO_G").isNull(), F.lit("Sin peso"))
    .when(F.col("PESO_G") < 500, F.lit("< 500 g"))
    .when(F.col("PESO_G") < 2000, F.lit("500g - 2kg"))
    .when(F.col("PESO_G") < 10000, F.lit("2kg - 10kg"))
    .otherwise(F.lit("10kg o más")),
)

# una fila por product_id, ninguna fuera
if df.count() != df.select("PRODUCT_ID").distinct().count():
    raise Exception("product_id viene repetida, tiene que ser una fila por product_id")

# dejar solo las columnas de la tabla de staging
df = df.select("PRODUCT_ID", "CATEGORIA", "PESO_G", "RANGO_PESO")

# columnas en mayuscula, como las crea Oracle
df = df.toDF(*[c.upper() for c in df.columns])

escribir(df, "stg_producto")


job.commit()
