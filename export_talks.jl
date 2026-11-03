# Export the Pluto notebooks in `talks/` to static HTML.
# Usage: julia --project=. export_talks.jl
#
# Pluto runs notebooks with the Julia version of the export process. To keep
# a notebook on an older Julia, run this script once per Julia version: each
# run exports the notebooks whose embedded manifest was made with the running
# Julia version, and the default version also exports all other notebooks.
#
# Environment variables:
#   JULIA_VERSIONS         Julia versions CI exports with (default: "1.10 1.11")
#   DEFAULT_JULIA_VERSION  version for all other notebooks (default: last of JULIA_VERSIONS)
#   PLUTO_PARALLEL_TASKS   number of notebooks to run at once (default: physical cores)
#   BENCHMARK_SECONDS      BenchmarkTools time budget per benchmark (default: 0.5)
#   BENCHMARK_SAMPLES      BenchmarkTools maximum number of samples (default: 100)

import PlutoSliderServer
import JSON

minor(v::VersionNumber) = VersionNumber(v.major, v.minor)

julia_versions = VersionNumber.(split(get(ENV, "JULIA_VERSIONS", "1.10 1.11")))
default_version = VersionNumber(get(ENV, "DEFAULT_JULIA_VERSION", string(last(julia_versions))))
this_version = minor(VERSION)
this_version in julia_versions ||
    error("Julia $(VERSION) is not one of JULIA_VERSIONS = $(julia_versions)")

function notebook_julia_version(path)
    m = match(r"^julia_version = \"([^\"]+)\""m, read(path, String))
    m === nothing && return default_version
    v = minor(VersionNumber(m[1]))
    return v in julia_versions ? v : default_version
end

notebooks = filter(readdir("talks")) do f
    endswith(f, ".jl") && notebook_julia_version(joinpath("talks", f)) == this_version
end
@info "Exporting with Julia $(this_version)" notebooks

parallel_tasks = let n = get(ENV, "PLUTO_PARALLEL_TASKS", "")
    isempty(n) ? nothing : parse(Int, n)
end
benchmark_seconds = parse(Float64, get(ENV, "BENCHMARK_SECONDS", "0.5"))
benchmark_samples = parse(Int, get(ENV, "BENCHMARK_SAMPLES", "100"))

# Runs in every notebook process before the notebook code. Lowers the
# BenchmarkTools defaults as soon as a notebook loads the package; benchmarks
# that pass `seconds=`/`samples=` explicitly keep their own values.
startup_expr = """
push!(Base.package_callbacks, function (pkg)
    pkg.name == "BenchmarkTools" || return
    params = Base.loaded_modules[pkg].DEFAULT_PARAMETERS
    params.seconds = $(benchmark_seconds)
    params.samples = $(benchmark_samples)
end)
"""

# Each run rewrites `talks/pluto_export.json` with only its own notebooks, so
# keep the entries of the other runs.
index_path = joinpath("talks", "pluto_export.json")
previous_index = isfile(index_path) ? JSON.parsefile(index_path) : nothing

PlutoSliderServer.export_directory(
    "talks";
    notebook_paths=notebooks,
    Export_cache_dir=joinpath("pluto_state_cache", "$(this_version.major).$(this_version.minor)"),
    Export_baked_notebookfile=false,
    Export_number_of_parallel_tasks=parallel_tasks,
    Pluto_evaluation_workspace_custom_startup_expr=startup_expr,
)

if previous_index !== nothing
    index = JSON.parsefile(index_path)
    for (path, entry) in previous_index["notebooks"]
        if !haskey(index["notebooks"], path) && isfile(joinpath("talks", path))
            index["notebooks"][path] = entry
        end
    end
    write(index_path, JSON.json(index))
end

# Add the citation meta tags and the "Cite this talk" box to every exported
# notebook. Franklin expands `{{citetalk_meta}}` and `{{citetalk}}` (see
# `utils.jl`) when it copies the HTML into `__site`.
for dir in readdir("talks"; join=true)
    html = joinpath(dir, "index.html")
    isfile(html) && isfile(dir * ".jl") || continue
    s = read(html, String)
    occursin("{{citetalk}}", s) && continue
    s = replace(s, "</head>" => "{{citetalk_meta}}</head>"; count=1)
    i = findlast("</body>", s)
    i === nothing || (s = s[1:prevind(s, first(i))] * "{{citetalk}}" * s[first(i):end])
    write(html, s)
end
