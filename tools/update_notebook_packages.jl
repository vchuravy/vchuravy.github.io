# Adapted from the 2025-rse-course repository.
if !isdir("talks") || isempty(ARGS)
    error("""
    Run me from the root of the repository directory, using:

    julia --project=. tools/update_notebook_packages.jl <level> [notebook...]

    Where <level> is one of: PATCH, MINOR, MAJOR, FIXED.
    Without notebook names, all notebooks in `talks/` are updated.
    """)
end

import Pkg
Pkg.instantiate()

# The notebooks are exported with the Julia version they are updated with
# (see export_talks.jl), so run this with the Julia version you want them on,
# e.g. `julia +1.12 --project=. tools/update_notebook_packages.jl MINOR foo`.
@info "Updating notebook environments for Julia $(VERSION)"

import Pluto

level = getfield(Pkg, Symbol("UPLEVEL_$(ARGS[1])"))

notebooks = if length(ARGS) > 1
    map(ARGS[2:end]) do n
        endswith(n, ".jl") || (n *= ".jl")
        joinpath("talks", basename(n))
    end
else
    filter(Pluto.is_pluto_notebook, readdir("talks"; join=true))
end

for n in notebooks
    @info "Updating" n
    Pluto.update_notebook_environment(n; backup=false, level)
end
