# Urban growth in Sweden's cities (R)

How Sweden's 35 largest cities grew between 1990 and 2020, measured with the classes of the
**Atlas of Urban Expansion** (Angel et al. 2016) on the **GISD30** impervious-surface record
(Zhang et al. 2022, Landsat, 30 m). The cities are SCB statistical *tätorter* (2020): the 35
most populous, leaving out the five that lie less than 1 km from a larger one (suburbs that
SCB separates by a gap, such as Upplands Väsby och Sollentuna next to Stockholm).
Same method as the Argentine study (`Arg_crecimiento`), with Swedish boundaries.

**Site:** <https://makijota.github.io/Swe_crecimiento/> (English) ·
<https://makijota.github.io/Swe_crecimiento/sv/> (svenska).

**Report:** [`reporte/REPORT_en.md`](reporte/REPORT_en.md) ·
[`reporte/REPORT_sv.md`](reporte/REPORT_sv.md) (på svenska).

Exploratory. Every number in the report and the site is generated from the pipeline outputs;
none is typed by hand.

## Pipeline

R scripts, in run order. Paths are relative to this folder, resolved from each script's own
location.

| Step | Script | What it does |
|---|---|---|
| 00 | `scripts/00_gisd30_descarga.R` | GISD30 tiles for Sweden from Zenodo (one package, E0_E30, md5 checked) |
| 01 | `scripts/01_gisd30_decadas.R` | eight five-year epochs to four cumulative decades (1990, 2000, 2010, 2020) |
| 07 | `scripts/07_limites_aglomerados.R` | SCB tätorter 2020 (WFS) for the chosen cities to `raw/boundaries/aglomerados.gpkg`, and their boxes to `cajas.md` |
| 04b | `scripts/04b_angel_sin_landsat.R` | Angel / Atlas classes and metrics per decade, GISD30 cut with each box |
| 06 | `scripts/06_reporte.R` | the report in `reporte/`, in English and Swedish |
| 08 | `scripts/08_sitio.R` | the GitHub Pages site in `docs/`, English at the root and Swedish under `/sv/` |

`scripts/lib/`: `cajas.R` (boxes and boundaries) and `resultados.R` (the numbers, rules,
charts, maps and text of report and site; every string through `tr(en, sv)`).

The city list is computed in step 07 (`TOP_N`, `SUBURBIO_KM`). After changing it, rerun 07,
04b, 06 and 08.

Everything under `outputs/` and `raw/` (except the small `aglomerados.gpkg`) is downloaded or
derived and is not versioned.

## Running it

R 4.5 with `terra`, `sf`, `ggplot2`, `curl`, `archive`, `digest` and `jsonlite`. From this
folder:

    Rscript scripts/00_gisd30_descarga.R --sin-gpkg
    Rscript scripts/01_gisd30_decadas.R
    Rscript scripts/07_limites_aglomerados.R
    Rscript scripts/04b_angel_sin_landsat.R          # all cities in cajas.md; --ciudades a,b for some
    Rscript scripts/06_reporte.R
    Rscript scripts/08_sitio.R

## Data and licences

- GISD30: Zhang, X. et al. (2022), *Earth System Science Data* 14, 1831-1856. CC BY 4.0.
- Statistiska tätorter 2020: Statistics Sweden (SCB), open geodata.
- Classes: Angel, S. et al. (2016), *Atlas of Urban Expansion, 2016 Edition*, Vol. 1.
