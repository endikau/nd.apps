options(renv.consent = TRUE)

lockfile <- renv::lockfile_read("renv.lock")
locked_r_version <- lockfile[["R"]][["Version"]]

if (!identical(as.character(getRversion()), locked_r_version)) {
  stop(
    "R version mismatch: image provides ",
    getRversion(),
    " but renv.lock requires ",
    locked_r_version
  )
}

renv::restore(clean = TRUE, prompt = FALSE)
