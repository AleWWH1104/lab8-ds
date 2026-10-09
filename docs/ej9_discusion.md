# Ejercicio 9 - Discusion

Las respuestas se apoyan en lo que se midio o documento en los ejercicios anteriores: [Ej. 3](ej3_exploracion.md), [Ej. 5](ej5_incorporacion.md), [Ej. 6](ej6_benchmark.md), [Ej. 7](ej7_indicadores.md) y [Ej. 8](ej8_incorporacion.md). Cuando algo no se midio, se dice.

## 9.1 Que caracteristicas de DuckDB resultaron mas utiles

- **Corre dentro del proceso, sin servidor.** No hubo que instalar, configurar ni mantener una base de datos: `import duckdb` dentro del contenedor bastaba. Es lo que pide el enunciado ("sin depender de un servidor de base de datos tradicional").
- **Lee Parquet con comodines.** `read_parquet('data/raw/yellow/*/*.parquet')` convierte los 32 archivos de cada tipo en una sola relacion. Con `filename = true` se obtiene el nombre del archivo, y de ahi salen el anio y el mes de cada viaje.
- **`union_by_name = true`.** Cuando 2025 trajo la columna `cbd_congestion_fee` y 2026 trajo `request_source`, las consultas no se rompieron: DuckDB las deja en `NULL` en los archivos que no las tienen.
- **Metadatos de Parquet como tablas.** `parquet_file_metadata` y `glob` permitieron comprobar que el numero de registros segun los metadatos coincide con el leido (121,184,384 en total) sin escribir codigo adicional.
- **SQL analitico moderno.** `FILTER`, `QUALIFY`, `DISTINCT ON`, `median`, `GROUP BY ALL` y funciones de ventana simplificaron mucho las consultas del Ej. 4 y del Ej. 7. Por ejemplo, la deduplicacion es una sola clausula.
- **Velocidad.** Seis consultas analiticas sobre 72 millones de registros sumaron 2.8 s sobre Parquet y 2.4 s sobre la tabla (Ej. 6).
- **Integracion.** Metabase se conecta a un archivo `.duckdb` con el driver de DuckDB, sin ningun servicio intermedio.

## 9.2 Ventajas y limitaciones de consultar directamente Parquet

**Ventajas**

- No hay paso de carga: un archivo recien descargado se puede consultar de inmediato, lo que encaja con datos que llegan un archivo por mes.
- No se duplican los datos: los Parquet ocupan 1,172 MiB para 2024 y 2026, contra 1,979 MiB de la tabla equivalente.
- Hay preguntas que Parquet responde casi sin leer datos: el conteo por tipo y anio fue mas rapido sobre Parquet (33 ms contra 76 ms) porque la cantidad de filas esta en los metadatos de cada archivo.
- Es un formato abierto: los mismos archivos los puede leer cualquier otra herramienta.

**Limitaciones**

- **Cada consulta vuelve a leer y a recalcular todo.** La vista `viajes_limpios` aplica `DISTINCT ON` sobre 121 millones de filas; cada consulta que pasa por ella tardo entre 6 y 22 segundos (Ej. 8). Eso es aceptable para explorar y no lo es para un tablero.
- **El costo crece con el numero de archivos.** Una consulta con filtro selectivo tardo 33 ms con 2 archivos de un mes y 74 ms con 40 archivos, porque DuckDB abre los metadatos de todos antes de decidir que saltar. La tabla se quedo en 4 ms.
- **El formato no impone calidad.** Los archivos traen viajes con fechas fuera de su mes, duraciones y distancias imposibles y duplicados. Ningun archivo avisa: hubo que descubrirlo con consultas (Ej. 3).
- **Esquema que cambia.** Dos columnas aparecieron en archivos recientes. `union_by_name` lo tolera, pero tambien puede ocultar un cambio que merece revisarse.

## 9.3 Ventajas y limitaciones de las tablas materializadas

**Ventajas**

- **Filtros selectivos mucho mas rapidos:** hasta 18 veces con 72 millones de registros (4 ms contra 74 ms), por las zonemaps (minimo y maximo por bloque de filas).
- **Un solo archivo con los datos ya limpios.** `taxis.duckdb` incluye el filtro base y las columnas calculadas, de modo que las consultas no repiten esas transformaciones.
- **Una herramienta externa puede conectarse.** Metabase necesita una base a la cual conectarse, y la tabla cumple ese papel.
- **Ayuda para precalcular.** El cubo del Ej. 7 (46,828 filas, 2.8 MiB) se construye en 42 s una sola vez y despues cada indicador responde en milisegundos.

**Limitaciones**

- **Espacio:** la tabla de 2024 y 2026 ocupa 1.7 veces lo que los Parquet (1,979 contra 1,172 MiB). Con los tres anios son 3,364 MiB. Los datos quedan duplicados.
- **Se desactualiza.** Es una copia: al llegar archivos nuevos hay que regenerarla (17.5 s con los tres anios).
- **Un solo escritor.** Un archivo `.duckdb` admite un proceso con permiso de escritura a la vez. Por eso Metabase abre el cubo en modo `read_only`, y para regenerarlo conviene detener Metabase o reconectarlo.
- **Para consultas de agregacion simple no hay ventaja.** En formas de pago y propinas, las dos estrategias quedaron dentro de 10 a 20 % una de la otra, y en una Parquet fue algo mas rapido (Ej. 6).
- **Tarda en pagarse.** La carga de 9.2 s se recupera tras unas 19 rondas de las seis consultas del benchmark.

## 9.4 Ventajas frente a cargar todo con Pandas

No se hizo una comparacion medida con Pandas en este laboratorio, asi que lo siguiente combina lo observado con lo que se sabe del funcionamiento de cada herramienta.

- **Memoria.** Pandas carga los datos completos en memoria. DuckDB lee solo las columnas y los grupos de filas que necesita y puede derramar a disco. En el Ej. 3 se estimo que solo los 30 millones de registros de 2026 ocuparian en Pandas "varias veces" sus 496 MB de Parquet; con 121 millones de registros y 25 columnas el conjunto ya no cabe comodamente en el contenedor de 6 a 8 GB que se uso. Aun DuckDB tuvo un limite: una consulta de deduplicacion con `row_number()` fallo por memoria con 72 millones de registros y hubo que fijar `memory_limit` (Ej. 5).
- **Paralelismo.** DuckDB usa todos los nucleos sin configuracion adicional.
- **Sin paso de importacion.** Con Pandas habria que leer y concatenar 64 archivos antes de analizar. Aqui es una sola consulta.
- **SQL.** Las consultas quedan documentadas en archivos `.sql` que se leen y se versionan, y que pueden reutilizarse tal cual en Metabase.
- **Pandas sigue siendo util** para el ultimo paso: una vez que DuckDB reduce el resultado a unas filas, convertirlo a un DataFrame para graficar o modelar es trivial.

## 9.5 Que permite incorporar datos nuevos con cambios minimos

Agregar 2024 (Ej. 5) y 2025 (Ej. 8) requirio cambiar una sola linea de codigo, `ANIOS_POR_DEFECTO`, y ninguna consulta. Lo que lo permite:

- **El script de descarga recibe los anios como parametro** y consulta al servidor que meses estan publicados, en lugar de suponerlos.
- **Es idempotente:** un archivo valido ya existente se omite (segunda corrida: 0 descargados, 64 existentes).
- **Las vistas usan comodines** (`data/raw/<tipo>/*/*.parquet`), asi que un anio nuevo se incluye solo.
- **El anio sale del nombre del archivo** (`anio_archivo`) y no de la fecha del viaje, que a veces esta mal.
- **`union_by_name`** absorbe las columnas nuevas.
- **Las consultas no mencionan anios concretos**, salvo la del cargo de congestion, que filtra desde 2025 porque antes no existia.
- **La tabla y el cubo se regeneran desde cero** con un solo comando cada uno.

## 9.6 Que automatizaria en un sistema de produccion

1. **La descarga periodica.** La TLC publica un mes con varias semanas de atraso; hoy falta septiembre a diciembre de 2026. Un trabajo programado (cron, Airflow o similar) deberia ejecutar `download_data.py` cada cierto tiempo.
2. **Las validaciones como compuertas.** `--verificar` y la comparacion de registros segun metadatos contra registros leidos deberian ser pasos que detienen el proceso si algo falla, en lugar de comprobaciones manuales.
3. **Deteccion de cambios de esquema.** Las columnas nuevas (`cbd_congestion_fee`, `request_source`) se descubrieron a mano. Una alerta cuando aparece una columna o cambia un tipo evitaria sorpresas.
4. **Actualizacion incremental.** Hoy `crear_tabla.py` borra y recrea todo (17.5 s) y el cubo tarda 42 s. Con mas anios convendria agregar solo los meses nuevos.
5. **Refresco del cubo y del tablero** encadenado a la actualizacion de la tabla, de modo que el tablero nunca muestre datos viejos.
6. **Chequeos de calidad con umbrales** (por ejemplo, el porcentaje de registros que conserva el filtro base, hoy entre 94 y 97 %) que avisen si cambian bruscamente.
7. **Credenciales y configuracion.** El usuario de Metabase esta en el script porque el ambiente es local; en produccion irian en un gestor de secretos.

## 9.7 Decisiones de diseno importantes para la reproducibilidad

- **Docker Compose** fija las versiones de DuckDB (`requirements.txt`), de Metabase y de su driver (el `metabase.Dockerfile` pide mantenerlas alineadas), de modo que el ambiente se levanta igual en cualquier maquina.
- **Los datos nunca entran a Git** (`.gitignore`), pero todo lo necesario para obtenerlos y prepararlos si esta versionado.
- **La descarga es verificable:** valida cada archivo con la firma `PAR1` y el tamano publicado, descarga a un archivo temporal y lo renombra al final, y `--verificar` compara contra el servidor.
- **Los datos originales no se modifican.** Los filtros viven en vistas y en consultas; la tabla y el cubo se pueden borrar y regenerar.
- **Todo el SQL esta en archivos** con un formato fijo (`-- N.M Titulo`), y `run_sql.py` guarda cada resultado en markdown. El tablero se genera a partir de esos mismos archivos.
- **El tablero se crea con un script** (`crear_tablero.py`) en lugar de a mano, y se puede repetir sin duplicar tarjetas.
- **Los ejercicios se documentan al hacerse**, con el comando exacto y el resultado observado, y el README reune el procedimiento completo.
- **Comparar solo lo comparable:** todas las comparaciones entre anios usan enero a agosto, porque 2026 no tiene mas meses.

## 9.8 Que se aprendio sobre el manejo de datos que no era evidente con conjuntos pequenos

- **Los problemas de calidad aparecen con el volumen.** Hay unos cientos de viajes por anio con fechas fuera de su mes (420 en yellow 2024; uno de un archivo de 2024 tiene fecha de 2026), y un viaje de 335 mil USD. Con una muestra pequena no se ven, y un promedio sin filtrar habria quedado distorsionado.
- **Entre 3 % y 6 % de los registros no pasa el filtro base** (94.1 % a 96.7 % se conserva). A esa escala son millones de viajes.
- **Lo que funciona con un anio no escala sin revisar.** Al pasar de 30 a 72 millones de registros hubo que ajustar la memoria, y una consulta que antes corria dejo de hacerlo.
- **El costo de una consulta depende de como esta escrita.** Una vista con `DISTINCT ON` sobre 121 millones de filas tarda segundos cada vez; precalcular un cubo la volvio instantanea.
- **La estrategia correcta cambia con el volumen.** Con un mes de datos, el filtro selectivo era 9.6 veces mas rapido sobre la tabla; con 72 millones llego a 18. Las agregaciones simples, en cambio, no cambiaron.
- **Un dato incompleto parece un cambio real.** Septiembre a diciembre de 2026 aparecian como una caida de 100 % solo porque aun no se publicaron. Hay que comparar los mismos meses.
- **Los cambios de significado afectan a los indicadores.** Flex Fare paso de 9 % a 25 % de los viajes yellow y esos viajes no traen pasajeros ni recargos. Cualquier indicador por pasajero o por propina cambia sin que cambie el comportamiento de nadie.
- **Los datos reales cambian de esquema** y hay que detectarlo, no suponerlo.
