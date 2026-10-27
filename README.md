# Subway, Measured

How New York's subway actually runs compared with its schedule, built in R from MTA open data.

**Site:** https://connortolany.github.io/transit-portfolio/

## Layout

```
pipeline/    R scripts that download raw data and build tidy tables (run in order)
data/        raw downloads and finished Parquet tables (not in git)
analyses/    one Quarto page per analysis
index.qmd    home page
_quarto.yml  site settings and nav bar
assets/      theme (upshot.scss) and images
```

Each layer only reads from the one above it: pages read the finished tables in `data/`, never raw downloads.

## Rebuild

```bash
Rscript pipeline/01_download.R   # then the other pipeline scripts in order
quarto preview                   # live local preview
quarto publish gh-pages          # render and publish to GitHub Pages
```

## Data

- MTA subway alerts feed (GTFS-realtime), archived daily by [subwaydata.nyc](https://subwaydata.nyc/programmatic-access). The source for planned service interruptions, which the MTA doesn't publish as an open dataset. `pipeline/02_download_alerts.R` keeps one snapshot per 10 minutes.
- [MTA Subway End-to-End Running Times: Beginning 2019](https://data.ny.gov/Transportation/MTA-Subway-End-to-End-Running-Times-Beginning-2019/sp9g-mzjh)
- [MTA static subway GTFS](https://rrgtfsfeeds.s3.amazonaws.com/gtfs_subway.zip)
