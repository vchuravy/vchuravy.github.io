# Adapted from the 2025-rse-course repository.
if !isdir("talks") || isempty(ARGS)
    error("""
    Run me from the root of the repository directory, using:

    julia --project=. tools/update_notebook_packages.jl <level> [notebook...]

    Where <level> is one of: PATCH, MINOR, MAJOR, FIXED.
    A notebook is a talk name (`foo` for `talks/foo.jl`) or a path
    (`notes/2024/01/foo.jl`). Without notebooks, all notebooks in `talks/`
    and `notes/` are updated.
    """)
end

import Pkg
Pkg.instantiate()

# The notebooks are exported with the Julia version they are updated with
# (see export_notebooks.jl), so run this with the Julia version you want them on,
# e.g. `julia +1.12 --project=. tools/update_notebook_packages.jl MINOR foo`.
@info "Updating notebook environments for Julia $(VERSION)"

import Pluto

level = getfield(Pkg, Symbol("UPLEVEL_$(ARGS[1])"))

notebooks = if length(ARGS) > 1
    map(ARGS[2:end]) do n
        endswith(n, ".jl") || (n *= ".jl")
        isfile(n) ? n : joinpath("talks", n)
    end
else
    all_files = [joinpath(root, f) for dir in ("talks", "notes") for (root, _, files) in walkdir(dir) for f in files]
    # Skip the copies inside exported notebook directories (`talks/foo/foo.jl`).
    filter(all_files) do f
        Pluto.is_pluto_notebook(f) && basename(dirname(f)) != splitext(basename(f))[1]
    end
end

for n in notebooks
    @info "Updating" n
    Pluto.update_notebook_environment(n; backup=false, level)
end
