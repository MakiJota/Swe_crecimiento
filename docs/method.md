---
title: "Method"
nav_order: 2
permalink: /method/
---

[På svenska]({{ '/sv/metod/' | relative_url }})

# Method

1. TOC
{:toc}

## Data

- **GISD30** (Zhang et al. 2022, *Earth System Science Data* 14:1831-1856, CC BY 4.0): global impervious surface at 30 m from Landsat. Each pixel stores the period of its first detection: 0 never, 1 before 1985, 2-8 five-year periods 1985-2020. The record is cumulative: a pixel never stops being built.
- **Decades** (`01_gisd30_decadas.R`): built-up by 1990 = values 1-2, by 2000 = 1-4, by 2010 = 1-6, by 2020 = 1-8.
- **City boundaries** (`07_limites_aglomerados.R`): Statistics Sweden (SCB) statistical *tätorter* 2020 (open geodata). A tätort is a continuous built-up area of at least 200 inhabitants with houses no more than 200 m apart.
- **Boxes** (`cajas.md`): the tätort's bounding box plus 10 km on every side, so the 1 km² neighbourhood never runs out of data at the edge of the city.
- Each box is reprojected to its UTM zone at 30 m (nearest neighbour) so that distances are metric.

## Classes

Each 30 m pixel looks at the circle of 1 km² around it (radius 564 m) and the share of that circle that is built-up. Rural cut used here: **0.25** (Atlas 2016 edition).

| Value | Class | Rule | In the urban extent? |
|---|---|---|---|
| 0 | rural open space | not built-up, none of the below | no |
| 1 | urban built-up | built-up, circle > 50 % built | yes |
| 2 | suburban built-up | built-up, circle 25-50 % built | yes |
| 3 | rural built-up | built-up, circle < 25 % built | no |
| 4 | fringe open space | not built-up, within 100 m of urban or suburban built-up | yes |
| 5 | captured open space | open patch (4-connected) under 200 ha, fully enclosed, not touching the box edge | yes |

**Urban extent** = urban + suburban + fringe + captured.

### How the fringe is drawn

A 100 m circle on the 30 m grid is centred on every urban and suburban pixel; every pixel that is not built-up and falls inside one of those circles is fringe. On the grid the circle reaches 3 pixels straight out (90 m) and 85-95 m on the diagonals. Rural built-up pixels do not make fringe. Captured open space is assigned after the fringe, so the two never overlap.

Because each built edge brings its own ring, the fringe grows with the *length of the city's edge*, not with its area: fragmented cities carry the most fringe, and a city that builds on its old fringe loses fringe as it grows.

## "The city"

Inside each box, the city is the set of urban-extent patches (8-connected) that touch the tätort boundary. A town inside the box that never touches the boundary is left out; a neighbouring town whose extent grows into the city's (the fringe is enough) counts with it.

When one patch touches the tätorter of two cities, each of its pixels goes to the nearer boundary. It applies here to: Stockholm, Malmö, Helsingborg, Lund, Södertälje, Borlänge, Falun, Åkersberga, Landskrona.

## Metrics

| Metric | Definition |
|---|---|
| built-up | built-up pixels inside the city's urban extent |
| saturation | built-up / urban extent |
| openness | average unbuilt share of the 1 km² circle around the city's urban and suburban pixels |
| fringe share | fringe open space / urban extent |
| growth | annual compound rate, (x1 / x0)^(1 / years) - 1 |
| 2007 footprint | the Angel, Parent & Civco 2007 definition (rural cut 0.10): built-up with ≥ 10 % of its circle built, plus unbuilt pixels with > 50 % built around them or within 100 m of that built-up; patches touching the boundary |

## Rules used to describe the cities

- **Pace** (built-up growth 1990-2020 per year): very fast ≥ 4 %, fast ≥ 2.5 %, moderate ≥ 1.5 %, slow < 1.5 %.
- **Shape** (saturation change 1990-2020): filling in ≥ +0.03, spreading out ≤ -0.03, stable in between.
- **Check**: built-up growth ≥ 4 % a year is flagged for review against GHSL or imagery.

## Caveats

- **GISD30 is the only input.** Its 1985-2000 detection is the weakest of the series (few Landsat 5 scenes), so part of the post-2000 acceleration may come from the data. At Swedish latitudes snow cover, low sun and clouds cut the number of usable scenes, and low-density housing among trees may be under-detected at 30 m.
- **Water counts as open space.** GISD30 has no water mask, so shores and coasts next to the city become fringe or captured open space. This weighs heavily in Sweden (Mälaren, the archipelagos, Göta älv). The Atlas removes water from open space; this pipeline does not yet.
- **The tätort boundary is from 2020.** It decides which patches are "the city" in all four years; it is not used to cut pixels.
- **Proximity is not reported**: measured to the centroid it says little about the city's shape.
- **Rural cut**: the Atlas 2016 edition puts suburban at 25-50 %; the 2007 definition uses 10 %, so its footprint is larger than the extent measured here.
- **No density yet**: it needs population per grid cell (the SCB population grid is the natural next step).

## Pipeline

| Step | Script | What it does |
|---|---|---|
| 00 | `00_gisd30_descarga.R` | GISD30 tiles for Sweden (Zenodo, md5 checked) |
| 01 | `01_gisd30_decadas.R` | eight five-year epochs to four cumulative decades |
| 07 | `07_limites_aglomerados.R` | SCB tätorter 2020 for the chosen cities, and their boxes |
| 04b | `04b_angel_sin_landsat.R` | Angel classes and metrics per decade |
| 06 | `06_reporte.R` | the same results as one markdown report per language |
| 08 | `08_sitio.R` | this site |

## References

- Angel, S. et al. (2016). *Atlas of Urban Expansion, 2016 Edition. Volume 1: Areas and Densities.* NYU, UN-Habitat, Lincoln Institute of Land Policy.
- Angel, S., Parent, J. & Civco, D. (2007). Urban sprawl metrics: an analysis of global urban expansion using GIS. ASPRS Annual Conference.
- Statistiska centralbyrån (SCB). Statistiska tätorter 2020, öppna geodata.
- Zhang, X. et al. (2022). GISD30: global 30 m impervious-surface dynamic dataset from 1985 to 2020 using time-series Landsat imagery on the Google Earth Engine platform. *Earth System Science Data* 14, 1831-1856.
