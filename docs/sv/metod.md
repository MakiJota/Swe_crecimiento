---
title: "Metod"
nav_order: 12
permalink: /sv/metod/
parent: Svenska
---

[In English]({{ '/method/' | relative_url }})

# Metod

1. TOC
{:toc}

## Data

- **GISD30** (Zhang m.fl. 2022, *Earth System Science Data* 14:1831-1856, CC BY 4.0): global hårdgjord yta i 30 m upplösning från Landsat. Varje pixel anger perioden då den först upptäcktes: 0 aldrig, 1 före 1985, 2-8 femårsperioder 1985-2020. Serien är kumulativ: en pixel slutar aldrig vara bebyggd.
- **Decennier** (`01_gisd30_decadas.R`): bebyggt till 1990 = värde 1-2, till 2000 = 1-4, till 2010 = 1-6, till 2020 = 1-8.
- **Stadsgränser** (`07_limites_aglomerados.R`): SCB:s statistiska tätorter 2020 (öppna geodata). En tätort är en sammanhängande bebyggelse med minst 200 invånare där husen ligger högst 200 m från varandra.
- **Rutor** (`cajas.md`): tätortens omskrivande rektangel plus 10 km åt varje håll, så att grannskapet på 1 km² aldrig tar slut vid stadens kant.
- Varje ruta projiceras om till sin UTM-zon i 30 m (närmaste granne) så att avstånd blir metriska.

## Klasser

Varje pixel på 30 m tittar på cirkeln på 1 km² runt sig (radie 564 m) och den andel av cirkeln som är bebyggd. Landsbygdsgräns som används här: **0,25** (Atlas 2016).

| Värde | Klass | Regel | I den urbana utbredningen? |
|---|---|---|---|
| 0 | öppen landsbygd | obebyggd, inget av nedanstående | nej |
| 1 | urban bebyggelse | bebyggd, cirkeln > 50 % bebyggd | ja |
| 2 | förortsbebyggelse | bebyggd, cirkeln 25-50 % bebyggd | ja |
| 3 | landsbygdsbebyggelse | bebyggd, cirkeln < 25 % bebyggd | nej |
| 4 | öppen randzon | obebyggd, inom 100 m från urban eller förortsbebyggelse | ja |
| 5 | innesluten öppen mark | öppen fläck (4-grannskap) under 200 ha, helt omsluten, rör inte rutans kant | ja |

**Urban utbredning** = urban + förort + randzon + innesluten.

### Hur randzonen ritas

En cirkel på 100 m centreras på varje urban och förortspixel; varje obebyggd pixel inom någon av cirklarna är randzon. På rutnätet når cirkeln 3 pixlar rakt ut (90 m) och 85-95 m diagonalt. Landsbygdsbebyggelse ger ingen randzon. Innesluten öppen mark tilldelas efter randzonen, så de överlappar aldrig.

Eftersom varje bebyggd kant får sin egen ring växer randzonen med *längden på stadens kant*, inte med dess yta: splittrade städer har mest randzon, och en stad som bygger på sin gamla randzon förlorar randzon när den växer.

## "Staden"

Inom varje ruta är staden de fläckar av urban utbredning (8-grannskap) som rör tätortsgränsen. En ort i rutan som aldrig rör gränsen räknas inte; en grannort vars utbredning växer ihop med staden (via randzonen räcker) räknas med.

När en fläck rör två städers tätorter går varje pixel till den närmaste gränsen. Det gäller här: Stockholm, Malmö, Helsingborg, Lund, Södertälje, Borlänge, Falun, Åkersberga, Landskrona.

## Mått

| Mått | Definition |
|---|---|
| bebyggd mark | bebyggda pixlar inom stadens urbana utbredning |
| mättnad | bebyggd mark / urban utbredning |
| öppenhet | genomsnittlig obebyggd andel av cirkeln på 1 km² runt stadens urbana och förortspixlar |
| randzonsandel | öppen randzon / urban utbredning |
| tillväxt | årlig genomsnittlig takt, (x1 / x0)^(1 / år) - 1 |
| fotavtryck 2007 | definitionen från Angel, Parent & Civco 2007 (landsbygdsgräns 0,10): bebyggt med ≥ 10 % av cirkeln bebyggd, plus obebyggda pixlar med > 50 % bebyggt runt sig eller inom 100 m från den bebyggelsen; fläckar som rör gränsen |

## Regler för att beskriva städerna

- **Takt** (tillväxt i bebyggd mark 1990-2020 per år): mycket snabb ≥ 4 %, snabb ≥ 2,5 %, måttlig ≥ 1,5 %, långsam < 1,5 %.
- **Form** (förändring i mättnad 1990-2020): förtätas ≥ +0,03, sprids ut ≤ -0,03, stabil däremellan.
- **Kontroll**: tillväxt i bebyggd mark ≥ 4 % per år flaggas för granskning mot GHSL eller bilder.

## Förbehåll

- **GISD30 är den enda indatan.** Upptäckten 1985-2000 är seriens svagaste (få Landsat 5-scener), så en del av accelerationen efter 2000 kan komma från datan. På svenska breddgrader minskar snötäcke, låg solhöjd och moln antalet användbara scener, och gles småhusbebyggelse bland träd kan underskattas i 30 m.
- **Vatten räknas som öppen mark.** GISD30 har ingen vattenmask, så stränder och kuster intill staden blir randzon eller innesluten öppen mark. Det väger tungt i Sverige (Mälaren, skärgården, Göta älv). Atlas tar bort vatten från den öppna marken; det gör inte den här kedjan ännu.
- **Tätortsgränsen är från 2020.** Den avgör vilka fläckar som är "staden" alla fyra åren; den används inte för att klippa pixlar.
- **Närhet redovisas inte**: mätt mot tyngdpunkten säger den lite om stadens form.
- **Landsbygdsgräns**: Atlas 2016 sätter förort till 25-50 %; definitionen från 2007 använder 10 %, så dess fotavtryck är större än utbredningen som mäts här.
- **Ingen täthet ännu**: det kräver befolkning per ruta (SCB:s befolkningsrutnät är ett naturligt nästa steg).

## Kedjan

| Steg | Skript | Vad det gör |
|---|---|---|
| 00 | `00_gisd30_descarga.R` | GISD30-rutor för Sverige (Zenodo, md5 kontrollerad) |
| 01 | `01_gisd30_decadas.R` | åtta femårsperioder till fyra kumulativa decennier |
| 07 | `07_limites_aglomerados.R` | SCB:s tätorter 2020 för de valda städerna, och deras rutor |
| 04b | `04b_angel_sin_landsat.R` | Angels klasser och mått per decennium |
| 06 | `06_reporte.R` | samma resultat som en markdown-rapport per språk |
| 08 | `08_sitio.R` | den här webbplatsen |

## Referenser

- Angel, S. et al. (2016). *Atlas of Urban Expansion, 2016 Edition. Volume 1: Areas and Densities.* NYU, UN-Habitat, Lincoln Institute of Land Policy.
- Angel, S., Parent, J. & Civco, D. (2007). Urban sprawl metrics: an analysis of global urban expansion using GIS. ASPRS Annual Conference.
- Statistiska centralbyrån (SCB). Statistiska tätorter 2020, öppna geodata.
- Zhang, X. et al. (2022). GISD30: global 30 m impervious-surface dynamic dataset from 1985 to 2020 using time-series Landsat imagery on the Google Earth Engine platform. *Earth System Science Data* 14, 1831-1856.
