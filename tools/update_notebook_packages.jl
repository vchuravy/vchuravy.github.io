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

# The notebook keeps the Julia version it is updated with, and CI exports it
# with that version if it is one of JULIA_VERSIONS (see export_talks.jl).
ci_versions = let m = match(r"JULIA_VERSIONS: \"([^\"]+)\"", read(".github/workflows/Deploy.yml", String))
    VersionNumber.(split(m[1]))
end
if VersionNumber(VERSION.major, VERSION.minor) ∉ ci_versions
    @warn "CI exports with Julia $(join(ci_versions, ", ")), but this is Julia $(VERSION); these notebooks will run on Julia $(last(ci_versions))"
end

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
