options(renv.consent = TRUE)

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) {
    return(y)
  }
  if (is.character(x) && !nzchar(x[[1L]])) {
    return(y)
  }
  x
}

ncpus <- function() {
  detected <- parallel::detectCores()
  if (is.na(detected)) {
    return(1L)
  }
  max(1L, detected)
}

ensure_repos <- function() {
  repos <- getOption("repos")
  if (
    is.null(repos) ||
      !length(repos) ||
      identical(unname(repos[["CRAN"]]), "@CRAN@")
  ) {
    options(repos = c(CRAN = "https://cloud.r-project.org"))
  }
}

ensure_package <- function(package) {
  if (requireNamespace(package, quietly = TRUE)) {
    return(invisible(TRUE))
  }

  ensure_repos()
  install.packages(package, Ncpus = ncpus())
}

setup_modes <- function() {
  raw <- Sys.getenv("ND_SETUP_ENVS", unset = "all")
  modes <- unique(tolower(unlist(strsplit(raw, "[,[:space:]]+"))))
  modes <- modes[nzchar(modes)]

  if ("all" %in% modes) {
    modes <- c("r", "python")
  }

  modes[modes == "renv"] <- "r"
  modes[modes == "py"] <- "python"

  invalid <- setdiff(modes, c("r", "python"))
  if (length(invalid)) {
    stop(
      "Invalid ND_SETUP_ENVS value(s): ",
      paste(invalid, collapse = ", "),
      ". Use all, R, or PYTHON.",
      call. = FALSE
    )
  }

  modes
}

ensure_package("renv")

lockfile <- renv::lockfile_read("renv.lock")

check_r_version <- function(lockfile) {
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
}

setup_r <- function(lockfile) {
  check_r_version(lockfile)
  renv::restore(clean = TRUE, prompt = FALSE)
}

setup_python <- function(lockfile) {
  python <- lockfile[["Python"]]
  if (is.null(python)) {
    message("No Python environment recorded in renv.lock; skipping Python setup.")
    return(invisible(FALSE))
  }

  python_version <- python[["Version"]]
  python_type <- python[["Type"]] %||% ""
  python_env <- Sys.getenv("ND_PYTHON_VENV", unset = python[["Name"]] %||% "./venv")
  requirements <- Sys.getenv("ND_PYTHON_REQUIREMENTS", unset = "requirements.txt")

  if (!nzchar(python_version)) {
    stop("renv.lock Python section does not define a Python version.", call. = FALSE)
  }
  if (!identical(python_type, "virtualenv")) {
    stop("Only Python virtualenv setup is supported.", call. = FALSE)
  }
  if (!file.exists(requirements)) {
    stop("Missing Python requirements file: ", requirements, call. = FALSE)
  }

  ensure_package("reticulate")

  message("Installing or reusing Python ", python_version, " through reticulate/pyenv.")
  python_exe <- reticulate::install_python(version = python_version)

  if (reticulate::virtualenv_exists(python_env)) {
    reticulate::virtualenv_remove(python_env, confirm = FALSE)
  } else if (dir.exists(python_env)) {
    unlink(python_env, recursive = TRUE)
  }

  message("Creating Python virtualenv at ", python_env, ".")
  created_env <- reticulate::virtualenv_create(
    envname = python_env,
    python = python_exe
  )
  python_bin <- reticulate::virtualenv_python(envname = created_env)

  Sys.setenv(RENV_PYTHON = python_bin, RETICULATE_PYTHON = python_bin)

  requirements <- normalizePath(requirements, winslash = "/", mustWork = TRUE)

  message("Installing Python packages from ", requirements, ".")
  status <- system2(python_bin, c("-m", "pip", "install", "--upgrade", "pip"))
  if (!identical(status, 0L)) {
    stop("Failed to upgrade pip in ", python_env, ".", call. = FALSE)
  }

  status <- system2(python_bin, c("-m", "pip", "install", "-r", requirements))
  if (!identical(status, 0L)) {
    stop("Failed to install Python requirements into ", python_env, ".", call. = FALSE)
  }

  invisible(TRUE)
}

modes <- setup_modes()

if ("r" %in% modes) {
  setup_r(lockfile)
}

if ("python" %in% modes) {
  setup_python(lockfile)
}
