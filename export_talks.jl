# Export the Pluto notebooks in `talks/` to static HTML.
# Usage: julia --project=. export_talks.jl
#
# Environment variables:
#   PLUTO_PARALLEL_TASKS   number of notebooks to run at once (default: physical cores)
#   BENCHMARK_SECONDS      BenchmarkTools time budget per benchmark (default: 0.5)
#   BENCHMARK_SAMPLES      BenchmarkTools maximum number of samples (default: 100)

import PlutoSliderServer

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

PlutoSliderServer.export_directory(
    "talks";
    Export_cache_dir="pluto_state_cache",
    Export_baked_notebookfile=false,
    Export_number_of_parallel_tasks=parallel_tasks,
    # `talks/foo.jl` is exported to `talks/foo/`, which also gets a copy of
    # `foo.jl`; skip those copies when re-running in a dirty tree.
    Export_exclude=["*/*"],
    Pluto_evaluation_workspace_custom_startup_expr=startup_expr,
)
