#!/usr/bin/env python3
"""Descarga los archivos Parquet del NYC TLC Trip Record Data.

Descarga los registros de viajes de taxis amarillos (yellow) y verdes (green)
para uno o varios anios. Por defecto descarga los anios que usa el laboratorio
(ANIOS_POR_DEFECTO); otros anios se pueden pedir con --anios.

Fuente oficial de los datos:
    https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page

Uso:
    python scripts/download_data.py                          # 2024 y 2026, amarillos y verdes
    python scripts/download_data.py --anios 2024 2026        # varios anios
    python scripts/download_data.py --taxi yellow --anios 2025
    python scripts/download_data.py --verificar --anios 2026 # solo verifica, no descarga

Los archivos se guardan en:
    data/raw/<tipo>/<anio>/<nombre-original>.parquet

Comportamiento:
  - La TLC publica cada mes con varias semanas de atraso, por lo que no todos
    los meses existen todavia. El script consulta al servidor que meses estan
    publicados en lugar de suponerlos (el servidor responde 403/404 a los meses
    que no existen).
  - Un archivo que ya existe localmente y es un Parquet valido no se vuelve a
    descargar. Si esta corrupto o truncado, se descarga de nuevo.
  - La descarga se hace sobre un nombre temporal y solo se renombra al
    terminar, de modo que una interrupcion no deja archivos .parquet a medias.
  - Cada descarga se valida contra el tamanio anunciado por el servidor
    (Content-Length) y contra la firma de Parquet ("PAR1" al inicio y al final).
  - Un error de red al consultar un mes se reporta como fallido, no como
    "no publicado", para no ocultar archivos faltantes.
"""

import argparse
import sys
from pathlib import Path

import requests

# Ej. 5: se agrega 2024 al conjunto inicial de 2026.
ANIOS_POR_DEFECTO = (2024, 2026)
TIPOS_TAXI = ("yellow", "green")
URL_BASE = "https://d37ci6vzurychx.cloudfront.net/trip-data"
# Relativo a la raiz del proyecto, no al directorio desde el que se ejecuta.
DIR_DESTINO = Path(__file__).resolve().parent.parent / "data" / "raw"

TIEMPO_ESPERA = 60          # segundos por peticion
INTENTOS = 3                # intentos por archivo antes de darse por vencido
BLOQUE = 1024 * 1024        # 1 MiB por bloque de descarga
SUFIJO_TEMPORAL = ".part"
FIRMA_PARQUET = b"PAR1"
CODIGOS_NO_PUBLICADO = (403, 404)


def construir_nombre(tipo: str, anio: int, mes: int) -> str:
    """Nombre del archivo publicado por la TLC, p. ej. yellow_tripdata_2026-01.parquet."""
    return f"{tipo}_tripdata_{anio}-{mes:02d}.parquet"


def construir_url(tipo: str, anio: int, mes: int) -> str:
    """URL completa del archivo Parquet mensual."""
    return f"{URL_BASE}/{construir_nombre(tipo, anio, mes)}"


def ruta_destino(tipo: str, anio: int, mes: int) -> Path:
    """Ruta local donde se guarda el archivo."""
    return DIR_DESTINO / tipo / str(anio) / construir_nombre(tipo, anio, mes)


def tamanio_publicado(url: str) -> int | None:
    """Tamanio en bytes del archivo en el servidor, o None si no esta publicado.

    Lanza requests.RequestException ante errores de red o respuestas
    inesperadas, para distinguirlos de un mes que aun no existe.
    """
    respuesta = requests.head(url, timeout=TIEMPO_ESPERA, allow_redirects=True)
    if respuesta.status_code in CODIGOS_NO_PUBLICADO:
        return None
    respuesta.raise_for_status()
    return int(respuesta.headers.get("Content-Length", 0))


def es_parquet_valido(ruta: Path, tamanio_esperado: int | None = None) -> bool:
    """Revisa la firma PAR1 al inicio y al final y, si se conoce, el tamanio."""
    if not ruta.exists():
        return False
    tamanio = ruta.stat().st_size
    if tamanio < 2 * len(FIRMA_PARQUET):
        return False
    if tamanio_esperado and tamanio != tamanio_esperado:
        return False
    with ruta.open("rb") as archivo:
        inicio = archivo.read(len(FIRMA_PARQUET))
        archivo.seek(-len(FIRMA_PARQUET), 2)
        fin = archivo.read(len(FIRMA_PARQUET))
    return inicio == FIRMA_PARQUET and fin == FIRMA_PARQUET


def formato_tamanio(n: float) -> str:
    for unidad in ("B", "KiB", "MiB", "GiB"):
        if n < 1024 or unidad == "GiB":
            return f"{n:.1f} {unidad}"
        n /= 1024
    return f"{n:.1f} GiB"


def descargar_archivo(url: str, destino: Path, tamanio_esperado: int) -> int:
    """Descarga `url` en `destino`. Devuelve la cantidad de bytes escritos."""
    destino.parent.mkdir(parents=True, exist_ok=True)
    temporal = destino.with_name(destino.name + SUFIJO_TEMPORAL)

    ultimo_error = None
    for intento in range(1, INTENTOS + 1):
        try:
            with requests.get(url, stream=True, timeout=TIEMPO_ESPERA) as respuesta:
                respuesta.raise_for_status()
                escritos = 0
                with temporal.open("wb") as archivo:
                    for bloque in respuesta.iter_content(chunk_size=BLOQUE):
                        if bloque:
                            archivo.write(bloque)
                            escritos += len(bloque)
            if escritos == 0:
                raise requests.RequestException("el servidor devolvio un archivo vacio")
            if not es_parquet_valido(temporal, tamanio_esperado):
                raise requests.RequestException(
                    f"archivo invalido ({escritos} de {tamanio_esperado} bytes o sin firma PAR1)"
                )
            temporal.replace(destino)
            return escritos
        except requests.RequestException as error:
            ultimo_error = error
            temporal.unlink(missing_ok=True)
            if intento < INTENTOS:
                print(f"      intento {intento}/{INTENTOS} fallido ({error}); reintentando")

    raise requests.RequestException(f"no se pudo descargar {url}: {ultimo_error}")


def resumen_vacio() -> dict:
    return {"descargados": 0, "omitidos": 0, "no_publicados": [], "fallidos": []}


def procesar(tipo: str, anio: int, verificar: bool) -> dict:
    """Descarga (o solo verifica) todos los meses publicados de un tipo y anio."""
    print(f"\n=== {tipo.upper()} {anio} ===")
    resumen = resumen_vacio()

    for mes in range(1, 13):
        etiqueta = f"{anio}-{mes:02d}"
        destino = ruta_destino(tipo, anio, mes)
        url = construir_url(tipo, anio, mes)

        # Sin red: un archivo local valido se omite sin consultar al servidor.
        if not verificar and es_parquet_valido(destino):
            print(f"  {etiqueta}  ya existe, se omite")
            resumen["omitidos"] += 1
            continue

        try:
            esperado = tamanio_publicado(url)
        except requests.RequestException as error:
            print(f"  {etiqueta}  ERROR al consultar el servidor: {error}")
            resumen["fallidos"].append(etiqueta)
            continue

        if esperado is None:
            print(f"  {etiqueta}  aun no publicado por la TLC")
            resumen["no_publicados"].append(etiqueta)
            continue

        if verificar:
            if es_parquet_valido(destino, esperado):
                print(f"  {etiqueta}  OK ({formato_tamanio(esperado)})")
                resumen["omitidos"] += 1
            else:
                estado = "corrupto o incompleto" if destino.exists() else "falta"
                print(f"  {etiqueta}  {estado.upper()}")
                resumen["fallidos"].append(etiqueta)
            continue

        if destino.exists():
            print(f"  {etiqueta}  existe pero es invalido, se descarga de nuevo")
        print(f"  {etiqueta}  descargando...")
        try:
            escritos = descargar_archivo(url, destino, esperado)
        except requests.RequestException as error:
            print(f"  {etiqueta}  ERROR: {error}")
            resumen["fallidos"].append(etiqueta)
        else:
            print(f"  {etiqueta}  listo ({formato_tamanio(escritos)}) -> {destino}")
            resumen["descargados"] += 1

    return resumen


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Descarga los datos de taxis amarillos y verdes del NYC TLC."
    )
    parser.add_argument(
        "--taxi", choices=(*TIPOS_TAXI, "all"), default="all",
        help="tipo de taxi a descargar (por defecto: all)",
    )
    parser.add_argument(
        "--anios", type=int, nargs="+", default=list(ANIOS_POR_DEFECTO),
        help=f"anios a descargar (por defecto: {' '.join(map(str, ANIOS_POR_DEFECTO))})",
    )
    parser.add_argument(
        "--verificar", action="store_true",
        help="no descarga; compara los archivos locales con los publicados por la TLC",
    )
    argumentos = parser.parse_args()

    tipos = TIPOS_TAXI if argumentos.taxi == "all" else (argumentos.taxi,)

    total = resumen_vacio()
    for anio in argumentos.anios:
        for tipo in tipos:
            resumen = procesar(tipo, anio, argumentos.verificar)
            total["descargados"] += resumen["descargados"]
            total["omitidos"] += resumen["omitidos"]
            total["no_publicados"] += [f"{tipo} {m}" for m in resumen["no_publicados"]]
            total["fallidos"] += [f"{tipo} {m}" for m in resumen["fallidos"]]

    print("\n" + "=" * 60)
    print("RESUMEN DE VERIFICACION" if argumentos.verificar else "RESUMEN")
    print("=" * 60)
    if argumentos.verificar:
        print(f"  completos     : {total['omitidos']}")
    else:
        print(f"  descargados   : {total['descargados']}")
        print(f"  ya existian   : {total['omitidos']}")
    print(f"  no publicados : {len(total['no_publicados'])}")
    if total["no_publicados"]:
        print(f"      {', '.join(total['no_publicados'])}")
    print(f"  {'faltantes' if argumentos.verificar else 'fallidos':<14}: {len(total['fallidos'])}")
    if total["fallidos"]:
        print(f"      {', '.join(total['fallidos'])}")
    print("=" * 60)

    return 1 if total["fallidos"] else 0


if __name__ == "__main__":
    sys.exit(main())
