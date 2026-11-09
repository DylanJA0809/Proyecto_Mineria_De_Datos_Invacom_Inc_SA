# Conectar Excel al DW

Excel lee `OLIST_DW` por **ODBC**, con el driver de Oracle, a través de **Tailscale**. Se entra con
el usuario personal por proxy: `usuario[olist_dw]` (por ejemplo `dylan[olist_dw]`) y la contraseña
de siempre.

Se hace una sola vez por computadora. Hace falta Windows y Excel de escritorio: Excel en el navegador
no puede conectarse por ODBC.

## 1. Tailscale

1. Instalar Tailscale desde [tailscale.com/download](https://tailscale.com/download) e iniciar
   sesión con la cuenta que se invitó a la red del grupo.
2. En el menú de Tailscale tiene que aparecer el servidor de Oracle, `salvatandas` (la máquina de
   Josué, compartida con cada cuenta).
3. Comprobar en PowerShell que se llega al puerto de Oracle:
   ```powershell
   Test-NetConnection salvatandas.tailbc2329.ts.net -Port 1521
   ```
   Tiene que decir `TcpTestSucceeded : True`.

## 2. Driver ODBC de Oracle

El driver tiene que ser de la **misma arquitectura que Excel**. Casi siempre es de 64 bits; se ve en
*Archivo > Cuenta > Acerca de Excel*.

1. Descargar de [Oracle Instant Client para Windows](https://www.oracle.com/database/technologies/instant-client/downloads.html)
   (x64 si Excel es de 64 bits) dos paquetes **de la misma versión**: *Basic Package* y *ODBC
   Package*.
2. Guardar los dos ZIP en `C:\oracle` y descomprimirlos ahí. Los dos traen adentro la misma
   carpeta (por ejemplo `instantclient_23_26`), así que sus archivos quedan juntos. Desde PowerShell:
   ```powershell
   cd C:\oracle
   Expand-Archive .\instantclient-basic-windows.x64-*.zip -DestinationPath C:\oracle -Force
   Expand-Archive .\instantclient-odbc-windows.x64-*.zip -DestinationPath C:\oracle -Force
   ls C:\oracle\instantclient_23_26\oci.dll, C:\oracle\instantclient_23_26\sqora32.dll
   ```
   Tienen que aparecer los dos archivos: `oci.dll` es del *Basic* y `sqora32.dll` del *ODBC*.
3. Instalar el driver, en PowerShell **como administrador**:
   ```powershell
   cd C:\oracle\instantclient_23_26
   .\odbc_install.exe
   ```
   Tiene que decir `Oracle ODBC Driver is installed successfully.`
4. Agregar la carpeta al `Path` del usuario (PowerShell normal):
   ```powershell
   $actual = [Environment]::GetEnvironmentVariable("Path", "User")
   [Environment]::SetEnvironmentVariable("Path", "$actual;C:\oracle\instantclient_23_26", "User")
   ```
   Después, cerrar y volver a abrir el administrador ODBC y Excel, que leen el `Path` al iniciar.

Si la versión descargada es otra, la carpeta cambia de nombre (`instantclient_23_xx`): usar ese
nombre en los pasos 2 a 4 y en el DSN.

## 3. Origen de datos (DSN)

1. Abrir **Orígenes de datos ODBC (64 bits)** desde el menú Inicio.
2. Pestaña **DSN de usuario > Agregar**, elegir **Oracle in instantclient_23_26** y llenar:

   | Campo | Valor |
   |---|---|
   | Data Source Name | `OLIST_DW` |
   | TNS Service Name | `salvatandas.tailbc2329.ts.net:1521/XEPDB1` |
   | User ID | `usuario[olist_dw]` |

3. **Test Connection** con la contraseña. Tiene que decir *Connection successful*.

## 4. Traer las tablas a Excel

1. En Excel: **Datos > Obtener datos > De otras fuentes > Desde ODBC**, elegir `OLIST_DW`.
2. Si pide credenciales, ir a **Base de datos** y poner `usuario[olist_dw]` y la contraseña.
3. En el navegador, abrir el esquema `OLIST_DW`, marcar **Seleccionar varios elementos** y elegir
   `FACT_VENTAS`, `DIM_FECHA`, `DIM_PRODUCTO`, `DIM_CLIENTE` y `DIM_VENDEDOR`.
4. **Cargar en…** > **Solo crear conexión** y marcar **Agregar estos datos al modelo de datos**.

Se tienen que ver las 5 en el panel **Consultas y conexiones**, con sus filas: `DIM_FECHA` 1 096,
`DIM_CLIENTE` 96 096, `DIM_VENDEDOR` 3 095, `DIM_PRODUCTO` 32 951 y `FACT_VENTAS` 112 650. Si una sale
con 0 filas, falta correr su job de Glue.

Hay que cargarlas al **modelo de datos**: es lo único que permite unir el hecho con las dimensiones
y usar **Recuento distinto**, que hace falta para contar pedidos (ver `docs/modelo-dimensional.md`).

## 5. Relaciones

En **Datos > Relaciones** tienen que quedar estas cuatro. Si falta alguna, se crea con **Nueva**:

| Tabla | Columna | Tabla relacionada | Columna relacionada |
|---|---|---|---|
| `FACT_VENTAS` | `FECHA_KEY` | `DIM_FECHA` | `FECHA_KEY` |
| `FACT_VENTAS` | `PRODUCTO_KEY` | `DIM_PRODUCTO` | `PRODUCTO_KEY` |
| `FACT_VENTAS` | `CLIENTE_KEY` | `DIM_CLIENTE` | `CLIENTE_KEY` |
| `FACT_VENTAS` | `VENDEDOR_KEY` | `DIM_VENDEDOR` | `VENDEDOR_KEY` |

## 6. Tabla dinámica de prueba

**Insertar > Tabla dinámica > Desde el modelo de datos**, y armar:

- **Filas:** `DIM_PRODUCTO` → `CATEGORIA`
- **Columnas:** `DIM_FECHA` → `ANIO`
- **Valores:**
  - `PRECIO` como **Suma**
  - `ORDER_ID` como **Recuento distinto** (*Configuración de campo de valor*)
  - `DIAS_ENTREGA` como **Promedio**

Para comprobar que cuadra, el total general tiene que coincidir con esta consulta en `OLIST_DW`:

```sql
select sum(precio), count(distinct order_id), round(avg(dias_entrega), 2)
from fact_ventas;
```

## Problemas comunes

| Error | Causa |
|---|---|
| `TcpTestSucceeded : False` | Tailscale apagado, sin sesión, o el servidor de Oracle apagado |
| El driver no aparece al crear el DSN | Se abrió el administrador ODBC de 32 bits, o falta correr `odbc_install.exe` |
| `ORA-12154` / `ORA-12514` | El *TNS Service Name* está mal: tiene que ser `salvatandas.tailbc2329.ts.net:1521/XEPDB1` |
| `odbc_install.exe` no existe | Falta descomprimir el *ODBC Package* en la misma carpeta (paso 2) |
| `ORA-01017` | Usuario o contraseña incorrectos; el usuario lleva `[olist_dw]` |
| `ORA-28150` | Al usuario le falta el permiso de proxy a `OLIST_DW` (`sql/esquemas.sql`) |
| No sale *Recuento distinto* | Las tablas no se cargaron al modelo de datos (paso 4) |
