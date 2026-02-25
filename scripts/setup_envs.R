# scripts/setup_envs.R
# Goal: arch-aware PPM binaries + ensure the same options are applied
# in parent AND every callr child process.

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || identical(x, "")) y else x

detect_ubuntu_codename <- function(os_release_path = "/etc/os-release") {
  if (!file.exists(os_release_path)) return(NA_character_)
  os_release <- readLines(os_release_path, warn = FALSE)
  codename <- sub("^VERSION_CODENAME=", "", os_release[grepl("^VERSION_CODENAME=", os_release)])
  if (length(codename) == 1 && nzchar(codename)) codename else NA_character_
}

detect_linux_arch <- function() {
  # Priority:
  # 1) dpkg (Ubuntu/Debian containers; respects target arch under buildx/QEMU)
  # 2) uname -m
  # 3) R fallbacks
  arch <- tryCatch(system("dpkg --print-architecture", intern = TRUE), error = function(e) character())
  if (!length(arch) || !nzchar(arch[1])) {
    arch <- tryCatch(system("uname -m", intern = TRUE), error = function(e) character())
  }

  arch <- if (length(arch)) trimws(tolower(arch[1])) else ""
  if (arch == "" || is.na(arch)) {
    arch <- trimws(tolower(.Platform$r_arch %||% R.version$arch %||% ""))
  }

  if (arch %in% c("amd64", "x86_64")) return("x86_64")
  if (arch %in% c("arm64", "aarch64")) return("aarch64")

  stop("Unsupported or unknown architecture: ", arch)
}

detect_r_minor <- function() {
  paste0(R.version$major, ".", strsplit(R.version$minor, "\\.")[[1]][1])
}

ppm_binary_repo <- function(codename = "noble") {
  sprintf(
    "https://packagemanager.posit.co/cran/latest/bin/linux/%s-%s/%s",
    codename,
    detect_linux_arch(),
    detect_r_minor()
  )
}

make_global_options <- function(target_codename = "noble") {
  codename <- detect_ubuntu_codename()
  if (!identical(codename, target_codename)) return(list())

  cran_bin <- ppm_binary_repo(codename = target_codename)
  ppm_src  <- "https://packagemanager.posit.co/cran/latest"

  list(
    # Base R installs (install.packages): point straight at Linux binaries
    repos = c(CRAN = cran_bin),

    # renv: enable PPM integration (uses source-style URL; renv transforms internally)
    renv.config.ppm.enabled = TRUE,
    renv.config.ppm.url = ppm_src,
    renv.config.repos.override = c(CRAN = ppm_src),

    # Docker-build stability: avoid pak subprocess integration
    renv.config.pak.enabled = FALSE
  )
}

print_install_opts <- function(opts) {
  codename <- detect_ubuntu_codename()
  message("install opts:")
  message("  Ubuntu codename: ", codename)
  if (!length(opts)) {
    message("  (no options set)")
    return(invisible(NULL))
  }
  message("  Arch:           ", detect_linux_arch())
  message("  R:              ", detect_r_minor())
  message("  CRAN (binary):  ", unname(opts$repos[["CRAN"]]))
  message("  PPM (source):   ", opts$renv.config.ppm.url)
  invisible(NULL)
}

# ---- Global options (parent + children) -------------------------------------

GLOBAL_R_OPTIONS <- make_global_options(target_codename = "noble")
if (length(GLOBAL_R_OPTIONS)) {
  do.call(options, GLOBAL_R_OPTIONS)
}
print_install_opts(GLOBAL_R_OPTIONS)

# ---- callr helper: apply GLOBAL_R_OPTIONS to all children -------------------
# NOTE: we do NOT pass `options=` into callr::r(); some callr versions don't support it.

run_in_callr <- function(expr, child_options = GLOBAL_R_OPTIONS) {
  expr_text <- paste(deparse(substitute(expr), width.cutoff = 500L), collapse = "\n")

  callr::r(
    func = function(expr_text, child_options) {
      if (length(child_options)) do.call(options, child_options)
      eval(parse(text = expr_text), envir = .GlobalEnv)
    },
    args = list(expr_text = expr_text, child_options = child_options),
    show = TRUE
  )
}

# ---- Main -------------------------------------------------------------------

# Install core packages via install.packages() (binaries via PPM repo)
install.packages(
  c("callr", "cli", "renv", "reticulate", "rlang"),
  Ncpus = parallel::detectCores()
)

run_in_callr({
  .python_pyenv_path <- reticulate::install_python("3.12:latest", force = FALSE)

  if (reticulate::virtualenv_exists("./venv")) {
    reticulate::virtualenv_remove(envname = "./venv")
  }

  reticulate::virtualenv_create(
    envname = "./venv",
    python = .python_pyenv_path
  )
})

run_in_callr({
  renv::activate()
})

run_in_callr({
  renv::restore(clean = TRUE)
})

run_in_callr({
  renv::install(
    packages = setdiff(
      c("yaml", "reticulate", "m-pilarski/helprrr"),
      rownames(installed.packages())
    ),
    prompt = FALSE
  )
})

cli::cli_alert_success("renv")

run_in_callr({
  .python_venv_path <- reticulate::virtualenv_python("./venv")
  renv::use_python(.python_venv_path, type = "virtualenv")
  helprrr::setenv_persist(
    RETICULATE_PYTHON = .python_venv_path,
    RENV_PYTHON = .python_venv_path
  )
})

cli::cli_alert_success("venv")

run_in_callr({
  renv::snapshot(prompt = FALSE)
})

cli::cli_alert_success("snapshot")




# set_install_opts <- function() {
#   # robust check for Ubuntu 24.04 codename
#   os_release <- readLines("/etc/os-release", warn = FALSE)
#   codename <- sub("^VERSION_CODENAME=", "", os_release[grepl("^VERSION_CODENAME=", os_release)])
#   if (length(codename) == 1 && codename == "noble") {

#     # Use the *source* P3M endpoint; renv/PPM integration will map to Linux binaries.
#     ppm_src <- "https://packagemanager.posit.co/cran/latest"

#     options(
#       repos = c(CRAN = ppm_src),

#       # renv: prefer PPM/P3M integration (rspm.* is deprecated)
#       renv.config.ppm.enabled = TRUE,
#       renv.config.ppm.default = TRUE,
#       renv.config.ppm.url = ppm_src,

#       # only if you really want to force this repo during restore()
#       renv.config.repos.override = paste0("CRAN=", ppm_src),

#       # pak integration (optional)
#       renv.config.pak.enabled = TRUE
#     )
#   }
# }


# set_install_opts()

# install.packages(c("pak", "callr"))

# pak::pak(pkg = c("cli", "renv", "reticulate", "rlang"))

# run_in_callr <- function(.expr) {
#   expr_quo <- rlang::enquo(.expr)
#   calling_env <- rlang::caller_env()

#   callr::r(
#     function(expr_quo, env_list) {
#       # Reconstruct an environment from a named list
#       e <- list2env(env_list, parent = baseenv())

#       # Evaluate the captured expression in that environment
#       rlang::eval_tidy(expr_quo, data = e)
#     },
#     args = list(
#       expr_quo = expr_quo,
#       env_list = as.list(calling_env, all.names = TRUE)
#     )
#   )
# }

# run_in_callr({
#   .python_pyenv_path <- reticulate::install_python(
#     "3.12:latest",
#     force = FALSE
#   )
#   if (reticulate::virtualenv_exists("./venv")) {
#     reticulate::virtualenv_remove(envname = "./venv")
#   }
#   reticulate::virtualenv_create(
#     envname = "./venv",
#     python = .python_pyenv_path
#   )
# })

# run_in_callr({
#     set_install_opts()
#     renv::activate()
# })

# run_in_callr({
#     set_install_opts()
#     renv::restore(clean = TRUE)
#   })

# run_in_callr({
#     set_install_opts()
#     renv::install(
#       packages = setdiff(
#         c("yaml", "reticulate", "m-pilarski/helprrr", "reticulate"),
#         rownames(installed.packages())
#       ),
#       prompt = FALSE
#     )
#   }
# )

# cli::cli_alert_success("renv")

# run_in_callr({

#     .python_venv_path <- reticulate::virtualenv_python("./venv")
#     renv::use_python(.python_venv_path, type = "virtualenv")
#     helprrr::setenv_persist(
#       RETICULATE_PYTHON = .python_venv_path,
#       RENV_PYTHON = .python_venv_path
#     )
#   }
# )

# cli::cli_alert_success("venv")

# run_in_callr({

#     renv::snapshot(prompt = FALSE)
#   }
# )

# cli::cli_alert_success("snapshot")
