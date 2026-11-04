# Cajas de las ciudades

Generado por `scripts/07_limites_aglomerados.R`: no editar a mano. Para agregar una ciudad,
agregar su fila a la tabla CIUDADES de 07 y volver a correrlo.

- **contorno**: el tatort de SCB 2020, en la capa `perimetro` de `raw/boundaries/aglomerados.gpkg`.
- **caja**: `lat0,lon0,lat1,lon1`, recuadro del tatort mas 10 km de cada lado (en SWEREF99 TM),
  pasado a grados WGS84 y agrandado hasta cubrirlo.

| slug | contorno | lat0 | lon0 | lat1 | lon1 | origen | partes |
|---|---|---|---|---|---|---|---|
| stockholm | stockholm | 59.0527 | 17.5740 | 59.5792 | 18.6293 | perimetro + 10 km | 1 |
| goteborg | goteborg | 57.3973 | 11.6178 | 57.9159 | 12.3663 | perimetro + 10 km | 1 |
| malmo | malmo | 55.4507 | 12.7416 | 55.7424 | 13.2812 | perimetro + 10 km | 1 |
| uppsala | uppsala | 59.6863 | 17.3588 | 59.9964 | 17.9253 | perimetro + 10 km | 1 |
| vasteras | vasteras | 59.4834 | 16.2610 | 59.7764 | 16.8272 | perimetro + 10 km | 1 |
| orebro | orebro | 59.0956 | 14.9220 | 59.4256 | 15.4628 | perimetro + 10 km | 1 |
| linkoping | linkoping | 58.2689 | 15.3615 | 58.5278 | 15.8931 | perimetro + 10 km | 1 |
| helsingborg | helsingborg | 55.8909 | 12.4926 | 56.1870 | 12.9482 | perimetro + 10 km | 1 |
| jonkoping | jonkoping | 57.5743 | 13.9168 | 57.9162 | 14.4932 | perimetro + 10 km | 1 |
| norrkoping | norrkoping | 58.4503 | 15.9387 | 58.7179 | 16.4328 | perimetro + 10 km | 1 |
| lund | lund | 55.5877 | 12.9791 | 55.8278 | 13.4191 | perimetro + 10 km | 1 |
| umea | umea | 63.6877 | 19.9022 | 63.9731 | 20.6124 | perimetro + 10 km | 1 |
| gavle | gavle | 60.5304 | 16.8625 | 60.8407 | 17.5128 | perimetro + 10 km | 1 |
| sodertalje | sodertalje | 59.0624 | 17.3848 | 59.3255 | 17.8777 | perimetro + 10 km | 1 |
| boras | boras | 57.6005 | 12.6790 | 57.8556 | 13.2093 | perimetro + 10 km | 1 |
| halmstad | halmstad | 56.5332 | 12.5743 | 56.8006 | 13.1259 | perimetro + 10 km | 1 |
| vaxjo | vaxjo | 56.7418 | 14.5481 | 57.0323 | 15.0336 | perimetro + 10 km | 1 |
| eskilstuna | eskilstuna | 59.2208 | 16.2118 | 59.4944 | 16.7492 | perimetro + 10 km | 1 |
| karlstad | karlstad | 59.2646 | 13.2312 | 59.5440 | 13.7783 | perimetro + 10 km | 1 |
| sundsvall | sundsvall | 62.2674 | 16.9722 | 62.5665 | 17.6061 | perimetro + 10 km | 1 |
| ostersund | ostersund | 62.9711 | 14.2989 | 63.3184 | 15.0547 | perimetro + 10 km | 1 |
| trollhattan | trollhattan | 58.1529 | 12.0597 | 58.4239 | 12.5360 | perimetro + 10 km | 1 |
| lulea | lulea | 65.4442 | 21.8166 | 65.7311 | 22.5677 | perimetro + 10 km | 1 |
| borlange | borlange | 60.3257 | 15.1736 | 60.6269 | 15.7231 | perimetro + 10 km | 1 |
| kalmar | kalmar | 56.5567 | 16.1355 | 56.8091 | 16.5497 | perimetro + 10 km | 1 |
| kristianstad | kristianstad | 55.8908 | 13.8630 | 56.1547 | 14.3865 | perimetro + 10 km | 1 |
| skovde | skovde | 58.2693 | 13.6354 | 58.5272 | 14.0862 | perimetro + 10 km | 1 |
| falun | falun | 60.4768 | 15.3953 | 60.7324 | 15.9647 | perimetro + 10 km | 1 |
| nykoping | nykoping | 58.6182 | 16.7796 | 58.8761 | 17.2744 | perimetro + 10 km | 1 |
| karlskrona | karlskrona | 56.0577 | 15.3985 | 56.3261 | 15.8587 | perimetro + 10 km | 1 |
| skelleftea | skelleftea | 64.6152 | 20.6298 | 64.8802 | 21.3558 | perimetro + 10 km | 1 |
| varberg | varberg | 56.9406 | 12.0579 | 57.2433 | 12.4966 | perimetro + 10 km | 1 |
| uddevalla | uddevalla | 58.2315 | 11.6263 | 58.4767 | 12.1900 | perimetro + 10 km | 1 |
| akersberga | akersberga | 59.3559 | 18.0522 | 59.6144 | 18.6148 | perimetro + 10 km | 1 |
| landskrona | landskrona | 55.7605 | 12.6334 | 56.0027 | 13.0548 | perimetro + 10 km | 1 |
