options(renv.consent = TRUE)

lockfile <- renv::lockfile_read("renv.lock")
locked_r_version <- lockfile[["R"]][["Version"]]

if (
  !is.null(locked_r_version) &&
  !identical(as.character(getRversion()), locked_r_version)
) {
  warning(
    "R version mismatch: image provides ",
    getRversion(),
    " but renv.lock requires ",
    locked_r_version,
    ". Continuing with the image R version.",
    call. = FALSE,
    immediate. = TRUE
  )
}

renv::restore(clean = TRUE, prompt = FALSE)
