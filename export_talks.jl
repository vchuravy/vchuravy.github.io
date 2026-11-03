# Export the Pluto notebooks in `talks/` to static HTML.
# Usage: julia --project=. export_talks.jl
#
# Pluto runs notebooks with the Julia version of the export process, so each
# notebook is exported with the Julia version its embedded manifest was made
# with: this script groups the notebooks by that version, installs the
# versions with juliaup, and runs one export per version.
#
# - Notebooks without a manifest use DEFAULT_JULIA.
# - Notebooks made with a Julia older than MIN_JULIA (the oldest that Pluto 1
#   supports) use MIN_JULIA.
# - If juliaup cannot install a version (e.g. an unreleased one), the
#   notebook uses DEFAULT_JULIA.
#
# Environment variables:
#   PLUTO_PARALLEL_TASKS   number of notebooks to run at once (default: physical cores)
#   BENCHMARK_SECONDS      BenchmarkTools time budget per benchmark (default: 0.5)
#   BENCHMARK_SAMPLES      BenchmarkTools maximum number of samples (default: 100)

# Everything lives in a module: Pluto evaluates code in `Main` of this process.
module ExportTalks

# Set by `export_all` for the per-version export processes.
const CHILD = haskey(ENV, "EXPORT_TALKS_NOTEBOOKS")
if CHILD
    import PlutoSliderServer, JSON
end

const MIN_JULIA = v"1.10"
const DEFAULT_JULIA = v"1.11"

minor(v::VersionNumber) = VersionNumber(v.major, v.minor)
channel(v::VersionNumber) = "$(v.major).$(v.minor)"

function export_notebooks(notebooks)
    this_version = minor(VERSION)
    @info "Exporting with Julia $(VERSION)" notebooks

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

    # Each export rewrites `talks/pluto_export.json` with only its own
    # notebooks, so keep the entries of the other Julia versions.
    index_path = joinpath("talks", "pluto_export.json")
    previous_index = isfile(index_path) ? JSON.parsefile(index_path) : nothing

    PlutoSliderServer.export_directory(
        "talks";
        notebook_paths=notebooks,
        Export_cache_dir=joinpath("pluto_state_cache", channel(this_version)),
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
end

function notebook_julia_version(path)
    m = match(r"^julia_version = \"([^\"]+)\""m, read(path, String))
    m === nothing && return DEFAULT_JULIA
    return max(minor(VersionNumber(m[1])), MIN_JULIA)
end

julia_cmd(v) = `julia +$(channel(v))`

# Whether `julia +x.y` works, installing the channel with juliaup if needed.
function ensure_julia(v)
    works() = success(pipeline(`$(julia_cmd(v)) --startup-file=no -e 'exit()'`; stdout=devnull, stderr=devnull))
    works() && return true
    success(`juliaup add $(channel(v))`) && works()
end

function export_all()
    groups = Dict{VersionNumber,Vector{String}}()
    for f in readdir("talks")
        endswith(f, ".jl") || continue
        v = notebook_julia_version(joinpath("talks", f))
        if v != DEFAULT_JULIA && !ensure_julia(v)
            @warn "Cannot install Julia $(channel(v)), exporting $f with Julia $(channel(DEFAULT_JULIA))"
            v = DEFAULT_JULIA
        end
        push!(get!(groups, v, String[]), f)
    end
    ensure_julia(DEFAULT_JULIA) || error("Cannot install Julia $(channel(DEFAULT_JULIA))")

    for v in sort!(collect(keys(groups)))
        julia = julia_cmd(v)
        run(`$julia --project=. -e 'import Pkg; Pkg.instantiate()'`)
        run(addenv(`$julia --project=. $(PROGRAM_FILE)`, "EXPORT_TALKS_NOTEBOOKS" => join(groups[v], "\n")))
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
end

function main()
    if CHILD
        export_notebooks(String.(split(ENV["EXPORT_TALKS_NOTEBOOKS"], "\n")))
    else
        export_all()
    end
end

end # module

ExportTalks.main()
