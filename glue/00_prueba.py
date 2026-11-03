# Job de prueba: leer una tabla de OLIST_SRC por el tunel y escribir en OLIST_STG por el tunel
# Parametros del job: --ORA_URL, --ORA_USER, --ORA_PASSWORD

import sys
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext

args = getResolvedOptions(sys.argv, ["JOB_NAME", "ORA_URL", "ORA_USER", "ORA_PASSWORD"])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

df = (
    spark.read.format("jdbc")
    .option("url", args["ORA_URL"])
    .option("driver", "oracle.jdbc.OracleDriver")
    .option("user", args["ORA_USER"])
    .option("password", args["ORA_PASSWORD"])
    .option("dbtable", "olist_src.product_category_name_translation")
    .load()
)

print("filas leidas:", df.count())
df.show(10, truncate=False)

(
    df.write.format("jdbc")
    .option("url", args["ORA_URL"])
    .option("driver", "oracle.jdbc.OracleDriver")
    .option("user", args["ORA_USER"])
    .option("password", args["ORA_PASSWORD"])
    .option("dbtable", "product_category_name_translation")
    .mode("overwrite")
    .save()
)

print("escritura en OLIST_STG terminada")

job.commit()
