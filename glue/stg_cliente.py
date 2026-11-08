# Job de Glue (parte A, SRC -> STG): stg_cliente
# Lee la vista v_dim_cliente de OLIST_SRC, normaliza las ciudades y deja el resultado en stg_cliente
# Antes hay que correr sql/stg/tablas_stg_cliente_vendedor.sql (crea stg_cliente en OLIST_STG)


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


def normalizar_ciudad(col):
    # regla 22 de docs/calidad-datos.md: minusculas, sin espacios de mas y sin acentos
    # (translate cambia cada letra con acento por su version sin acento)
    con_acento = "áàâãäéèêëíìîïóòôõöúùûüçñ"
    sin_acento = "aaaaaeeeeiiiiooooouuuucn"
    return F.translate(F.lower(F.trim(col)), con_acento, sin_acento)


# ---------- A. v_dim_cliente (OLIST_SRC) -> stg_cliente (OLIST_STG) ----------

df = leer("""
    select customer_unique_id, ciudad, estado, recompra
    from olist_src.v_dim_cliente
""")

# ciudades normalizadas
df = df.withColumn("CIUDAD", normalizar_ciudad(F.col("CIUDAD")))

# una fila por customer_unique_id, ninguna fuera
if df.count() != df.select("CUSTOMER_UNIQUE_ID").distinct().count():
    raise Exception("customer_unique_id viene repetida, tiene que ser una fila por customer_unique_id")

# columnas en mayuscula, como las crea Oracle
df = df.toDF(*[c.upper() for c in df.columns])

escribir(df, "stg_cliente")


job.commit()
