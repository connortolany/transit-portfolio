# 02_download_alerts.R
# Downloads archived snapshots of the MTA subway alerts feed (GTFS-realtime),
# which is where planned work lives. The MTA doesn't publish planned work as an
# open dataset, so we rebuild it from these snapshots.
#
# Source: subwaydata.nyc archives every MTA real-time feed daily since April 2021.
#   https://subwaydata.nyc/data/subwaydatanyc_YYYY-MM-DD_gtfsrt.tar.xz
# Each daily archive (~30-60 MB) holds every feed; we keep only the alerts feed.
#
# Thinning: the archive has up to ~3,200 alerts snapshots/day (~1 GB uncompressed)
# in Jan-Mar 2026 and ~150-450/day from April on. The archiver drops snapshots
# identical to the previous one, so a gap between files means the feed didn't
# change, and each file's state holds until the next file. Planned work changes
# on a scale of hours, so we keep the LAST snapshot in each 10-minute window
# (<=144/day): that's the state that persists into the next window.
#
# Output: data/raw/alerts/alerts_YYYY-MM-DD.tar.xz, plus a log of each day.
#
# Usage: Rscript pipeline/02_download_alerts.R                       (2026-01-01 to 2 days ago)
#        Rscript pipeline/02_download_alerts.R 2026-01-01 2026-01-07 (a date range)
# Days already downloaded are skipped, so it's safe to stop and re-run.

library(here)

args <- commandArgs(trailingOnly = TRUE)
start_date <- as.Date(if (length(args) >= 1) args[1] else "2026-01-01")
# The archive is updated each morning with the previous day; 2 days back is safe.
end_date   <- as.Date(if (length(args) >= 2) args[2] else Sys.Date() - 2)

out_dir <- here("data", "raw", "alerts")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
log_file <- file.path(out_dir, "_download_log.csv")

options(timeout = 600)
snapshot_minutes <- 10

log_day <- function(date, status, n_snapshots = NA, n_kept = NA) {
  row <- data.frame(date = format(date), status, n_snapshots, n_kept,
                    logged_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
  write.table(row, log_file, sep = ",", row.names = FALSE,
              col.names = !file.exists(log_file), append = file.exists(log_file))
}

download_day <- function(date) {
  dest <- file.path(out_dir, paste0("alerts_", date, ".tar.xz"))
  if (file.exists(dest)) return(invisible("skipped"))

  work <- tempfile("alerts_")
  dir.create(work)
  on.exit(unlink(work, recursive = TRUE), add = TRUE)

  # 1. Download the full day of raw feeds
  url <- sprintf("https://subwaydata.nyc/data/subwaydatanyc_%s_gtfsrt.tar.xz", date)
  archive <- file.path(work, "day.tar.xz")
  ok <- tryCatch({
    download.file(url, archive, mode = "wb", quiet = TRUE)
    TRUE
  }, error = function(e) FALSE)
  if (!ok) {
    message(date, ": download failed")
    log_day(date, "download_failed")
    return(invisible("failed"))
  }

  # 2. Extract only the alerts snapshots
  snap_dir <- file.path(work, "snapshots")
  dir.create(snap_dir)
  system2("tar", c("-xJf", archive, "-C", snap_dir, "--include", "'nycsubway_alerts_*'"))
  unlink(archive)
  files <- sort(list.files(snap_dir, pattern = "^nycsubway_alerts_"))
  if (length(files) == 0) {
    message(date, ": no alerts snapshots in archive")
    log_day(date, "no_alerts", 0, 0)
    return(invisible("empty"))
  }

  # 3. Keep the last snapshot in each 10-minute window.
  # File names look like nycsubway_alerts_20260115T053118.031Z_dw47csdwffoy.gtfsrt
  stamp <- as.POSIXct(sub("^nycsubway_alerts_(\\d{8}T\\d{6}).*", "\\1", files),
                      format = "%Y%m%dT%H%M%S", tz = "UTC")
  window <- floor(as.numeric(stamp) / (snapshot_minutes * 60))
  keep <- files[!duplicated(window, fromLast = TRUE)]

  # 4. Repack the kept snapshots. Write to a temp name, then rename, so an
  # interrupted run never leaves a partial file that looks complete.
  tmp_dest <- paste0(dest, ".part")
  system2("tar", c("-cJf", shQuote(tmp_dest), "-C", shQuote(snap_dir), keep))
  file.rename(tmp_dest, dest)

  message(sprintf("%s: kept %d of %d snapshots (%.1f MB)",
                  date, length(keep), length(files), file.size(dest) / 1e6))
  log_day(date, "ok", length(files), length(keep))
  invisible("ok")
}

dates <- seq(start_date, end_date, by = "day")
message("Downloading alerts for ", length(dates), " days: ", start_date, " to ", end_date)

for (d in as.list(dates)) {
  result <- download_day(d)
  # Be polite to a volunteer-run archive: pause between real downloads.
  if (result != "skipped") Sys.sleep(2)
}

message("Done. ", length(list.files(out_dir, pattern = "^alerts_.*\\.tar\\.xz$")),
        " days in ", out_dir)
