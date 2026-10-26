# 01_download.R
# Downloads the raw inputs into data/raw/. Pages never read these directly;
# later pipeline scripts turn them into tidy Parquet tables in data/.
#
# Sources:
#   Running times: MTA Subway End-to-End Running Times: Beginning 2019
#     https://data.ny.gov/Transportation/MTA-Subway-End-to-End-Running-Times-Beginning-2019/sp9g-mzjh
#     CSV: https://data.ny.gov/api/views/sp9g-mzjh/rows.csv?accessType=DOWNLOAD
#     ~146k rows: month x day type x time period x line x stop path, Jan 2019 onward
#   Static GTFS (line shapes, stops):
#     https://rrgtfsfeeds.s3.amazonaws.com/gtfs_subway.zip
#
# TODO (Connor): download both into data/raw/ and unzip the GTFS.
# Tips: use here::here("data", "raw", ...) for paths; skip the download
# if the file already exists so re-running is cheap.

library(here)
