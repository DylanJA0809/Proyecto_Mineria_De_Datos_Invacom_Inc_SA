# Job de Glue (parte A, SRC -> STG): stg_vendedor
# Lee la vista v_dim_vendedor de OLIST_SRC, normaliza las ciudades (regla 22) y deja el resultado en stg_vendedor
# Antes hay que correr sql/stg/tablas_stg_cliente_vendedor.sql (crea stg_vendedor en OLIST_STG)

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
    con_acento = "áàâãäéèêëíìîïóòôõöúùûüçñ´"
    sin_acento = "aaaaaeeeeiiiiooooouuuucn'"
    col = F.lower(F.trim(col))
    col = F.regexp_replace(col, r"\p{M}", "")  # tildes sueltas, como en "são paulo"
    col = F.translate(col, con_acento, sin_acento)
    return F.regexp_replace(col, " +", " ")


# Aun con la normalizacion quedan ciudades que no son correctas, por ejemplo:
CORRECCIONES = {
    # con el estado pegado
    "andira-pr": "andira",
    "angra dos reis rj": "angra dos reis",
    "auriflama/sp": "auriflama",
    "barbacena/ minas gerais": "barbacena",
    "brasilia df": "brasilia",
    "carapicuiba / sao paulo": "carapicuiba",
    "cariacica / es": "cariacica",
    "jacarei / sao paulo": "jacarei",
    "lages - sc": "lages",
    "maua/sao paulo": "maua",
    "mogi das cruzes / sp": "mogi das cruzes",
    "novo hamburgo, rio grande do sul, brasil": "novo hamburgo",
    "pinhais/pr": "pinhais",
    "ribeirao preto / sao paulo": "ribeirao preto",
    "rio de janeiro / rio de janeiro": "rio de janeiro",
    "rio de janeiro \\rio de janeiro": "rio de janeiro",
    "rio de janeiro, rio de janeiro, brasil": "rio de janeiro",
    "santo andre/sao paulo": "santo andre",
    "sao paulo - sp": "sao paulo",
    "sao paulo / sao paulo": "sao paulo",
    "sao paulo sp": "sao paulo",
    "sao sebastiao da grama/sp": "sao sebastiao da grama",
    "sbc/sp": "sao bernardo do campo",
    "sp / sp": "sao paulo",
    # mal escritas
    "ao bernardo do campo": "sao bernardo do campo",
    "balenario camboriu": "balneario camboriu",
    "belo horizont": "belo horizonte",
    "cascavael": "cascavel",
    "floranopolis": "florianopolis",
    "garulhos": "guarulhos",
    "ji parana": "ji-parana",
    "juzeiro do norte": "juazeiro do norte",
    "mogi das cruses": "mogi das cruzes",
    "paincandu": "paicandu",
    "portoferreira": "porto ferreira",
    "ribeirao pretp": "ribeirao preto",
    "riberao preto": "ribeirao preto",
    "robeirao preto": "ribeirao preto",
    "s jose do rio preto": "sao jose do rio preto",
    "sando andre": "santo andre",
    "sao bernardo do capo": "sao bernardo do campo",
    "sao jose do rio pret": "sao jose do rio preto",
    "sao jose dos pinhas": "sao jose dos pinhais",
    "sao miguel d'oeste": "sao miguel do oeste",
    "sao paluo": "sao paulo",
    "sao paulop": "sao paulo",
    "sao pauo": "sao paulo",
    "sbc": "sao bernardo do campo",
    "scao jose do rio pardo": "sao jose do rio pardo",
    "tabao da serra": "taboao da serra",
    # barrio o distrito: va el municipio
    "aguas claras df": "brasilia",
    "arraial d'ajuda (porto seguro)": "porto seguro",
    "castro pires": "teofilo otoni",
    "centro": "para de minas",
    "pirituba": "sao paulo",
    "vicente de carvalho": "guaruja",
    # no es una ciudad: sale del codigo postal
    "04482255": "rio de janeiro",
    "bahia": "paulo afonso",
    "minas gerais": "campo do meio",
    "parana": "maringa",
    "santa catarina": "palhoca",
    "vendas@creditparts.com.br": "maringa",
}


def corregir_ciudad(col):
    mapa = F.create_map(*[F.lit(x) for par in CORRECCIONES.items() for x in par])
    return F.coalesce(mapa[col], col)


# ---------- A. v_dim_vendedor (OLIST_SRC) -> stg_vendedor (OLIST_STG) ----------

df = leer("""
    select seller_id, ciudad, estado
    from olist_src.v_dim_vendedor
""")

# ciudades normalizadas
df = df.withColumn("CIUDAD", corregir_ciudad(normalizar_ciudad(F.col("CIUDAD"))))

# una fila por seller_id, ninguna fuera
if df.count() != df.select("SELLER_ID").distinct().count():
    raise Exception("seller_id viene repetida, tiene que ser una fila por seller_id")

# columnas en mayuscula, asi como las crea Oracle
df = df.toDF(*[c.upper() for c in df.columns])

escribir(df, "stg_vendedor")


job.commit()