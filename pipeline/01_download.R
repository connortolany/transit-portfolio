# 01_download.R
# Downloads the raw inputs into data/raw/. Pages never read these directly;
# later pipeline scripts turn them into tidy Parquet tables in data/.
#
# Sources:
#   Running times: MTA Subway End-to-End Running Times: Beginning 2019
#     https://data.ny.gov/Transportation/MTA-Subway-End-to-End-Running-Times-Beginning-2019/sp9g-mzjh
#     ~146k rows: month x day type x time period x line x stop path, Jan 2019 onward
#   Static GTFS (line shapes, stops):
#     https://rrgtfsfeeds.s3.amazonaws.com/gtfs_subway.zip
#
# Usage: Rscript pipeline/01_download.R          (skips files already downloaded)
#        Rscript pipeline/01_download.R --refresh (re-downloads everything)

library(here)

refresh <- "--refresh" %in% commandArgs(trailingOnly = TRUE)

raw_dir <- here("data", "raw")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

# The CSV is tens of MB; R's default 60-second timeout is too short.
options(timeout = 600)

# Download `url` to `dest` unless it's already there.
download_once <- function(url, dest) {
  if (file.exists(dest) && !refresh) {
    message("Already have ", basename(dest), " (use --refresh to re-download)")
    return(invisible(dest))
  }
  message("Downloading ", basename(dest), " ...")
  # Download to a temp name first so an interrupted download never
  # leaves a half-written file that looks complete.
  tmp <- paste0(dest, ".part")
  download.file(url, tmp, mode = "wb", quiet = TRUE)
  file.rename(tmp, dest)
  message("  ", round(file.size(dest) / 1e6, 1), " MB")
  invisible(dest)
}

# 1. Running times ---------------------------------------------------------

running_times_csv <- download_once(
  "https://data.ny.gov/api/views/sp9g-mzjh/rows.csv?accessType=DOWNLOAD",
  file.path(raw_dir, "running_times.csv")
)

# 2. Static GTFS -----------------------------------------------------------

gtfs_zip <- download_once(
  "https://rrgtfsfeeds.s3.amazonaws.com/gtfs_subway.zip",
  file.path(raw_dir, "gtfs_subway.zip")
)

# Unzip so the individual .txt files (shapes, stops, routes) are easy to read.
gtfs_dir <- file.path(raw_dir, "gtfs")
if (!dir.exists(gtfs_dir) || refresh) {
  unzip(gtfs_zip, exdir = gtfs_dir)
}

# 3. Record when we pulled the data -----------------------------------------
# The site's "Method" section should say what date the data is as of.
# Only stamp it when the running-times file was actually (re)downloaded.

stamp <- file.path(raw_dir, "downloaded_at.txt")
if (!file.exists(stamp) || file.mtime(running_times_csv) > file.mtime(stamp)) {
  writeLines(format(Sys.time(), "%Y-%m-%d %H:%M %Z"), stamp)
}

message("Done. Files in ", raw_dir, ":")
print(list.files(raw_dir, recursive = TRUE))
