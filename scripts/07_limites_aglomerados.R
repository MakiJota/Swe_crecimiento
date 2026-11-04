# -*- coding: utf-8 -*-
# Paso 07 · Limites de las ciudades suecas y sus cajas, en un GeoPackage.
# Reemplaza al 07 de Argentina (que leia plataforma/ del repo de Bolsones).
#
# DE DONDE SALEN LOS LIMITES. SCB, Statistiska tatorter (oppna geodata), por WFS:
#   https://geodata.scb.se/geoserver/stat/wfs  capa stat:Tatorter_<anio>
# Un tatort es una aglomeracion continua de al menos 200 habitantes, con casas a menos
# de 200 m entre si (definicion SCB). Se usa el de 2020, el ultimo anio de GISD30.
# El contorno sirve para elegir "la ciudad" en 04b: las manchas de la extension urbana
# que tocan el tatort. Una mancha contigua (Sollentuna junto a Estocolmo) entra sola.
#
# QUE CIUDADES. Los TOP_N tatorter mas poblados de 2020 (campo bef), salvo los SUBURBIOS:
# un tatort a menos de SUBURBIO_KM de otro mas poblado es parte de esa ciudad, que SCB
# separa por un hueco de mas de 200 m. Con 1 km salen cinco (Upplands Vasby och
# Sollentuna, Nordostra Goteborg, Tumba, Lidingo, Vallentuna en el top 40, todos a menos
# de 0,7 km);
# el siguiente mas cercano esta a 3,6 km, asi que el corte no es fino. La distancia se mide
# sobre los poligonos simplificados a 50 m. El slug es el nombre en minusculas sin tildes.
#
# Salida:
#   raw/boundaries/tatorter_2020_scb.gpkg   la capa de SCB tal como viene (SWEREF99 TM)
#   raw/boundaries/aglomerados.gpkg         dos capas, EPSG:4326:
#     perimetro  una fila por ciudad (slug, nombre, provincia = lan, kommun, bef, n_partes, km2)
#     cajas      las cajas de cajas.md (slug, contorno, origen)
#   cajas.md                                la tabla que leen 04b y 05 (perimetro + 10 km)
#
# Uso: Rscript Sweden/scripts/07_limites_aglomerados.R

Sys.setenv(PROJ_LIB = system.file("proj", package = "terra"),
           PROJ_DATA = system.file("proj", package = "terra"),
           GDAL_DATA = system.file("gdal", package = "terra"))
suppressPackageStartupMessages(library(sf))

script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
SCRIPTS <- normalizePath(dirname(script), winslash = "/")
RPIPE <- dirname(SCRIPTS)
source(file.path(SCRIPTS, "lib", "cajas.R"))
SAL <- file.path(RPIPE, "raw", "boundaries")
ANIO <- 2020
SCB <- file.path(SAL, sprintf("tatorter_%d_scb.gpkg", ANIO))
GPKG <- file.path(SAL, "aglomerados.gpkg")
WFS <- paste0("https://geodata.scb.se/geoserver/stat/wfs?service=WFS&REQUEST=GetFeature",
              "&version=1.1.0&TYPENAMES=stat:Tatorter_%d&outputFormat=geopackage")
MARGEN_KM <- 10
TOP_N <- 35
SUBURBIO_KM <- 1
dir.create(SAL, recursive = TRUE, showWarnings = FALSE)


if (!file.exists(SCB)) {
  cat("Bajando", sprintf("stat:Tatorter_%d", ANIO), "de SCB ...\n")
  download.file(sprintf(WFS, ANIO), SCB, mode = "wb", quiet = TRUE)
}
tat <- st_read(SCB, quiet = TRUE)
tat <- tat[order(-tat$bef), ]
# candidatos: los que hagan falta para llegar a TOP_N despues de sacar suburbios
cand <- tat[seq_len(2 * TOP_N), ]
d <- units::drop_units(st_distance(st_simplify(cand, dTolerance = 50))) / 1000
suburbio <- vapply(seq_len(nrow(cand)), function(i) i > 1 && min(d[i, seq_len(i - 1)]) < SUBURBIO_KM, TRUE)
cat(sprintf("Suburbios (a menos de %g km de un tatort mas poblado): %s
", SUBURBIO_KM,
            paste(cand$tatort[suburbio], collapse = ", ")))
tat <- head(cand[!suburbio, ], TOP_N)
CIUDADES <- data.frame(slug = gsub("[^a-z]+", "_", tolower(chartr("åäöéÅÄÖÉ", "aaoeAAOE", tat$tatort))),
                       tatortskod = tat$tatortskod)
if (anyDuplicated(CIUDADES$slug)) stop("slug repetido: ", paste(CIUDADES$slug[duplicated(CIUDADES$slug)], collapse = ", "))

per <- st_sf(slug = CIUDADES$slug, nombre = tat$tatort, provincia = tat$lannamn,
             kommun = tat$kommunnamn, tatortskod = tat$tatortskod, bef = tat$bef,
             geometry = st_make_valid(st_geometry(tat)))
per$n_partes <- vapply(st_geometry(per), function(g) length(st_cast(st_sfc(g), "POLYGON")), 1L)
per$km2 <- round(as.numeric(st_area(per)) / 1e6, 1)

# caja: recuadro del perimetro mas MARGEN_KM de cada lado, medido en SWEREF99 TM (metros)
cajas_m <- lapply(st_geometry(per), function(g) st_bbox(g) + c(-1, -1, 1, 1) * MARGEN_KM * 1e3)
cajas <- st_sf(slug = per$slug, contorno = per$slug, origen = sprintf("perimetro + %d km", MARGEN_KM),
               geometry = st_set_crs(do.call(c, lapply(cajas_m, st_as_sfc)), st_crs(tat)))
per <- st_transform(per, 4326)
cajas <- st_transform(cajas, 4326)
bb <- t(vapply(st_geometry(cajas), function(g) as.vector(st_bbox(g)), numeric(4)))

filas <- sprintf("| %s | %s | %.4f | %.4f | %.4f | %.4f | %s | %d |", cajas$slug, cajas$contorno,
                 bb[, 2], bb[, 1], bb[, 4], bb[, 3], cajas$origen, per$n_partes)
writeLines(enc2utf8(c(
  "# Cajas de las ciudades", "",
  "Generado por `scripts/07_limites_aglomerados.R`: no editar a mano. Para agregar una ciudad,",
  "agregar su fila a la tabla CIUDADES de 07 y volver a correrlo.", "",
  sprintf("- **contorno**: el tatort de SCB %d, en la capa `perimetro` de `raw/boundaries/aglomerados.gpkg`.", ANIO),
  sprintf("- **caja**: `lat0,lon0,lat1,lon1`, recuadro del tatort mas %d km de cada lado (en SWEREF99 TM),", MARGEN_KM),
  "  pasado a grados WGS84 y agrandado hasta cubrirlo.", "",
  "| slug | contorno | lat0 | lon0 | lat1 | lon1 | origen | partes |",
  "|---|---|---|---|---|---|---|---|", filas)), file.path(RPIPE, "cajas.md"), useBytes = TRUE)

if (file.exists(GPKG)) unlink(GPKG)
st_write(per, GPKG, layer = "perimetro", quiet = TRUE)
st_write(cajas, GPKG, layer = "cajas", quiet = TRUE, append = TRUE)

# control: la caja en grados (la que leen 04b y 05) tiene que cubrir el perimetro entero
cj <- leer_cajas(RPIPE)
cubre <- vapply(seq_len(nrow(cj)), function(i) {
  b <- st_as_sfc(st_bbox(c(xmin = cj$lon0[i], ymin = cj$lat0[i], xmax = cj$lon1[i], ymax = cj$lat1[i]),
                         crs = 4326))
  isTRUE(st_covers(b, per[per$slug == cj$contorno[i], ], sparse = FALSE)[1, 1])
}, TRUE)

cat(sprintf("Escrito %s\n  perimetro  %d ciudades (%d de mas de una parte)\n  cajas      %d, y cajas.md\n",
            GPKG, nrow(per), sum(per$n_partes > 1), nrow(cajas)))
print(st_drop_geometry(per)[, c("slug", "nombre", "provincia", "bef", "km2", "n_partes")], row.names = FALSE)
if (all(cubre)) cat("  ok   cada caja cubre su perimetro entero\n") else
  cat("  AVISO  cajas que cortan su perimetro:", paste(cj$slug[!cubre], collapse = ", "), "\n")
