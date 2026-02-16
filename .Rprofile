utils::install.packages(
  setdiff("pak", rownames(utils::installed.packages()))
)

options(
  renv.config.pak.enabled = TRUE,
  renv.config.ppm.enabled = TRUE,
  renv.config.ppm.default = TRUE,
  repos = c(
    P3M_MANYLINUX = "https://p3m.dev/cran/__linux__/manylinux_2_28/latest", 
    getOption("repos")
  )
)

source("renv/activate.R")
