# -*- coding: utf-8 -*-
# Funciones de las salidas de resultados (el reporte, 06_reporte.R, y el sitio, 08_sitio.R):
# leen los resultados de Angel, calculan lo que se publica, dibujan graficos y mapas y arman
# el texto compartido. Se carga con source(); no se corre sola.
# Adaptado de Rpipe/scripts/lib/resultados.R (Argentina).
#
# IDIOMA. Todo texto publicado pasa por tr(en, sv). LANG ("en" o "sv") lo fija quien llama
# antes de source(); por defecto "en". Los numeros siguen la convencion de cada idioma
# (sv: coma decimal y espacio de miles).
#
# Lee:
#   outputs/angel/resumen.csv             metricas por ciudad y anio (paso 04b)
#   outputs/angel/<slug>/angel_<anio>.tif clases 0-5 (paso 04b), para los mapas
#   raw/boundaries/aglomerados.gpkg       perimetro (tatort SCB 2020), nombre y lan (paso 07)
#   cajas.md                              que ciudad va con que tatort
#
# NINGUNA CIFRA SE ESCRIBE A MANO. Todo numero sale de resumen.csv en la corrida, y las
# frases que clasifican ciudades salen de estas reglas (las mismas que Argentina):
#   ritmo   crecimiento anual del construido 1990-2020: >= 4 muy rapido, >= 2,5
#           rapido, >= 1,5 moderado, < 1,5 lento
#   forma   cambio de la saturacion 1990-2020: >= +0,03 se llena, <= -0,03 se
#           dispersa, en el medio estable
#   alerta  construido >= 4 % anual: revisar contra GHSL o imagenes
# Exploratorio.

Sys.setenv(PROJ_LIB = system.file("proj", package = "terra"),
           PROJ_DATA = system.file("proj", package = "terra"),
           GDAL_DATA = system.file("gdal", package = "terra"))
suppressPackageStartupMessages({
  library(ggplot2)
  library(terra)
  library(sf)
})
# requiere lib/cajas.R cargado antes (leer_cajas)

if (!exists("LANG")) LANG <- "en"
stopifnot(LANG %in% c("en", "sv"))
tr <- function(en, sv) if (LANG == "sv") sv else en

ANIOS <- c(1990, 2000, 2010, 2020)

# paleta categorica validada (validate_palette.js, modo claro); la misma en graficos y mapas
COL <- c(urbano = "#2a78d6", suburbano = "#eda100", capturado = "#1baf7a", franja = "#eb6834")
ETQ <- tr(c(urbano = "urban built-up", suburbano = "suburban built-up",
            capturado = "captured open space", franja = "fringe open space"),
          c(urbano = "urban bebyggelse", suburbano = "förortsbebyggelse",
            capturado = "innesluten öppen mark", franja = "öppen randzon"))
ETQ_RURAL <- tr(c("rural built-up", "rural open space"), c("landsbygdsbebyggelse", "öppen landsbygd"))
MEDIDAS <- c(construido = "#2a78d6", sin_franja = "#1baf7a", con_franja = "#eb6834")
ETQ_MED <- tr(c(construido = "built-up", sin_franja = "extent without fringe",
                con_franja = "extent with fringe"),
              c(construido = "bebyggd mark", sin_franja = "utbredning utan randzon",
                con_franja = "utbredning med randzon"))
RITMOS <- tr(c("slow", "moderate", "fast", "very fast"), c("långsam", "måttlig", "snabb", "mycket snabb"))
FORMAS <- tr(c("filling in", "stable", "spreading out"), c("förtätas", "stabil", "sprids ut"))
# valor del raster de 04b -> color: 0 abierto rural, 1 urbano, 2 suburbano,
# 3 rural construido, 4 franja, 5 capturado
PAL_MAPA <- c("#f3f2ee", COL[["urbano"]], COL[["suburbano"]], "#8a8986", COL[["franja"]],
              COL[["capturado"]])
FONDO <- "#fcfcfb"
TINTA <- "#0b0b0b"
TINTA2 <- "#52514e"
REJILLA <- "#e6e5df"
PIE <- tr("Source: GISD30 (Zhang et al. 2022), SCB tätorter 2020. Angel / Atlas of Urban Expansion 2016 classes. Exploratory.",
          "Källa: GISD30 (Zhang m.fl. 2022), SCB tätorter 2020. Klasser enligt Angel / Atlas of Urban Expansion 2016. Explorativt.")

tema <- theme_minimal(base_size = 11) +
  theme(plot.background = element_rect(fill = FONDO, colour = NA),
        panel.background = element_rect(fill = FONDO, colour = NA),
        panel.grid.major.x = element_blank(), panel.grid.minor = element_blank(),
        panel.grid.major.y = element_line(colour = REJILLA, linewidth = 0.3),
        text = element_text(colour = TINTA), axis.text = element_text(colour = TINTA2),
        strip.text = element_text(face = "bold", hjust = 0),
        plot.title = element_text(face = "bold"), plot.subtitle = element_text(colour = TINTA2),
        plot.caption = element_text(colour = TINTA2, hjust = 0),
        legend.position = "top", legend.justification = "left")
tema_h <- tema + theme(panel.grid.major.x = element_line(colour = REJILLA, linewidth = 0.3),
                       panel.grid.major.y = element_blank())


# ---- formato -----------------------------------------------------------------------

fn <- function(x, d) formatC(x, format = "f", digits = d, big.mark = tr(",", " "),
                             decimal.mark = tr(".", ","))
f0 <- function(x) fn(x, 0)
f1 <- function(x) fn(x, 1)
f2 <- function(x) fn(x, 2)
fs <- function(x) ifelse(x >= 0, paste0("+", f2(x)), f2(x))   # con signo
tabla <- function(cab, filas) c(paste0("| ", paste(cab, collapse = " | "), " |"),
                                paste0("|", paste(rep("---", length(cab)), collapse = "|"), "|"),
                                vapply(filas, function(f) paste0("| ", paste(f, collapse = " | "), " |"), ""))
lista <- function(x) if (!length(x)) tr("none", "inga") else paste(x, collapse = ", ")
tasa <- function(x0, x1, anios) 100 * ((x1 / x0)^(1 / anios) - 1)
leyenda_png <- function(archivo) {
  # leyenda de los mapas como imagen: GitHub no deja pasar estilos en el markdown
  et <- c(ETQ[["urbano"]], ETQ[["suburbano"]], ETQ[["franja"]], ETQ[["capturado"]], ETQ_RURAL,
          tr("tätort boundary (SCB 2020)", "tätortsgräns (SCB 2020)"))
  co <- PAL_MAPA[c(2, 3, 5, 6, 4, 1)]
  png(archivo, width = 1000, height = 70, bg = FONDO)
  par(mar = c(0, 0, 0, 0))
  plot.new()
  plot.window(c(0, 1000), c(0, 70))
  x <- c(10, 170, 345, 520, 705, 850)
  for (i in 1:6) {
    rect(x[i], 42, x[i] + 22, 62, col = co[i], border = "#c9c8c2")
    text(x[i] + 30, 52, et[i], adj = 0, cex = 1.1, col = TINTA)
  }
  segments(10, 18, 32, 18, col = "#1d1d1b", lwd = 2)
  text(40, 18, et[7], adj = 0, cex = 1.1, col = TINTA)
  dev.off()
}


# ---- datos -------------------------------------------------------------------------

cargar_resultados <- function(rpipe) {
  angel <- file.path(rpipe, "outputs", "angel")
  cj <- leer_cajas(rpipe)
  cj <- cj[nzchar(cj$contorno), ]
  per <- st_read(file.path(rpipe, "raw", "boundaries", "aglomerados.gpkg"), layer = "perimetro", quiet = TRUE)
  info <- merge(cj[, c("slug", "contorno")], st_drop_geometry(per), by.x = "contorno", by.y = "slug")

  d <- read.csv(file.path(angel, "resumen.csv"))
  d <- d[d$ciudad %in% info$slug & d$anio %in% ANIOS, ]
  completas <- names(which(table(d$ciudad) == length(ANIOS)))
  faltan <- setdiff(info$slug, completas)
  if (length(faltan)) cat("AVISO  sin las cuatro epocas, quedan afuera:", paste(faltan, collapse = ", "), "\n")
  d <- d[d$ciudad %in% completas, ]
  info <- info[info$slug %in% completas, ]
  # orden de poblacion del tatort 2020, de mayor a menor
  info <- info[order(-info$bef), ]
  if (length(unique(d$u_rural)) != 1) stop("resumen.csv mezcla umbrales rurales", call. = FALSE)

  d$sin_franja <- d$urbano_ciudad_km2 + d$suburbano_ciudad_km2 + d$capturado_ciudad_km2
  d$pct_franja <- 100 * d$franja_ciudad_km2 / d$extension_ciudad_km2
  d$nombre <- info$nombre[match(d$ciudad, info$slug)]
  d <- d[order(d$ciudad, d$anio), ]
  val <- function(slug, anio, col) d[[col]][d$ciudad == slug & d$anio == anio]

  # una fila por ciudad con todo lo que se publica
  fichas <- do.call(rbind, lapply(info$slug, function(s) {
    data.frame(slug = s,
               nombre = info$nombre[info$slug == s],
               provincia = info$provincia[info$slug == s],
               bef = info$bef[info$slug == s],
               partes = info$n_partes[info$slug == s],
               construido_1990 = val(s, 1990, "construido_ciudad_km2"),
               construido_2020 = val(s, 2020, "construido_ciudad_km2"),
               extension_1990 = val(s, 1990, "extension_ciudad_km2"),
               extension_2020 = val(s, 2020, "extension_ciudad_km2"),
               t_construido = tasa(val(s, 1990, "construido_ciudad_km2"), val(s, 2020, "construido_ciudad_km2"), 30),
               t_sin = tasa(val(s, 1990, "sin_franja"), val(s, 2020, "sin_franja"), 30),
               t_con = tasa(val(s, 1990, "extension_ciudad_km2"), val(s, 2020, "extension_ciudad_km2"), 30),
               franja_1990 = val(s, 1990, "pct_franja"), franja_2020 = val(s, 2020, "pct_franja"),
               suma_franja_2020 = 100 * val(s, 2020, "franja_ciudad_km2") / val(s, 2020, "sin_franja"),
               sat_1990 = val(s, 1990, "saturacion"), sat_2020 = val(s, 2020, "saturacion"),
               ape_1990 = val(s, 1990, "apertura"), ape_2020 = val(s, 2020, "apertura"))
  }))
  fichas$dif <- fichas$t_con - fichas$t_sin
  fichas$ritmo <- cut(fichas$t_construido, c(-Inf, 1.5, 2.5, 4, Inf), right = FALSE, labels = RITMOS)
  dsat <- fichas$sat_2020 - fichas$sat_1990
  fichas$forma <- ifelse(dsat >= 0.03, FORMAS[1], ifelse(dsat <= -0.03, FORMAS[3], FORMAS[2]))
  fichas$alerta <- fichas$t_construido >= 4

  # agregados: todas, y sin la mayor (Estocolmo, por poblacion del tatort)
  n <- nrow(info)
  mayor <- info$slug[1]
  nm_mayor <- info$nombre[1]
  t_todos <- sprintf(tr("All %d cities", "Alla %d städer"), n)
  t_sin <- sprintf(tr("%d cities, without %s", "%d städer, utan %s"), n - 1, nm_mayor)
  suma <- function(x, grupo) {
    cols <- c(paste0(names(COL), "_ciudad_km2"), "extension_ciudad_km2", "construido_ciudad_km2", "sin_franja")
    a <- aggregate(x[cols], list(anio = x$anio), sum)
    a$pct_franja <- 100 * a$franja_ciudad_km2 / a$extension_ciudad_km2
    a$ciudad <- a$nombre <- a$grupo <- grupo
    a
  }
  ag <- rbind(suma(d, t_todos), suma(d[d$ciudad != mayor, ], t_sin))
  ag$grupo <- factor(ag$grupo, levels = c(t_todos, t_sin))

  # cajas que contienen el tatort de otra ciudad del estudio (manchas compartidas, ver 04b)
  caja_sf <- function(i) st_as_sfc(st_bbox(c(xmin = cj$lon0[i], ymin = cj$lat0[i], xmax = cj$lon1[i],
                                             ymax = cj$lat1[i]), crs = 4326))
  compartidas <- unlist(lapply(seq_len(nrow(cj)), function(i) {
    otros <- per[per$slug != cj$contorno[i], ]
    if (any(st_intersects(otros, caja_sf(i), sparse = FALSE))) cj$slug[i]
  }))

  list(d = d, info = info, fichas = fichas, per = per, ag = ag, angel = angel, n = n,
       t_todos = t_todos, t_sin = t_sin, nm_mayor = nm_mayor, compartidas = compartidas,
       u_rural = unique(d$u_rural))
}

decadas <- function(r, s) {
  x <- r$d[r$d$ciudad == s, ]
  do.call(rbind, lapply(1:3, function(i) data.frame(
    decada = sprintf("%d-%d", ANIOS[i], ANIOS[i + 1]), medida = names(MEDIDAS),
    tasa = c(tasa(x$construido_ciudad_km2[i], x$construido_ciudad_km2[i + 1], 10),
             tasa(x$sin_franja[i], x$sin_franja[i + 1], 10),
             tasa(x$extension_ciudad_km2[i], x$extension_ciudad_km2[i + 1], 10)))))
}


# ---- graficos ----------------------------------------------------------------------

largo <- function(x) {
  l <- do.call(rbind, lapply(names(COL), function(k)
    data.frame(ciudad = x$ciudad, nombre = x$nombre, anio = factor(x$anio), clase = k,
               km2 = x[[paste0(k, "_ciudad_km2")]])))
  l$clase <- factor(l$clase, levels = rev(names(COL)))
  l
}

barras <- function(x, titulo, facetas = FALSE) {
  g <- ggplot(largo(x), aes(anio, km2, fill = clase)) +
    geom_col(width = 0.7, colour = FONDO, linewidth = 0.4) +
    geom_text(data = x, aes(factor(anio), extension_ciudad_km2,
                            label = sprintf(tr("%s%% fringe", "%s %% randzon"), f0(pct_franja))),
              inherit.aes = FALSE, vjust = -0.5, size = 3, colour = TINTA2) +
    scale_fill_manual(values = COL, breaks = names(COL), labels = ETQ) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.14)), labels = function(v) f0(v)) +
    labs(x = NULL, y = "km²", fill = NULL, title = titulo,
         subtitle = tr("Urban extent by component. Label: share of the extent that is fringe open space",
                       "Urban utbredning per komponent. Etikett: andel av utbredningen som är öppen randzon"),
         caption = PIE) + tema +
    guides(fill = guide_legend(nrow = 2))
  if (facetas) g <- g + facet_wrap(~grupo, scales = "free_y")
  g
}

graf_decadas <- function(r, s, titulo) {
  x <- decadas(r, s)
  x$medida <- factor(x$medida, levels = names(MEDIDAS))
  ggplot(x, aes(decada, tasa, fill = medida)) +
    geom_hline(yintercept = 0, colour = TINTA2, linewidth = 0.3) +
    geom_col(position = position_dodge(width = 0.78), width = 0.72, colour = FONDO, linewidth = 0.4) +
    geom_text(aes(label = f1(tasa), vjust = ifelse(tasa >= 0, -0.4, 1.3)),
              position = position_dodge(width = 0.78), size = 2.8, colour = TINTA2) +
    scale_fill_manual(values = MEDIDAS, labels = ETQ_MED) +
    scale_y_continuous(expand = expansion(mult = c(0.08, 0.14)), labels = function(v) f1(v)) +
    labs(x = NULL, y = tr("% per year", "% per år"), fill = NULL, title = titulo,
         subtitle = tr("Annual compound growth in each decade", "Årlig genomsnittlig tillväxt per decennium"),
         caption = PIE) + tema
}

puntos <- function(x, titulo, eje, subtitulo = NULL) {
  ggplot(x, aes(v, nombre)) +
    geom_line(aes(group = nombre), colour = "#d6d5cf", linewidth = 0.6) +
    geom_point(aes(colour = anio), size = 2.4) +
    scale_colour_manual(values = c("1990" = "#86b6ef", "2020" = "#1c5cab")) +
    scale_x_continuous(labels = function(v) f2(v)) +
    labs(x = eje, y = NULL, colour = NULL, title = titulo, subtitle = subtitulo, caption = PIE) + tema_h
}

graficos <- function(r, dir) {
  # escribe en dir: sverige_*.png y agl/<slug>_{composicion,decadas}.png
  dir.create(file.path(dir, "agl"), recursive = TRUE, showWarnings = FALSE)
  guardar <- function(g, nombre, w, h) ggsave(file.path(dir, nombre), g, width = w, height = h, dpi = 120, bg = FONDO)
  fi <- r$fichas
  alto <- 0.3 * r$n + 2.5

  guardar(barras(r$ag, tr("Urban extent of Sweden's largest cities", "Urban utbredning i Sveriges största städer"),
                 facetas = TRUE), "sverige_composicion.png", 10, 5.2)

  cre <- rbind(data.frame(nombre = fi$nombre, medida = "construido", tasa = fi$t_construido),
               data.frame(nombre = fi$nombre, medida = "sin_franja", tasa = fi$t_sin),
               data.frame(nombre = fi$nombre, medida = "con_franja", tasa = fi$t_con))
  cre$nombre <- factor(cre$nombre, levels = fi$nombre[order(fi$t_construido)])
  cre$medida <- factor(cre$medida, levels = names(MEDIDAS))
  guardar(ggplot(cre, aes(tasa, nombre, colour = medida)) +
            geom_line(aes(group = nombre), colour = "#d6d5cf", linewidth = 0.6) +
            geom_point(size = 2.4) +
            scale_colour_manual(values = MEDIDAS, labels = ETQ_MED) +
            scale_x_continuous(labels = function(v) f1(v)) +
            labs(x = tr("annual growth 1990-2020 (%)", "årlig tillväxt 1990-2020 (%)"), y = NULL, colour = NULL,
                 title = tr("How fast each city grew, by what is counted", "Hur snabbt varje stad växte, beroende på vad som räknas"),
                 subtitle = tr("Annual compound growth of the surface, 1990 to 2020", "Årlig genomsnittlig tillväxt av ytan, 1990 till 2020"),
                 caption = PIE) + tema_h,
          "sverige_crecimiento.png", 8.5, alto)

  fr <- rbind(data.frame(nombre = fi$nombre, anio = "1990", v = fi$franja_1990),
              data.frame(nombre = fi$nombre, anio = "2020", v = fi$franja_2020))
  fr$nombre <- factor(fr$nombre, levels = fi$nombre[order(fi$franja_2020)])
  guardar(puntos(fr, tr("Weight of the fringe open space, 1990 and 2020", "Den öppna randzonens vikt, 1990 och 2020"),
                 tr("% of the urban extent that is fringe open space", "% av den urbana utbredningen som är öppen randzon")),
          "sverige_franja.png", 8, alto)

  df <- data.frame(nombre = factor(fi$nombre, levels = fi$nombre[order(fi$dif)]), v = fi$dif)
  guardar(ggplot(df, aes(v, nombre)) +
            geom_vline(xintercept = 0, colour = TINTA2, linewidth = 0.3) +
            geom_col(fill = "#6f6e69", width = 0.65) +
            scale_x_continuous(labels = function(v) f2(v)) +
            labs(x = tr("growth with fringe minus growth without fringe (percentage points per year)",
                        "tillväxt med randzon minus tillväxt utan randzon (procentenheter per år)"), y = NULL,
                 title = tr("How much counting the fringe changes the growth rate",
                            "Hur mycket randzonen ändrar tillväxttakten"),
                 subtitle = tr("Negative: the city fills its old fringe. Positive: new scattered patches add new fringe",
                               "Negativt: staden bygger på sin gamla randzon. Positivt: nya spridda fläckar ger ny randzon"),
                 caption = PIE) + tema_h,
          "sverige_efecto_franja.png", 8.5, alto)

  ns <- tr(c("saturation", "openness"), c("mättnad", "öppenhet"))
  ix <- rbind(data.frame(nombre = fi$nombre, anio = "1990", indice = ns[1], v = fi$sat_1990),
              data.frame(nombre = fi$nombre, anio = "2020", indice = ns[1], v = fi$sat_2020),
              data.frame(nombre = fi$nombre, anio = "1990", indice = ns[2], v = fi$ape_1990),
              data.frame(nombre = fi$nombre, anio = "2020", indice = ns[2], v = fi$ape_2020))
  ix$indice <- factor(ix$indice, levels = ns)
  ix$nombre <- factor(ix$nombre, levels = fi$nombre[order(fi$sat_2020)])
  guardar(puntos(ix, tr("Saturation and openness, 1990 and 2020", "Mättnad och öppenhet, 1990 och 2020"), NULL,
                 tr("Saturation: built-up / urban extent. Openness: unbuilt share of the 1 km² circle",
                    "Mättnad: bebyggd mark / urban utbredning. Öppenhet: obebyggd andel av cirkeln på 1 km²")) +
            facet_wrap(~indice, scales = "free_x"), "sverige_indices.png", 9.5, alto)

  for (s in r$info$slug) {
    nm <- r$info$nombre[r$info$slug == s]
    guardar(barras(r$d[r$d$ciudad == s, ], nm), sprintf("agl/%s_composicion.png", s), 7.5, 4.8)
    guardar(graf_decadas(r, s, nm), sprintf("agl/%s_decadas.png", s), 7.5, 4.4)
  }
  leyenda_png(file.path(dir, "leyenda.png"))
  cat("graficos listos en", dir, "\n")
}


# ---- mapas -------------------------------------------------------------------------

mapas <- function(r, dir) {
  # escribe en dir: <slug>_<anio>.png, el perimetro mas 5 km, mismo encuadre en las cuatro
  # epocas. Sin texto salvo nombre y anio: los comparten los dos idiomas.
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  for (s in r$info$slug) {
    cont <- vect(r$per[r$per$slug == r$info$contorno[r$info$slug == s], ])
    r0 <- rast(file.path(r$angel, s, "angel_2020.tif"))
    marco <- intersect(ext(project(cont, crs(r0))) + 5000, ext(r0))
    for (a in ANIOS) {
      x <- crop(rast(file.path(r$angel, s, sprintf("angel_%d.tif", a))), marco)
      coltab(x) <- data.frame(value = 0:5, col = PAL_MAPA)
      w <- 900
      h <- round(w * nrow(x) / ncol(x))
      if (h > 1100) { w <- round(w * 1100 / h); h <- 1100 }
      png(file.path(dir, sprintf("%s_%d.png", s, a)), width = w, height = h + 40, bg = FONDO)
      plot(x, legend = FALSE, axes = FALSE, mar = c(0, 0, 2, 0), maxcell = 4e6,
           main = sprintf("%s · %d", r$info$nombre[r$info$slug == s], a), cex.main = 1.3)
      lines(project(cont, crs(x)), col = "#1d1d1b", lwd = 1.3)
      dev.off()
    }
    cat("  mapas", s, "\n")
  }
}


# ---- texto compartido --------------------------------------------------------------
# img(ruta, alt) y enlace(slug) los pone quien llama: cada salida resuelve sus rutas y
# enlaces (el reporte, rutas relativas y anclas; el sitio, URLs de Jekyll).

resumen_md <- function(r) {
  fi <- r$fichas
  tot <- r$ag[r$ag$grupo == r$t_todos, ]
  sin <- r$ag[r$ag$grupo == r$t_sin, ]
  ta <- function(x, col) tasa(x[[col]][x$anio == 1990], x[[col]][x$anio == 2020], 30)
  sprintf(tr(
    "Across the %d cities, built-up land inside the urban extent grew from %s km² in 1990 to %s km² in 2020 (%s %% a year); without %s, from %s to %s km² (%s %% a year). The fringe open space is %s %% of the total urban extent in 2020, and between %s %% and %s %% city by city. Counting it adds %s-%s %% to the area of each city, and moves its 1990-2020 growth rate by less than 0.2 points a year in %d of the %d.",
    "I de %d städerna växte den bebyggda marken inom den urbana utbredningen från %s km² år 1990 till %s km² år 2020 (%s %% per år); utan %s, från %s till %s km² (%s %% per år). Den öppna randzonen utgör %s %% av den samlade urbana utbredningen 2020, och mellan %s %% och %s %% stad för stad. Att räkna med den lägger till %s-%s %% till varje stads yta, och ändrar tillväxttakten 1990-2020 med mindre än 0,2 procentenheter per år i %d av de %d."),
    r$n, f0(tot$construido_ciudad_km2[tot$anio == 1990]), f0(tot$construido_ciudad_km2[tot$anio == 2020]),
    f2(ta(tot, "construido_ciudad_km2")), r$nm_mayor, f0(sin$construido_ciudad_km2[sin$anio == 1990]),
    f0(sin$construido_ciudad_km2[sin$anio == 2020]), f2(ta(sin, "construido_ciudad_km2")),
    f1(tot$pct_franja[tot$anio == 2020]), f1(min(fi$franja_2020)), f1(max(fi$franja_2020)),
    f0(min(fi$suma_franja_2020)), f0(max(fi$suma_franja_2020)), sum(abs(fi$dif) < 0.2), r$n)
}

metodo_md <- function(r, h = "##") {
  # el metodo, con encabezados de nivel h
  h2 <- paste0(h, "#")
  comp <- r$compartidas
  if (LANG == "sv") {
    return(c(paste(h, "Data"), "",
      "- **GISD30** (Zhang m.fl. 2022, *Earth System Science Data* 14:1831-1856, CC BY 4.0): global hårdgjord yta i 30 m upplösning från Landsat. Varje pixel anger perioden då den först upptäcktes: 0 aldrig, 1 före 1985, 2-8 femårsperioder 1985-2020. Serien är kumulativ: en pixel slutar aldrig vara bebyggd.",
      "- **Decennier** (`01_gisd30_decadas.R`): bebyggt till 1990 = värde 1-2, till 2000 = 1-4, till 2010 = 1-6, till 2020 = 1-8.",
      "- **Stadsgränser** (`07_limites_aglomerados.R`): SCB:s statistiska tätorter 2020 (öppna geodata). En tätort är en sammanhängande bebyggelse med minst 200 invånare där husen ligger högst 200 m från varandra.",
      "- **Rutor** (`cajas.md`): tätortens omskrivande rektangel plus 10 km åt varje håll, så att grannskapet på 1 km² aldrig tar slut vid stadens kant.",
      "- Varje ruta projiceras om till sin UTM-zon i 30 m (närmaste granne) så att avstånd blir metriska.", "",
      paste(h, "Klasser"), "",
      sprintf("Varje pixel på 30 m tittar på cirkeln på 1 km² runt sig (radie 564 m) och den andel av cirkeln som är bebyggd. Landsbygdsgräns som används här: **%s** (Atlas 2016).", f2(r$u_rural)), "",
      tabla(c("Värde", "Klass", "Regel", "I den urbana utbredningen?"), list(
        c("0", ETQ_RURAL[2], "obebyggd, inget av nedanstående", "nej"),
        c("1", ETQ[["urbano"]], "bebyggd, cirkeln > 50 % bebyggd", "ja"),
        c("2", ETQ[["suburbano"]], sprintf("bebyggd, cirkeln %s-50 %% bebyggd", f0(100 * r$u_rural)), "ja"),
        c("3", ETQ_RURAL[1], sprintf("bebyggd, cirkeln < %s %% bebyggd", f0(100 * r$u_rural)), "nej"),
        c("4", ETQ[["franja"]], "obebyggd, inom 100 m från urban eller förortsbebyggelse", "ja"),
        c("5", ETQ[["capturado"]], "öppen fläck (4-grannskap) under 200 ha, helt omsluten, rör inte rutans kant", "ja"))), "",
      "**Urban utbredning** = urban + förort + randzon + innesluten.", "",
      paste(h2, "Hur randzonen ritas"), "",
      "En cirkel på 100 m centreras på varje urban och förortspixel; varje obebyggd pixel inom någon av cirklarna är randzon. På rutnätet når cirkeln 3 pixlar rakt ut (90 m) och 85-95 m diagonalt. Landsbygdsbebyggelse ger ingen randzon. Innesluten öppen mark tilldelas efter randzonen, så de överlappar aldrig.", "",
      "Eftersom varje bebyggd kant får sin egen ring växer randzonen med *längden på stadens kant*, inte med dess yta: splittrade städer har mest randzon, och en stad som bygger på sin gamla randzon förlorar randzon när den växer.", "",
      paste(h, "\"Staden\""), "",
      "Inom varje ruta är staden de fläckar av urban utbredning (8-grannskap) som rör tätortsgränsen. En ort i rutan som aldrig rör gränsen räknas inte; en grannort vars utbredning växer ihop med staden (via randzonen räcker) räknas med.", "",
      if (length(comp)) sprintf("När en fläck rör två städers tätorter går varje pixel till den närmaste gränsen. Det gäller här: %s.", lista(r$info$nombre[r$info$slug %in% comp]))
      else "Ingen ruta innehåller en annan studerad stads tätort, så regeln om delade fläckar (från den argentinska versionen) används aldrig här.", "",
      paste(h, "Mått"), "",
      tabla(c("Mått", "Definition"), list(
        c("bebyggd mark", "bebyggda pixlar inom stadens urbana utbredning"),
        c("mättnad", "bebyggd mark / urban utbredning"),
        c("öppenhet", "genomsnittlig obebyggd andel av cirkeln på 1 km² runt stadens urbana och förortspixlar"),
        c("randzonsandel", "öppen randzon / urban utbredning"),
        c("tillväxt", "årlig genomsnittlig takt, (x1 / x0)^(1 / år) - 1"),
        c("fotavtryck 2007", "definitionen från Angel, Parent & Civco 2007 (landsbygdsgräns 0,10): bebyggt med ≥ 10 % av cirkeln bebyggd, plus obebyggda pixlar med > 50 % bebyggt runt sig eller inom 100 m från den bebyggelsen; fläckar som rör gränsen"))), "",
      paste(h, "Regler för att beskriva städerna"), "",
      sprintf("- **Takt** (tillväxt i bebyggd mark 1990-2020 per år): %s ≥ 4 %%, %s ≥ 2,5 %%, %s ≥ 1,5 %%, %s < 1,5 %%.", RITMOS[4], RITMOS[3], RITMOS[2], RITMOS[1]),
      sprintf("- **Form** (förändring i mättnad 1990-2020): %s ≥ +0,03, %s ≤ -0,03, %s däremellan.", FORMAS[1], FORMAS[3], FORMAS[2]),
      "- **Kontroll**: tillväxt i bebyggd mark ≥ 4 % per år flaggas för granskning mot GHSL eller bilder.", "",
      paste(h, "Förbehåll"), "",
      "- **GISD30 är den enda indatan.** Upptäckten 1985-2000 är seriens svagaste (få Landsat 5-scener), så en del av accelerationen efter 2000 kan komma från datan. På svenska breddgrader minskar snötäcke, låg solhöjd och moln antalet användbara scener, och gles småhusbebyggelse bland träd kan underskattas i 30 m.",
      "- **Vatten räknas som öppen mark.** GISD30 har ingen vattenmask, så stränder och kuster intill staden blir randzon eller innesluten öppen mark. Det väger tungt i Sverige (Mälaren, skärgården, Göta älv). Atlas tar bort vatten från den öppna marken; det gör inte den här kedjan ännu.",
      "- **Tätortsgränsen är från 2020.** Den avgör vilka fläckar som är \"staden\" alla fyra åren; den används inte för att klippa pixlar.",
      "- **Närhet redovisas inte**: mätt mot tyngdpunkten säger den lite om stadens form.",
      "- **Landsbygdsgräns**: Atlas 2016 sätter förort till 25-50 %; definitionen från 2007 använder 10 %, så dess fotavtryck är större än utbredningen som mäts här.",
      "- **Ingen täthet ännu**: det kräver befolkning per ruta (SCB:s befolkningsrutnät är ett naturligt nästa steg)."))
  }
  c(paste(h, "Data"), "",
    "- **GISD30** (Zhang et al. 2022, *Earth System Science Data* 14:1831-1856, CC BY 4.0): global impervious surface at 30 m from Landsat. Each pixel stores the period of its first detection: 0 never, 1 before 1985, 2-8 five-year periods 1985-2020. The record is cumulative: a pixel never stops being built.",
    "- **Decades** (`01_gisd30_decadas.R`): built-up by 1990 = values 1-2, by 2000 = 1-4, by 2010 = 1-6, by 2020 = 1-8.",
    "- **City boundaries** (`07_limites_aglomerados.R`): Statistics Sweden (SCB) statistical *tätorter* 2020 (open geodata). A tätort is a continuous built-up area of at least 200 inhabitants with houses no more than 200 m apart.",
    "- **Boxes** (`cajas.md`): the tätort's bounding box plus 10 km on every side, so the 1 km² neighbourhood never runs out of data at the edge of the city.",
    "- Each box is reprojected to its UTM zone at 30 m (nearest neighbour) so that distances are metric.", "",
    paste(h, "Classes"), "",
    sprintf("Each 30 m pixel looks at the circle of 1 km² around it (radius 564 m) and the share of that circle that is built-up. Rural cut used here: **%s** (Atlas 2016 edition).", f2(r$u_rural)), "",
    tabla(c("Value", "Class", "Rule", "In the urban extent?"), list(
      c("0", "rural open space", "not built-up, none of the below", "no"),
      c("1", "urban built-up", "built-up, circle > 50 % built", "yes"),
      c("2", "suburban built-up", sprintf("built-up, circle %s-50 %% built", f0(100 * r$u_rural)), "yes"),
      c("3", "rural built-up", sprintf("built-up, circle < %s %% built", f0(100 * r$u_rural)), "no"),
      c("4", "fringe open space", "not built-up, within 100 m of urban or suburban built-up", "yes"),
      c("5", "captured open space", "open patch (4-connected) under 200 ha, fully enclosed, not touching the box edge", "yes"))), "",
    "**Urban extent** = urban + suburban + fringe + captured.", "",
    paste(h2, "How the fringe is drawn"), "",
    "A 100 m circle on the 30 m grid is centred on every urban and suburban pixel; every pixel that is not built-up and falls inside one of those circles is fringe. On the grid the circle reaches 3 pixels straight out (90 m) and 85-95 m on the diagonals. Rural built-up pixels do not make fringe. Captured open space is assigned after the fringe, so the two never overlap.", "",
    "Because each built edge brings its own ring, the fringe grows with the *length of the city's edge*, not with its area: fragmented cities carry the most fringe, and a city that builds on its old fringe loses fringe as it grows.", "",
    paste(h, "\"The city\""), "",
    "Inside each box, the city is the set of urban-extent patches (8-connected) that touch the tätort boundary. A town inside the box that never touches the boundary is left out; a neighbouring town whose extent grows into the city's (the fringe is enough) counts with it.", "",
    if (length(comp)) sprintf("When one patch touches the tätorter of two cities, each of its pixels goes to the nearer boundary. It applies here to: %s.", lista(r$info$nombre[r$info$slug %in% comp]))
    else "No box contains the tätort of another city in the study, so the shared-patch rule (from the Argentine version) never applies here.", "",
    paste(h, "Metrics"), "",
    tabla(c("Metric", "Definition"), list(
      c("built-up", "built-up pixels inside the city's urban extent"),
      c("saturation", "built-up / urban extent"),
      c("openness", "average unbuilt share of the 1 km² circle around the city's urban and suburban pixels"),
      c("fringe share", "fringe open space / urban extent"),
      c("growth", "annual compound rate, (x1 / x0)^(1 / years) - 1"),
      c("2007 footprint", "the Angel, Parent & Civco 2007 definition (rural cut 0.10): built-up with ≥ 10 % of its circle built, plus unbuilt pixels with > 50 % built around them or within 100 m of that built-up; patches touching the boundary"))), "",
    paste(h, "Rules used to describe the cities"), "",
    "- **Pace** (built-up growth 1990-2020 per year): very fast ≥ 4 %, fast ≥ 2.5 %, moderate ≥ 1.5 %, slow < 1.5 %.",
    "- **Shape** (saturation change 1990-2020): filling in ≥ +0.03, spreading out ≤ -0.03, stable in between.",
    "- **Check**: built-up growth ≥ 4 % a year is flagged for review against GHSL or imagery.", "",
    paste(h, "Caveats"), "",
    "- **GISD30 is the only input.** Its 1985-2000 detection is the weakest of the series (few Landsat 5 scenes), so part of the post-2000 acceleration may come from the data. At Swedish latitudes snow cover, low sun and clouds cut the number of usable scenes, and low-density housing among trees may be under-detected at 30 m.",
    "- **Water counts as open space.** GISD30 has no water mask, so shores and coasts next to the city become fringe or captured open space. This weighs heavily in Sweden (Mälaren, the archipelagos, Göta älv). The Atlas removes water from open space; this pipeline does not yet.",
    "- **The tätort boundary is from 2020.** It decides which patches are \"the city\" in all four years; it is not used to cut pixels.",
    "- **Proximity is not reported**: measured to the centroid it says little about the city's shape.",
    "- **Rural cut**: the Atlas 2016 edition puts suburban at 25-50 %; the 2007 definition uses 10 %, so its footprint is larger than the extent measured here.",
    "- **No density yet**: it needs population per grid cell (the SCB population grid is the natural next step).")
}

sverige_md <- function(r, img, enlace, h = "##") {
  fi <- r$fichas
  h2 <- paste0(h, "#")
  tot <- r$ag[r$ag$grupo == r$t_todos, ]
  sin <- r$ag[r$ag$grupo == r$t_sin, ]
  ta <- function(x, col) tasa(x[[col]][x$anio == 1990], x[[col]][x$anio == 2020], 30)
  grupo <- function(col, valor) lista(vapply(fi$slug[fi[[col]] == valor], enlace, ""))
  cab <- c("", ETQ[["urbano"]], ETQ[["suburbano"]], ETQ[["capturado"]], ETQ[["franja"]],
           tr("extent", "utbredning"), tr("% fringe", "% randzon"), ETQ_MED[["construido"]])
  tabla_ag <- function(x) tabla(cab,
    lapply(seq_len(nrow(x)), function(i) with(x[i, ], c(anio, f1(urbano_ciudad_km2), f1(suburbano_ciudad_km2),
      f1(capturado_ciudad_km2), f1(franja_ciudad_km2), f1(extension_ciudad_km2), f1(pct_franja),
      f1(construido_ciudad_km2)))))
  neg <- fi$slug[order(fi$dif)]
  neg <- head(neg[fi$dif[match(neg, fi$slug)] < 0], 3)
  pos <- fi$slug[order(-fi$dif)]
  pos <- head(pos[fi$dif[match(pos, fi$slug)] > 0], 3)
  c(paste(h, tr("Totals", "Summor")), "",
    img("sverige_composicion.png", tr("Urban extent of Sweden's largest cities by component",
                                      "Urban utbredning i Sveriges största städer per komponent")), "",
    sprintf("%s %s (km²)", h2, r$t_todos), "", tabla_ag(tot), "",
    sprintf("%s %s (km²)", h2, r$t_sin), "", tabla_ag(sin), "",
    sprintf(tr("Annual growth 1990-2020: built-up %s %%, extent without fringe %s %%, extent with fringe %s %% (all %d); %s, %s and %s %% without %s.",
               "Årlig tillväxt 1990-2020: bebyggd mark %s %%, utbredning utan randzon %s %%, utbredning med randzon %s %% (alla %d); %s, %s och %s %% utan %s."),
            f2(ta(tot, "construido_ciudad_km2")), f2(ta(tot, "sin_franja")), f2(ta(tot, "extension_ciudad_km2")), r$n,
            f2(ta(sin, "construido_ciudad_km2")), f2(ta(sin, "sin_franja")), f2(ta(sin, "extension_ciudad_km2")), r$nm_mayor), "",
    paste(h, tr("How each city is growing", "Hur varje stad växer")), "",
    img("sverige_crecimiento.png", tr("Annual growth 1990-2020 of each city", "Årlig tillväxt 1990-2020 per stad")), "",
    tabla(c(tr("Pace", "Takt"), tr("Cities", "Städer")),
          lapply(rev(levels(fi$ritmo)), function(x) c(sprintf("**%s**", x), grupo("ritmo", x)))), "",
    tabla(c(tr("Shape", "Form"), tr("Cities", "Städer")),
          lapply(FORMAS, function(x) c(sprintf("**%s**", x), grupo("forma", x)))), "",
    sprintf(tr("**To check** (built-up ≥ 4 %% a year, see the caveats): %s.",
               "**Att kontrollera** (bebyggd mark ≥ 4 %% per år, se förbehållen): %s."),
            lista(vapply(fi$slug[fi$alerta], enlace, ""))), "",
    img("sverige_indices.png", tr("Saturation and openness, 1990 and 2020", "Mättnad och öppenhet, 1990 och 2020")), "",
    paste(h, tr("How much the fringe open space matters", "Hur mycket den öppna randzonen betyder")), "",
    paste(h2, tr("On the size of the city", "För stadens storlek")), "",
    sprintf(tr("In 2020 the fringe is between %s %% and %s %% of the urban extent; counting it adds %s-%s %% to the area of everything else. Anything divided by the urban extent (population density, share of the city in a given condition) moves by that much depending on whether the fringe is in.",
               "År 2020 är randzonen mellan %s %% och %s %% av den urbana utbredningen; att räkna med den lägger till %s-%s %% till ytan av resten. Allt som delas med den urbana utbredningen (befolkningstäthet, andel av staden i ett visst tillstånd) rör sig så mycket beroende på om randzonen räknas."),
            f1(min(fi$franja_2020)), f1(max(fi$franja_2020)), f0(min(fi$suma_franja_2020)), f0(max(fi$suma_franja_2020))), "",
    img("sverige_franja.png", tr("Fringe share 1990 and 2020", "Randzonens andel 1990 och 2020")), "",
    paste(h2, tr("On growth", "För tillväxten")), "",
    sprintf(tr("Counting the fringe moves the 1990-2020 growth rate by less than 0.2 points a year in %d of the %d cities. It lowers growth most where the city fills in its old fringe (%s) and raises it most where new scattered patches add new fringe (%s).",
               "Att räkna med randzonen ändrar tillväxttakten 1990-2020 med mindre än 0,2 procentenheter per år i %d av de %d städerna. Den sänker tillväxten mest där staden bygger på sin gamla randzon (%s) och höjer den mest där nya spridda fläckar ger ny randzon (%s)."),
            sum(abs(fi$dif) < 0.2), r$n, lista(vapply(neg, enlace, "")), lista(vapply(pos, enlace, ""))), "",
    img("sverige_efecto_franja.png", tr("Effect of the fringe on growth", "Randzonens effekt på tillväxten")), "",
    paste(h, tr("All cities", "Alla städer")), "",
    tr("Growth in % per year, 1990-2020. Extent in km², 2020. Population: tätort 2020 (SCB).",
       "Tillväxt i % per år, 1990-2020. Utbredning i km², 2020. Befolkning: tätort 2020 (SCB)."), "",
    tabla(tr(c("City", "County", "population", "extent 2020", "built-up", "without fringe", "with fringe", "difference",
               "% fringe 2020", "saturation", "pace", "shape"),
             c("Stad", "Län", "befolkning", "utbredning 2020", "bebyggd mark", "utan randzon", "med randzon", "skillnad",
               "% randzon 2020", "mättnad", "takt", "form")),
          lapply(seq_len(nrow(fi)), function(i) with(fi[i, ], c(enlace(slug), provincia, f0(bef), f1(extension_2020),
            f2(t_construido), f2(t_sin), f2(t_con), fs(dif), f1(franja_2020),
            sprintf("%s → %s", f2(sat_1990), f2(sat_2020)), as.character(ritmo), forma)))))
}

ciudad_md <- function(r, s, img, mapas_html, h = "##") {
  # el cuerpo de una ciudad (sin su titulo). mapas_html(s): el bloque de los cuatro mapas
  f <- r$fichas[r$fichas$slug == s, ]
  x <- r$d[r$d$ciudad == s, ]
  dc <- decadas(r, s)
  notas <- c(
    if (f$alerta) sprintf(tr("- **Check:** built-up grows %s %% a year, at or above the 4 %% flag; confirm against GHSL or imagery before using these numbers.",
                             "- **Kontrollera:** den bebyggda marken växer %s %% per år, vid eller över gränsen 4 %%; jämför med GHSL eller bilder innan siffrorna används."),
                          f2(f$t_construido)),
    if (f$partes > 1) sprintf(tr("- The tätort has %d parts; patches touching any of them count as the city.",
                                 "- Tätorten har %d delar; fläckar som rör någon av dem räknas som staden."), f$partes))
  c(sprintf(tr("County: %s. Tätort population 2020 (SCB): %s.", "Län: %s. Tätortens befolkning 2020 (SCB): %s."),
            f$provincia, f0(f$bef)), "",
    sprintf(tr("Built-up land in the city's urban extent grew from **%s km²** in 1990 to **%s km²** in 2020, **%s %% a year** (pace: **%s**). The urban extent went from %s to %s km². Saturation moved from %s to %s (shape: **%s**).",
               "Den bebyggda marken i stadens urbana utbredning växte från **%s km²** år 1990 till **%s km²** år 2020, **%s %% per år** (takt: **%s**). Den urbana utbredningen gick från %s till %s km². Mättnaden gick från %s till %s (form: **%s**)."),
            f1(f$construido_1990), f1(f$construido_2020), f2(f$t_construido), f$ritmo, f1(f$extension_1990),
            f1(f$extension_2020), f2(f$sat_1990), f2(f$sat_2020), f$forma), "",
    sprintf(tr("The fringe open space was %s %% of the urban extent in 1990 and %s %% in 2020; in 2020 it adds %s %% to the rest of the extent. Counting it changes the 1990-2020 growth rate from %s %% to %s %% a year (%s points).",
               "Den öppna randzonen var %s %% av den urbana utbredningen 1990 och %s %% 2020; år 2020 lägger den till %s %% till resten av utbredningen. Att räkna med den ändrar tillväxttakten 1990-2020 från %s %% till %s %% per år (%s procentenheter)."),
            f1(f$franja_1990), f1(f$franja_2020), f0(f$suma_franja_2020), f2(f$t_sin), f2(f$t_con), fs(f$dif)), "",
    if (length(notas)) c(notas, "") else character(),
    paste(h, tr("Growth by class", "Tillväxt per klass")), "",
    img(sprintf("agl/%s_composicion.png", s), sprintf(tr("%s: urban extent by class", "%s: urban utbredning per klass"), f$nombre)), "",
    tabla(c("", ETQ[["urbano"]], ETQ[["suburbano"]], ETQ[["capturado"]], ETQ[["franja"]], tr("extent", "utbredning"),
            tr("% fringe", "% randzon"), ETQ_MED[["construido"]], tr("saturation", "mättnad"), tr("openness", "öppenhet"),
            tr("2007 footprint", "fotavtryck 2007")),
          lapply(seq_len(nrow(x)), function(j) with(x[j, ], c(anio, f1(urbano_ciudad_km2), f1(suburbano_ciudad_km2),
            f1(capturado_ciudad_km2), f1(franja_ciudad_km2), f1(extension_ciudad_km2), f1(pct_franja),
            f1(construido_ciudad_km2), f2(saturacion), f2(apertura), f1(huella_proyecto_ciudad_km2))))), "",
    tr("km². Rural built-up and rural open space lie outside the urban extent; they appear on the maps.",
       "km². Landsbygdsbebyggelse och öppen landsbygd ligger utanför den urbana utbredningen; de syns på kartorna."), "",
    paste(h, tr("Growth by decade", "Tillväxt per decennium")), "",
    img(sprintf("agl/%s_decadas.png", s), sprintf(tr("%s: growth by decade", "%s: tillväxt per decennium"), f$nombre)), "",
    tabla(c(tr("Decade", "Decennium"), ETQ_MED[["construido"]], ETQ_MED[["sin_franja"]], ETQ_MED[["con_franja"]]),
          lapply(unique(dc$decada), function(k) c(k, f2(dc$tasa[dc$decada == k & dc$medida == "construido"]),
            f2(dc$tasa[dc$decada == k & dc$medida == "sin_franja"]), f2(dc$tasa[dc$decada == k & dc$medida == "con_franja"])))), "",
    tr("% per year.", "% per år."), "",
    paste(h, tr("Maps", "Kartor")), "", img("leyenda.png", tr("Map legend", "Kartförklaring")), "", mapas_html(s), "",
    sprintf(tr("Maps are framed on the tätort plus 5 km; the metrics use the larger box of `cajas.md` (slug `%s`).",
               "Kartorna visar tätorten plus 5 km; måtten använder den större rutan i `cajas.md` (slug `%s`)."), s))
}
