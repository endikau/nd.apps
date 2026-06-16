# scripts/setup_envs.R

install.packages(
  pkgs = c("renv", "reticulate"),
  repos = "https://packagemanager.posit.co/cran/latest",  
  Ncpus = parallel::detectCores()
)

lockfile <- renv::lockfile_read("renv.lock")

python_version <- lockfile[["Python"]][["Version"]]
python_type <- lockfile[["Python"]][["Type"]]
python_name <- lockfile[["Python"]][["Name"]]

if(!is.null(python_version)){
  python_exe <- reticulate::install_python(version = python_version)
}

if(python_type == "virtualenv"){
  if(reticulate::virtualenv_exists(python_name)){
    reticulate::virtualenv_remove(python_name, confirm = FALSE)
  }
  python_env <- reticulate::virtualenv_create(
    envname = python_name, 
    python = python_exe
  )
  python_exe <- reticulate::virtualenv_python(envname = python_env)
  renv::use_python(python = python_exe, type = "virtualenv")
}else{
  stop("not a virtualenv")
}

renv::restore(clean = TRUE, prompt = FALSE)
