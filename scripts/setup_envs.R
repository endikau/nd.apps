install.packages(
  pkgs = setdiff(
    c("renv", "callr", "cli", "pak"),
    rownames(installed.packages())
  ),
  repos = "https://cloud.r-project.org"
)

callr::r(
  \(...) {
    renv::activate()
  },
  show = TRUE
)

callr::r(
  \(...) {
    renv::restore()
  },
  show = TRUE
)

callr::r(
  \(...) {
    renv::install(
      c("yaml", "reticulate", "m-pilarski/helprrr"),
      prompt = FALSE
    )
  },
  show = TRUE
)

cli::cli_alert_success("renv")

callr::r(
  \(...) {
    .python_pyenv_path <- reticulate::install_python(
      "3.12:latest",
      force = FALSE
    )
    if (!reticulate::virtualenv_exists("./venv")) {
      reticulate::virtualenv_create(
        envname = "./venv",
        python = .python_pyenv_path,
        requiremens = (if (fs::file_exists("requirements.txt")) {
          "requirements.txt"
        } else {
          NULL
        })
      )
    }
    .python_venv_path <- reticulate::virtualenv_python("./venv")
    renv::use_python(.python_venv_path, type = "virtualenv")
    helprrr::setenv_persist(
      RETICULATE_PYTHON = .python_venv_path,
      RENV_PYTHON = .python_venv_path
    )
  },
  show = TRUE
)

cli::cli_alert_success("venv")

callr::r(
  \(...) {
    renv::snapshot(prompt = FALSE)
  },
  show = TRUE
)

cli::cli_alert_success("snapshot")
