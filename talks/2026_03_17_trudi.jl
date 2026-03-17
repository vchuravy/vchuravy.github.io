### A Pluto.jl notebook ###
# v0.20.24

#> [frontmatter]
#> title = "Performance Analysis with Julia for Trixi.jl "
#> date = "2026-03-17"
#> tags = ["module1", "track_performance"]
#> License = "MIT"
#> 
#>     [[frontmatter.author]]
#>     name = "Valentin Churavy"
#>     url = "https://vchuravy.dev"

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    return quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

# ╔═╡ 25935904-4644-4ce2-83e9-d08c22b5e40d
using PlutoUI, PlutoTeachingTools

# ╔═╡ b238fccf-56a8-47a9-950f-b1bfedf3bbd8
using BenchmarkTools

# ╔═╡ bef23b0e-fd7f-4fab-aec7-de0e38a5b847
using Profile

# ╔═╡ c48f8d56-a11c-4e94-b98f-b44c4516b0af
using ProfileCanvas

# ╔═╡ 054e1fe2-fc02-4b05-a3db-30f09fe1e7ff
begin
	using Trixi
	using OrdinaryDiffEqLowStorageRK
end

# ╔═╡ 203a1ab2-caaa-4530-8b30-fc4d522019b1
using PProf

# ╔═╡ 06e23433-30df-467c-8c8c-2d3bc115a24d
using ThreadPinning

# ╔═╡ a01059d0-67ec-4cf7-9d36-3049145ffc39
using CpuId

# ╔═╡ 74428e50-7739-4d92-84bf-f7e355c63128
using LinuxPerf

# ╔═╡ 9a210aff-9ca5-4df3-a197-9aaf372951eb
using LIKWID

# ╔═╡ 4203bd1f-61e4-401f-8c5b-e4c4b3c1d95b
using IntelITT

# ╔═╡ 8e24417d-8e8c-41ec-b2c7-0a19b518e1c4
using Serialization

# ╔═╡ 9a083aa8-d7df-479a-9b3c-6d83812d7930
using TimerOutputs

# ╔═╡ 2902eb1a-442e-4a75-a6bd-3fb498c5ddf6
using Base.Threads: @threads

# ╔═╡ f08a7392-5f7e-45f8-a713-adb51eb43a7e
using CairoMakie

# ╔═╡ 644724b7-5104-460d-ace9-93432e41fe2e
using About

# ╔═╡ 820eef38-86d2-4b03-8989-0dc4d4c86929
ChooseDisplayMode()

# ╔═╡ 2aeda4bd-aa1c-46fc-8183-79f8c75e5172
PlutoUI.TableOfContents(; depth=4)

# ╔═╡ 97f862e8-268b-4bff-8bdc-842aecffc2f1
html"""
<h1> Performance Analysis with Julia for Trixi.jl </h1>

<div style="text-align: center;">
March 17th 2026 <br>
<br><br>
Valentin Churavy
<br><br>
High Performance Scientific Computing, University of Augsburg <br>
Numerical Mathematics, University of Mainz 
<br><br>
@vchuravy
</div>

 <table>
        <tr>
<td><img src="https://upload.wikimedia.org/wikipedia/commons/e/e9/Universit%C3%A4t_Augsburg_logo.svg" width=100px></td>

<td><img src="https://upload.wikimedia.org/wikipedia/commons/8/8a/Johannes_Gutenberg-Universit%C3%A4t_Mainz_logo.svg" width=200px></td>
        </tr>
</table>
"""

# ╔═╡ 5c4c21e4-1a90-11f0-2f05-47d877772576
md"""
# Performance Engineering
"""

# ╔═╡ f3108f38-2bb4-4af7-b864-1805bb3cbef5
md"""
#### Goals:

1. Understanding the performance characteristics of your program
    - What is the hot-path
    - Where is time being spent
2. Define metrics
    - Benchmarks allow us to understand "is a change good"
3. How does my program get executed?
    - Language of choice?
    - Compilation
    - Hardware architecture
"""

# ╔═╡ f11fb041-4587-4dc2-b201-5a5b27a32dff
TwoColumn(
md"""
**Benchmarking**
- Focusing on the "hot-loop"
- Allows for comparision
  - Different algorithms
  - Different hardware
""",
md"""
**Profiling**
- Analyse where time is being spent
- Many tools with different trade-offs
- Different perspectives
  - Language profiler
  - System profiler
""")

# ╔═╡ 4040ca9a-acbe-40fe-9a81-95996c4b64b2
md"""
## Benchmarking
"""

# ╔═╡ 4f60569e-a86b-4488-ac35-1554ae2b79ea
md"""
!!! note
    **Premature optimization is the root of all evil & If you don't measure you won't improve**
"""

# ╔═╡ 68ae253d-2a29-44e0-b217-98c3c1b5bc60
md"""
### BenchmarkTools.jl

Solid package that tries to eliminate common pitfalls in performance measurment.

- `@benchmark` macro that will repeatedly evaluate your code to gain enough samples
- Caveat: You probably want to escape $ your input data
"""

# ╔═╡ c37a3eda-4ce4-4ad3-8011-4c4c6376775d
@bind N PlutoUI.Slider(5:12)

# ╔═╡ be74fa8a-21d6-4ee0-814c-bbaea5904934
md"""
N=$N
"""

# ╔═╡ 56f31a4a-8bea-4738-9c38-9630a67fb4e6
data = rand(10^N);

# ╔═╡ 71f5f0a0-b472-48e8-ad8f-1a2b515d81fe
function sum(X)
    acc = 0
    for x in X
        acc += x
    end
    acc
end

# ╔═╡ 93756400-7346-4fa0-ad5e-06591a6cd8d8
@elapsed sum(data) # Huh! Is pluto lying to us

# ╔═╡ 317f1ca5-5d8e-4820-abbf-682464866bcb
@belapsed sum(data) samples=10 evals=3

# ╔═╡ 066f84af-45ef-4ff7-9016-d4e2f95d42d1
@benchmark sum(data) samples=10 evals=3

# ╔═╡ 80ef7628-0f17-48d2-9bcf-21e3e3985455
md"""
!!! note
    We will talk about the Julia compiler in detail in a future lecture. One important thing to know, that Julia performs type-inference based on the argument types, and **quality** of type-inference determines performance characteristics.
"""

# ╔═╡ 7838acb6-3786-44ad-ae40-b78d252d59a8
md"""
```julia
function sum(X::Vector{Float64})
    acc = 0::Int64
    for x in X
        (acc += x)::Float64
    end
    acc::Union{Int64, Float64}
end
```
"""

# ╔═╡ 948f8590-9a26-4b26-998d-ac0c8f5c50f4
md"""
### Caveats of micro-benchmarking

BenchmarkTools tries to approximate a function execution a top-level.
It thus measures the cost of accessing global variables.

Use the interpolation syntax `$` to avoid that cost for very cheap functions.
"""

# ╔═╡ 492c4348-0b0d-4e52-a4c9-d80283f7bc98
begin
	a = 3.0
	b = 4.0
end

# ╔═╡ dde9da1d-a6b1-4ca9-b8d4-f9a164b089cb
@benchmark sin(a) + b

# ╔═╡ 7c31dec3-dcf8-4366-96c8-98bd9d426faf
@benchmark sin($a) + b

# ╔═╡ 8a01f348-9e96-448f-97b3-b193c5f7a36a
@benchmark sin($a) + $b

# ╔═╡ 0115a2f6-ae33-45e3-bebf-924f7c3e8e05
md"""
!!! warning
	Did we get to fast?
"""

# ╔═╡ 3eb69d4f-5d7b-4b08-b274-f51f7c33970a
code_typed() do
	sin(3.0) + 4.0
end |> only

# ╔═╡ f953aace-06b6-4101-924c-3218140fc09a
md"""
Julia can constant-fold expressions.
"""

# ╔═╡ 1255bdf3-a32f-45e9-b589-2da4883d775b
@benchmark sin($Ref(a)[]) + $Ref(b)[]

# ╔═╡ 5c8c666a-8a8b-4f37-8bde-3a29b75c9c43
md"""
!!! warning
	Be careful with benchmarks whose time doesn't change with an increase in complexity! Likely that the compiler got clever and turned it into a constant time expression or constant folded it.
"""

# ╔═╡ 68d0783c-6651-4432-bdbc-3be4d3f6ea65
function count(N)
    acc = 0
    for i in 1:N
        acc += 1
    end
    return acc
end

# ╔═╡ 89b11df3-7a2f-463f-954a-f7f6c137af8d
@benchmark count(10)

# ╔═╡ 6db6a364-60af-4afc-bdcf-3f2f29e5aaa7
@benchmark count(1000000)

# ╔═╡ 8ac7e33b-2279-4b3b-9c44-9cc7bdb4d256
md"""
!!! warning
    How would you benchmark `sort!`?
"""

# ╔═╡ e03e9d1c-0d1c-4bbc-848e-0fd81ddd5e8a
let
	v = rand(Int, 1024)
	@benchmark sort!($v)
end

# ╔═╡ 8ef05b61-e2ce-4b9f-a42c-f7f2dc664852
md"""
`sort!` is mutating its input. Therefore we need to set `evals=1` and provide a `setup` to re-initialize the data everytime
"""

# ╔═╡ 9790f509-046b-4714-bfba-b77019c806ae
@benchmark sort!(v) setup=(v = rand(Int, 1024)) evals=1

# ╔═╡ 3e717bde-a8d7-41b3-a52e-694efd22ff38
md"""
### Sources of noise

Computers are noisy systems. The operating system manages resources and distribute them to programs.

1. Heat
    - The temperature of your processor influences the frequency it is targetting
    - When benchmarking a function may be faster in the beginning and slower afterwards
2. Other programs
    - The OS is splitting the CPU time into slices
    - So a program may be descheduled 
3. Input-Output (IO)
    - Disk/Network access is variable
    - The OS will also put you to sleep, when waiting for data
4. The CPU
    - CPU are "learning"/"predicitive" systems. See https://discourse.julialang.org/t/psa-microbenchmarks-remember-branch-history/17436
"""

# ╔═╡ e8dd5d43-7a39-4f4c-9465-a25ad4dae287
md"""
## Profiling
"""

# ╔═╡ 14b79b92-6ff8-476f-b403-63c797d99567
md"""
Most profilers we will use are **stochastic** profilers. They sample the running program at a fixed interval. Julia uses a default of `0.001s` and it also uses a fixed size buffer. See `Profile.init`.

!!! note
    Sampling artifacts can occur when profiling multi-threaded applications. During a sample the thread we are sampling from is paused. If the thread is in a critical section this may introduce artifacts. 
"""

# ╔═╡ 7e51fbab-eea5-4d05-82fd-44d37e91e9b7
Profile.init()

# ╔═╡ ac46f42b-ec7d-46d3-a4ad-d5c887a93327
md"""
- [Profiler](https://docs.julialang.org/en/latest/manual/profile/)
- [ProfileView.jl](https://github.com/timholy/ProfileView.jl)
- [ProfileCanvas.jl](https://github.com/pfitzseb/ProfileCanvas.jl)
- [PProf.jl](https://github.com/JuliaPerf/PProf.jl)
"""

# ╔═╡ ad5f2707-572a-4245-ba52-078c67f1b17f
md"""
The Julia profiler focuses on the execution of Julia code. This leads to two limitations:

1. By default it does not show time spent in C functions
2. It does not measure time spent on "external" threads
  - BLAS threads
  - GC worker threads
"""

# ╔═╡ 3f02c140-c408-4f0c-9d73-5348d2b4af4d
function profile_test(n)
    for i = 1:n
        A = randn(100,100,20)
        m = maximum(A)
        Am = mapslices(sum, A; dims=2)
        B = A[:,:,5]
        Bsort = mapslices(sort, B; dims=1)
        b = rand(100)
        C = B.*b
    end
end

# ╔═╡ 9840f078-63ff-4efc-9d45-6e0198d2624d
@profview profile_test(1);  # run once to trigger compilation (ignore this one)

# ╔═╡ 36762f71-e535-4048-ac68-ea1fc6859de1
@profview profile_test(10)

# ╔═╡ 9b28e25b-493a-4e74-bc44-e996f639b8d1
md"""
!!! note
    The profiler shows all Julia worker-threads. The time spent in `task_done_hook` is a worker thread idiling.
"""

# ╔═╡ 43abf4bc-d98d-4162-9cb5-2f531ffb7fb4
function pfib(n::Int)
    if n <= 1
        return n
    end
    t = Threads.@spawn pfib(n-2)
    return pfib(n-1) + fetch(t)::Int
end

# ╔═╡ 74ae8f13-c09d-4e51-ba56-e5b230e13f1f
function profile_pfib(n, k)
    for i = 1:n
        pfib(k)
    end
end

# ╔═╡ acd1a03d-1114-44e3-a970-3f418539d2db
@profview profile_pfib(1, 4);

# ╔═╡ 84973c7a-2d17-49c3-b627-a804dcefd35b
@profview profile_pfib(10, 16)

# ╔═╡ 03fed1dd-004c-4fba-8ce3-7625f1c25820
md"""
To gain insight into runtime behavior we can turn on C-frames
"""

# ╔═╡ 9d058445-37e5-4201-b7f2-c658125bc126
@profview profile_pfib(10, 16) C=true

# ╔═╡ 5bdf8023-ce43-44e2-beff-229ff6455d84
md"""
Runtime functions you might see:

- `jl_gc_*_alloc`: Memory allocations
- `jl_gc_collect`: Garbage collection
- `jl_safepoint_wait_gc`: Garbage collection waiting for all threads to reach it.
"""

# ╔═╡ 0c145a21-ec7e-4509-9b1d-8844a89f65aa
md"""
## Example: Trixi
"""

# ╔═╡ 55167a98-2dd4-4751-a4cf-7bdce3032bb1
trixi_include(@__MODULE__, joinpath(examples_dir(), "tree_2d_dgsem", "elixir_advection_basic.jl"), sol = nothing);

# ╔═╡ 194c38a6-4256-4f1d-861c-07700442b0ea
with_terminal() do
	solve(ode, CarpenterKennedy2N54(williamson_condition = false);
          dt = 1.0, ode_default_options()..., 
		  callback = CallbackSet(stepsize_callback))
	summary_callback()
end

# ╔═╡ 866bcf04-f70d-4c5d-91b9-fa59e54f14c6
@profview begin 
	solve(ode, CarpenterKennedy2N54(williamson_condition = false);
          dt = 1.0, ode_default_options()...,
		  callback = CallbackSet(stepsize_callback))
end C=true

# ╔═╡ ed204cae-226f-423d-b056-a02bb25664d0
md"""
!!! note
    Polyester makes our profiles hard to read...

!!! warning
    Profiling a multi-threaded application from within leads to biases...
"""

# ╔═╡ d732846e-8c4d-4243-b886-4dde461da524
md"""
### PProf
"""

# ╔═╡ 1709a94e-5bc6-4c57-ae03-e48b14ef7c5a
@pprof begin
	solve(ode, CarpenterKennedy2N54(williamson_condition = false);
          dt = 1.0, ode_default_options()...,
		  callback = CallbackSet(stepsize_callback))
end

# ╔═╡ 801a3777-6bd0-439a-977a-5ded24b68825
PProf.refresh()

# ╔═╡ 2897d2e7-58d8-42ce-b0cd-22c206b94e25
 html"""
<embed type="text/html" src="http://localhost:57599" width="800" height="400"> 
"""

# ╔═╡ ea252115-6131-4cf5-ad03-dc8bfea1c392
md"""
!!! note "Sharing profiles"
    - [flamegraph.com](https://flamegraph.com)
    - [pprof.me](https://pprof.me)
"""

# ╔═╡ fa5243df-79a9-4e36-a14a-18d20babbd08
md"""
### Native profilers
"""

# ╔═╡ faf4b6b2-e191-4af1-9527-c8cb3e9f6e71
md"""
System profilers allow you to gain even more insight into how your program is performing, but come with usability down-sides.
"""

# ╔═╡ 898ad034-31b8-4ef5-a58e-06757a6d34cb
md"""
- [VTune](https://github.com/JuliaPerf/IntelITT.jl?tab=readme-ov-file#running-julia-under-vtune)
- [Perf](https://docs.julialang.org/en/v1/manual/profile/#External-Profiling)
- [NSight Systems](https://cuda.juliagpu.org/stable/development/profiling/#External-profilers)
  - `CUDA.jl` has it's own inbuilt `@profile`
"""

# ╔═╡ a8098f14-c792-441d-817d-e4bc1124fd55
md"""
!!! note
    Set the environment variable `ENABLE_JITPROFILING=1`, when using `perf` or `VTune`.
"""

# ╔═╡ 88bc8fac-06e1-45cc-86e7-dee875bd0e78
md"""
## Aside: ThreadPinning.jl
"""

# ╔═╡ 947272bd-1fbb-4eb3-8775-967b4dae9df2
begin 
	ThreadPinning.pinthreads(:cores)
	marker_tp = nothing
end;

# ╔═╡ 386da2f5-3285-494f-baaa-86f139bdf3a6
with_terminal() do
	marker_tp
	ThreadPinning.threadinfo()
end

# ╔═╡ 3edd3985-e3b1-4a5a-90d1-647f3c42a000
cpuinfo()

# ╔═╡ 63fc1a79-8c7c-47b2-8926-cdaf965f063e
Sys.CPU_NAME

# ╔═╡ 8799a9ce-1c36-4fb3-a038-a9c259abb5bc
md"""
### Example: axpy
"""

# ╔═╡ 4fce5337-e204-4fa4-95eb-4bc1e31b54d1
function axpy!(z, a, x, y)
	for idx in eachindex(z, x, y)
		z[idx] = a * x[idx] + y[idx]
	end
end

# ╔═╡ 652ccd92-71ee-427d-b21e-fec27640e99e
md"""T = $(@bind T Select([Float32, Float64]))"""

# ╔═╡ 8e52812b-7b8c-4e69-ae11-04e1b6da4b85
let
	range = trunc.(Int, exp10.(0:0.2:5))
	md"M = $(@bind M PlutoUI.Slider(range, default=10_000, show_value=true))"
end

# ╔═╡ 4f5bfc23-252d-46a2-8eac-ec4446cc915b
begin
	A = T(pi)
	X = rand(T, M);
	Y = rand(T, M);
	Z = zeros(T, M);
end;

# ╔═╡ 29384daa-5276-4a2d-81d5-578749335a75
@benchmark axpy!(Z, A, X, Y)

# ╔═╡ 6182daf1-5332-4b68-a9a5-1ae0c9a39882
md"""
## Perf & LinuxPerf.jl
"""

# ╔═╡ 50499b7e-4ff9-4279-ab02-214e857c3d55
md"""
!!! note
    Linux-only, command line only top. Supported by GUI application with `hotspot`
"""

# ╔═╡ d39720df-ab2e-440e-861b-be0b09859477
md"""
!!! warning
    Local example
"""

# ╔═╡ 6a3f8b13-990a-48ba-8bb5-1132b819c0fa
md"""
```sh
ENABLE_JITPROFILING=1 perf record --call-graph dwarf -k 1 /home/vchuravy/.julia/juliaup/julia-1.11.9+0.x64.linux.gnu/bin/julia --threads=auto --project=. profile.jl
```

```sh
perf inject --jit --input perf.data --output perf.jit.data
```

```
perf report -i perf.jit.data
```
"""

# ╔═╡ b10de1e6-653c-4c12-b7d5-a4980e010ce7
md"""We can also access Linux's [`perf`](https://perf.wiki.kernel.org/index.php/Main_Page) performance counters via [`LinuxPerf.jl`](https://github.com/JuliaPerf/LinuxPerf.jl)."""

# ╔═╡ 11c0a32b-2b01-429f-af5d-adddd56a2963
@measure axpy!(Z, A, X, Y)

# ╔═╡ 9446cf71-0dd9-4aaf-9f93-5fc80ac8176d
perf_events = "(cache-references,cache-misses)";

# ╔═╡ fb395623-26e6-4d4f-a418-136ab2fdb6b0
@pstats perf_events axpy!(Z, A, X, Y)

# ╔═╡ a83e3be5-e97a-4945-8c97-1e8ddfa80917
md"""
## LIKWID 
"""

# ╔═╡ 8e2aa324-0a75-4b7c-beb8-a689d72315a0
perf_group = T==Float32 ? "FLOPS_SP" : "FLOPS_DP";

# ╔═╡ 1dd35fb1-87e5-4fe5-af95-25ba71560e4a
metrics, events = @perfmon perf_group axpy!(Z, A, X, Y)

# ╔═╡ bcd3aa5c-f42c-4300-bdee-67a6e4154497
first(metrics[perf_group])

# ╔═╡ 177940b1-781b-43e2-a300-091c00313b6f
N_FLOPs = first(events[perf_group])["RETIRED_SSE_AVX_FLOPS_ALL"]

# ╔═╡ 85978b71-25df-4aa1-93d1-4a236b6f2110
N_FLOPs_per_iteration = N_FLOPs / N

# ╔═╡ 3db655ff-4d88-4165-a8ec-e49141bd6d7e
md"""
!!! note "Exercise"
	[Interactive performance tuning with Julia](https://vchuravy.dev/rse-course/mod3_parallelism/interactive_tuning/)
"""

# ╔═╡ b5231b36-ac16-4451-aba8-bb31652e903e
md"""
## Aside: LLVM & Vectorizer
"""

# ╔═╡ 59913f9e-3a75-4a98-b7e0-2d4702453f48
md"""
!!! note "LLVM remarks"
    `JULIA_LLVM_ARGS="--pass-remarks-analysis=loop-vectorize"`
"""

# ╔═╡ a08e1c6f-14d4-4d50-ad4f-9682e0780af8
md"""
!!! warning "More information on the Julia Compiler"
    - [RSE Course: Compilers](https://vchuravy.dev/rse-course/mod5_performance_engineering/compilers/)
    - [A random walk through Julia's compiler ](https://vchuravy.dev/talks/2026_03_05_LLVM-Berlin/)
"""

# ╔═╡ 37ee5ec0-7264-49de-96ac-948fbafbf0e1
md"""
## VTunes
""" 

# ╔═╡ d611bde5-5c88-4069-975c-92f2d1f354f1
INTEL_PATH = "/opt/intel/oneapi-manual/vtune/2025.6/bin64"

# ╔═╡ 4e8037ea-3aab-424a-b0be-f4e7b1e048ac
VTUNE = `$INTEL_PATH/vtune`

# ╔═╡ 93b8c0d7-d7f9-4d53-9209-fe21d3113aef
DEFAULT = `hotspots`

# ╔═╡ d483b892-e4db-4207-b427-284d024fa7a8
macro vtune(expr)
	path = mktempdir()
	script = path * "script.jl"
	control_io_path = path * "data.ji"
	
	io = open(script, "w")
	println(io, "using Serialization")
	println(io, "__val = begin")
	println(io, expr)
	println(io, "end")
	println(io, """
	Serialization.serialize("$control_io_path", __val)
	""")
	close(io)
	quote
		let
			path = $path
			script = $script
			cmd = `$(VTUNE) --user-data-dir=$path -q -collect $(DEFAULT) -- $(Base.julia_cmd()) --project=$(Base.active_project()) $(script)`
			cmd = addenv(cmd, "ENABLE_JITPROFILING" => "1")
			run(cmd)
		end
		v = Serialization.deserialize($control_io_path)
		rm($control_io_path)
		# let
		# 	path = $path
		# 	script = $script
		# 	cmd = `$(VTUNE) --user-data-dir=$path -q -report hotspots`
		# 	run(cmd)
		# end
		v
	end
end

# ╔═╡ 14bc747c-3bf8-4831-a7ea-dda24200ff0d
@vtune let
	using InteractiveUtils
	peakflops()
end

# ╔═╡ 08e3642e-8e06-4906-b235-1b31bdc1eb42
with_terminal() do
	@code_warntype sum(data)
end

# ╔═╡ 5b702c30-d19a-4391-99ba-cc1b0173c1ad
with_terminal() do
	@code_llvm debuginfo=:none axpy!(Z, A, X, Y)
end

# ╔═╡ 1a6d3e16-753f-47b5-9e05-6405dfd6dfa0
md"""
!!! warning
    Local example
"""

# ╔═╡ 49fb6e38-b545-466f-aa84-fcf41e3c1607
md"""
## Nsight 

!!! note "CUDA.@profile"
    Nvidia Nsight-sys and Nsight-compute are both very useful and powerful, but as a first approximation `CUDA.@profile` can give us insights into a JuliaGPU application.

    [https://colab.research.google.com/drive/10CtFsiPosUipDcFXCMFO3O_szp7wDNZR?usp=sharing](https://colab.research.google.com/drive/10CtFsiPosUipDcFXCMFO3O_szp7wDNZR?usp=sharing)
"""

# ╔═╡ 978f5dfa-ad45-4982-b451-d4afbd430530
md"""
### Instrumentation

It can be hard to correlate profiles with our programs, instrumentation makes it easier to define semantically important portions.

- [TimerOutputs](https://github.com/KristofferC/TimerOutputs.jl)
- [NVTX](https://github.com/JuliaGPU/NVTX.jl)
- [Tracy](https://github.com/topolarity/Tracy.jl)
- [IntelITT.jl](https://github.com/JuliaPerf/IntelITT.j)

!!! warning "Open question"
    How to I integrate all these different instrumentation choices into one that I can use across multiple profilers.

"""

# ╔═╡ 876c2320-c6bf-4a71-9c17-d16bd4868b7e
const to = TimerOutput();

# ╔═╡ d5e28e66-b609-44c0-8fc1-7a15d2034be2
@timeit to function prefix_threads!(⊕, y::AbstractVector)
	l = length(y)
	k = ceil(Int, log2(l))
	# do reduce phase
	@timeit to "reduce" for j = 1:k
		@threads for i = 2^j:2^j:min(l, 2^k)
			@inbounds y[i] = y[i - 2^(j - 1)] ⊕ y[i]
		end
	end
	# do expand phase
	@timeit to "expand" for j = (k - 1):-1:1
		@threads for i = 3*2^(j - 1):2^j:min(l, 2^k)
			@inbounds y[i] = y[i - 2^(j - 1)] ⊕ y[i]
		end
	end
	return y
end

# ╔═╡ 60093202-d8fd-4e78-b76f-2bc69775eacb
let
	TimerOutputs.reset_timer!(to)
	for i in 1:10
		A = fill(1, 500_000)
		prefix_threads!(+, A)
	end
	to
end

# ╔═╡ b269b4e8-8738-4abd-a4ab-7c1682252f9b
md"""
### Allocation profiler

The allocation profiler will collect backtraces at allocation sites with a default `sample_rate=0.0001` (So about 1/10_000 allocations).

[PProf.jl](https://github.com/JuliaPerf/PProf.jl) also has a callgraph view instead of just the "icile" view.
"""

# ╔═╡ f15244e7-8b92-4972-8af0-ea689a83f700
@profview_allocs profile_test(10)

# ╔═╡ 69e35f64-1429-413e-8e11-8b785251ddcd
@profview_allocs profile_test(10) sample_rate=1.0

# ╔═╡ 11f8a810-830d-47cd-902e-8fe96aca1149
md"""
## Where does time go?
"""

# ╔═╡ f84dd0b3-fef4-4f52-b9d6-e09197e8d49a
TwoColumn(
md"""
### Your code
- Arithmetic operations
- Special functions
- Memory accesses
  - Memory layout
- Type-instabilities
- Bad algorithm choices
- Lack of parallelism
""",
md"""

### Runtime
- Memory allocation
- Garbage collection (finding unused memory)
- Waiting for the OS
  - Network/Filesystem/...
- Concurrency
  - Lock conflicts
- Function dispatch
- Compiling code
	"""
)

# ╔═╡ c20d320d-8bc3-4407-91ad-7b98a9956090
md"""
## Performance annotation in Julia

- https://docs.julialang.org/en/v1/manual/performance-tips/
- Julia does bounds checking by default `ones(10)[11]` is an error
- `@inbounds` Turns of bounds-checking locally
- `@fastmath` Turns of strict IEEE749 locally – be very careful this might not do what you want
- `@simd` and `@simd ivdep` provide stronger gurantuees to encourage LLVM to use SIMD operations

"""

# ╔═╡ aad3dddf-c6b1-4c60-94fd-b7a31861aa7c
function my_sum(X)
	acc = zero(eltype(X))
	for x in X
		acc += x
	end
	return acc
end

# ╔═╡ a57c204a-e329-4ad9-a3d7-a88b3020efbd
@benchmark my_sum(w) setup=(w=rand(2048))

# ╔═╡ 90585941-f47d-4e48-b2e4-ebe402cbd29c
function my_sum2(X)
	acc = zero(eltype(X))
	@simd for x in X
		acc += x
	end
	return acc
end

# ╔═╡ 0b65c669-1f2b-4bc2-8f7b-d30a1b19a1db
@benchmark my_sum2(w) setup=(w=rand(2048))

# ╔═╡ d3c47968-1b79-44cc-8625-58fa5c82990a
md"""
!!! note
	`@simd` allows for re-ordering of reduction operations.
"""

# ╔═╡ 3979717b-c8d8-4a30-ae36-f923e702d484
md"""
## Example: Matrix addition

Matrix addition is an interesting case because it has no data re-use, so there is no possible temporal locality, but depending on *what order* you use for the loops and how matrices are stored in memory, you may or may not get **spatial locality** that takes advantage of **cache lines**.

Here let's implement matrix addition in two different ways. We'll use a pre-allocated output array so that our benchmark does not include the time for memory allocation:
"""

# ╔═╡ 3f344124-fd06-453d-ad16-c9d1e62fb9bd
function matadd1!(C, A, B)
    size(C) == size(A) == size(B) || throw(DimensionMismatchmatch())
    m,n = size(A)
    for i = 1:m
        @simd for j = 1:n
            @inbounds C[i,j] = A[i,j] + B[i,j]
        end
    end
    return C
end

# ╔═╡ 5f572c39-66af-4adf-9e16-7462422b7254
matadd1(A, B) = matadd1!(similar(A, promote_type(eltype(A), eltype(B))), A, B)

# ╔═╡ 7fd5e1f7-3ac5-4f9e-8c6c-dc6a397bdc13
function matadd2!(C, A, B)
    size(C) == size(A) == size(B) || throw(DimensionMismatch())
    m,n = size(A)
    for j = 1:n
        @simd for i = 1:m
            @inbounds C[i,j] = A[i,j] + B[i,j]
        end
    end
    return C
end

# ╔═╡ f500571a-0726-49f7-8ac2-884eb9a26728
matadd2(A, B) = matadd2!(similar(A, promote_type(eltype(A), eltype(B))), A, B)

# ╔═╡ 5c3cc925-4873-4d90-9911-a9dc927c9228
let
	A = rand(5,6)
	B = rand(5,6)
	A + B ≈ matadd1(A,B) ≈ matadd2(A,B)
end

# ╔═╡ c3dbf98a-a629-4188-abe2-9d8792b0f8f5
function logspace(start, stop, length)
	exp10.(range(start; stop, length))
end

# ╔═╡ c0c1651b-9343-439a-b4c1-d5c37cbdf494
begin
	Na = round.(Int, logspace(1, log10(3000), 60))  # 60 sizes from 10 to 3000
	# alternatively, use N = 10:1000 to see some interesting patterns due to cache associativity etc.
	t1 = Float64[]
	t2 = Float64[]
	for n in Na
	    local A = zeros(n,n)
	    local B = zeros(n,n)
	    # preallocate output C so that allocation is not included in timing
	    C = zeros(n,n)
	    matadd1!(C,A,B) # add once just to make sure we are in cache if A and B are small
	    push!(t1, @elapsed matadd1!(C,A,B))
	    push!(t2, @elapsed matadd2!(C,A,B))
	    println("finished n = $n: ratio t1/t2 of ", t1[end]/t2[end])
	end
end

# ╔═╡ 3d6beb54-a1e1-4373-b759-d335a0a73e54
let 
	fig = Figure()
	ax = Axis(fig[1, 1],
			 title = "",
			 xlabel = "matrix size n",
			 ylabel = L"\text{gigaflops~} \frac{n^2}{t}")
	lines!(ax, Na, Na.^2 ./ t1 .* 1e-9, label="by row")
	lines!(ax, Na, Na.^2 ./ t2 .* 1e-9, label="by column")
	axislegend(ax, position = :rt)
	fig
end

# ╔═╡ 1d0f5763-e7a4-4dd5-8a12-1a229c245cb8
let
	fig = Figure()
	ax = Axis(fig[1, 1],
			 title = "Ratio of matrix-addition algorithms",
			 xlabel = "matrix size n",
			 ylabel = "by row time / by column time")

	lines!(ax, Na, t1 ./t2)
	fig
end

# ╔═╡ 1c868eb8-988d-469a-a0d5-4e640030afdc
md"""
!!! note
    The reason for this is that **Julia stores matrices with consecutive columns**, which is known as **column-major storage** format.
"""

# ╔═╡ 9e246b82-e6b2-4e70-9d04-29a3ad8ccc26
let 
	A = zeros(Int, 10, 3)
	for i in 1:length(A)
		A[i] = i
	end
	A
end

# ╔═╡ 663bf708-3587-4b89-9310-6762ad6a7fc4
md"""
## Memory layout of Objects
"""

# ╔═╡ 99ceea1c-cfc3-413e-bd7e-199f0dd37f74
md"""
Julia has two types of struct types.

1. Immutable
2. Mutable

**Immutable** datatypes have fields that can't be mutated and they do not have *object-identity*. Think numbers, and similar objects.

**Mutable** datatypes can be updated in place and they posses object-identity.
"""

# ╔═╡ f26973b0-f952-46b8-89fc-3e3ec53c7d7a
struct MyImmutable
	a::Float64
end

# ╔═╡ 3585b48e-2a72-43a3-a66e-dfa539a3f473
mutable struct MyMutable
	a::Float64
end

# ╔═╡ 82ecf1cb-88d1-47ab-a70b-3472f5450dc8
let
	x = MyImmutable(1.0)
	y = MyImmutable(1.0)

	x === y
end

# ╔═╡ 41ada7f5-4d9c-4611-9cba-cc761847e082
let
	x = MyMutable(1.0)
	y = MyMutable(1.0)

	x === y
end

# ╔═╡ 111edbf4-218a-4f69-a42a-ed1ee5291d74
with_terminal() do
	about(Float64(ℯ))
end

# ╔═╡ a63c2727-5620-4d96-a2c2-1c156d361dc9
with_terminal() do
	about(1.0 + 0.0im)
end

# ╔═╡ 7b7e6228-0e38-4c3f-807c-1444cfd23968
with_terminal() do
	about(MyImmutable)
end

# ╔═╡ 5abf32f0-bc53-4369-b537-023ed6f4c83b
with_terminal() do
	about(MyMutable)
end

# ╔═╡ be00f1de-8eef-457c-a300-36f4010fc2b7
begin
	x1 = fill(MyImmutable(0.0), 10)
	x1[1] = MyImmutable(1.0)
	x1
end

# ╔═╡ d6bb2f8e-8f69-4001-92fa-dbd321785799
begin
	x2 = fill(MyMutable(0.0), 10)
	x2[1].a = 1.0
	x2
end

# ╔═╡ 176a75bd-f0c5-4e68-8045-7319333d4052
md"""
!!! warning
	`fill` with a mutable object will lead to aliasing.
"""

# ╔═╡ a0819e29-a1c1-4bd5-8ca8-a087946b0247
begin
	x3 = [MyMutable(0.0) for _ in 1:10]
	x3[1].a = 1.0
	x3
end

# ╔═╡ 2acabb56-87fe-4242-a497-c1d43e3ecdfb
with_terminal() do
	about([1.0, 2.0])
end

# ╔═╡ b8ba3334-b2b4-45b3-b9f3-7470502f803b
with_terminal() do
	about([1.0+0.0im, 2.0-1.0im])
end

# ╔═╡ 9b7a0beb-852f-410d-8dab-f133911485db
with_terminal() do
	about([MyMutable(0.0), MyMutable(1.0)])
end

# ╔═╡ 8e5ad5e5-915c-494f-8026-8e7db6fe3fb6
md"""
!!! info
    Mutable objects are stored in fields and arrays as references (pointers). 
    Immutable objects may be stored **inline**. 
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
About = "69d22d85-9f48-4c46-bbbe-7ad8341ff72a"
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
CpuId = "adafc99b-e345-5852-983c-f28acb93d879"
IntelITT = "c9b2f978-7543-4802-ae44-75068f23ee64"
InteractiveUtils = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
LIKWID = "bf22376a-e803-4184-b2ed-56326e3bff83"
LinuxPerf = "b4c46c6c-4fb0-484d-a11a-41bc3392d094"
OrdinaryDiffEqLowStorageRK = "b0944070-b475-4768-8dec-fb6eb410534d"
PProf = "e4faabce-9ead-11e9-39d9-4379958e3056"
PlutoTeachingTools = "661c6b06-c737-4d37-b85c-46df65de6f69"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Profile = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"
ProfileCanvas = "efd6af41-a80b-495e-886c-e51b0c7d77a3"
Serialization = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
ThreadPinning = "811555cd-349b-4f26-b7bc-1f208b848042"
TimerOutputs = "a759f4b9-e2f1-59dc-863e-4aeb61b1ea8f"
Trixi = "a7f1ee26-1774-49b1-8366-f1abc58fbfcb"

[compat]
About = "~1.0.4"
BenchmarkTools = "~1.6.3"
CairoMakie = "~0.15.9"
CpuId = "~0.3.1"
IntelITT = "~0.2.1"
LIKWID = "~0.4.5"
LinuxPerf = "~0.4.2"
OrdinaryDiffEqLowStorageRK = "~1.12.0"
PProf = "~3.2.0"
PlutoTeachingTools = "~0.4.7"
PlutoUI = "~0.7.79"
ProfileCanvas = "~0.1.7"
ThreadPinning = "~1.0.2"
TimerOutputs = "~0.5.29"
Trixi = "~0.15.8"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.11.9"
manifest_format = "2.0"
project_hash = "d083650a378c29047a54375dfb5bd1c126173816"

[[deps.ADTypes]]
git-tree-sha1 = "f7304359109c768cf32dc5fa2d371565bb63b68a"
uuid = "47edcb42-4c32-4615-8424-f2b9edc5f35b"
version = "1.21.0"
weakdeps = ["ChainRulesCore", "ConstructionBase", "EnzymeCore"]

    [deps.ADTypes.extensions]
    ADTypesChainRulesCoreExt = "ChainRulesCore"
    ADTypesConstructionBaseExt = "ConstructionBase"
    ADTypesEnzymeCoreExt = "EnzymeCore"

[[deps.About]]
deps = ["InteractiveUtils", "JuliaSyntaxHighlighting", "PrecompileTools", "StyledStrings"]
git-tree-sha1 = "b0dcdec6d6279635bb338e7c266ff629388180e0"
uuid = "69d22d85-9f48-4c46-bbbe-7ad8341ff72a"
version = "1.0.4"
weakdeps = ["Pkg"]

    [deps.About.extensions]
    PkgExt = "Pkg"

[[deps.AbstractFFTs]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "d92ad398961a3ed262d8bf04a1a2b8340f915fef"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.5.0"
weakdeps = ["ChainRulesCore", "Test"]

    [deps.AbstractFFTs.extensions]
    AbstractFFTsChainRulesCoreExt = "ChainRulesCore"
    AbstractFFTsTestExt = "Test"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "6e1d2a35f2f90a4bc7c2ed98079b2ba09c35b83a"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.3.2"

[[deps.AbstractTrees]]
git-tree-sha1 = "2d9c9a55f9c93e8887ad391fbae72f8ef55e1177"
uuid = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
version = "0.4.5"

[[deps.Accessors]]
deps = ["CompositionsBase", "ConstructionBase", "Dates", "InverseFunctions", "MacroTools"]
git-tree-sha1 = "856ecd7cebb68e5fc87abecd2326ad59f0f911f3"
uuid = "7d9f7c33-5ae7-4f3b-8dc6-eff91059b697"
version = "0.1.43"

    [deps.Accessors.extensions]
    AxisKeysExt = "AxisKeys"
    IntervalSetsExt = "IntervalSets"
    LinearAlgebraExt = "LinearAlgebra"
    StaticArraysExt = "StaticArrays"
    StructArraysExt = "StructArrays"
    TestExt = "Test"
    UnitfulExt = "Unitful"

    [deps.Accessors.weakdeps]
    AxisKeys = "94b1ba4f-4ee9-5380-92f1-94cde586c3c5"
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
    StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
    Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.Adapt]]
deps = ["LinearAlgebra", "Requires"]
git-tree-sha1 = "35ea197a51ce46fcd01c4a44befce0578a1aaeca"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "4.5.0"
weakdeps = ["SparseArrays", "StaticArrays"]

    [deps.Adapt.extensions]
    AdaptSparseArraysExt = "SparseArrays"
    AdaptStaticArraysExt = "StaticArrays"

[[deps.AdaptivePredicates]]
git-tree-sha1 = "7e651ea8d262d2d74ce75fdf47c4d63c07dba7a6"
uuid = "35492f91-a3bd-45ad-95db-fcad7dcfedb7"
version = "1.2.0"

[[deps.AliasTables]]
deps = ["PtrArrays", "Random"]
git-tree-sha1 = "9876e1e164b144ca45e9e3198d0b689cadfed9ff"
uuid = "66dad0bd-aa9a-41b7-9441-69ab47430ed8"
version = "1.1.3"

[[deps.Animations]]
deps = ["Colors"]
git-tree-sha1 = "e092fa223bf66a3c41f9c022bd074d916dc303e7"
uuid = "27a7e980-b3e6-11e9-2bcd-0b925532e340"
version = "0.4.2"

[[deps.ArgCheck]]
git-tree-sha1 = "f9e9a66c9b7be1ad7372bbd9b062d9230c30c5ce"
uuid = "dce04be8-c92d-5529-be00-80e4d2c0e197"
version = "2.5.0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.ArrayInterface]]
deps = ["Adapt", "LinearAlgebra"]
git-tree-sha1 = "78b3a7a536b4b0a747a0f296ea77091ca0a9f9a3"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "7.23.0"

    [deps.ArrayInterface.extensions]
    ArrayInterfaceAMDGPUExt = "AMDGPU"
    ArrayInterfaceBandedMatricesExt = "BandedMatrices"
    ArrayInterfaceBlockBandedMatricesExt = "BlockBandedMatrices"
    ArrayInterfaceCUDAExt = "CUDA"
    ArrayInterfaceCUDSSExt = ["CUDSS", "CUDA"]
    ArrayInterfaceChainRulesCoreExt = "ChainRulesCore"
    ArrayInterfaceChainRulesExt = "ChainRules"
    ArrayInterfaceGPUArraysCoreExt = "GPUArraysCore"
    ArrayInterfaceMetalExt = "Metal"
    ArrayInterfaceReverseDiffExt = "ReverseDiff"
    ArrayInterfaceSparseArraysExt = "SparseArrays"
    ArrayInterfaceStaticArraysCoreExt = "StaticArraysCore"
    ArrayInterfaceTrackerExt = "Tracker"

    [deps.ArrayInterface.weakdeps]
    AMDGPU = "21141c5a-9bdb-4563-92ae-f87d6854732e"
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    BlockBandedMatrices = "ffab5731-97b5-5995-9138-79e8c1846df0"
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    CUDSS = "45b445bb-4962-46a0-9369-b4df9d0f772e"
    ChainRules = "082447d4-558c-5d27-93f4-14fc19e9eca2"
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
    Metal = "dde4c033-4e86-420c-a63e-0dd931031962"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    StaticArraysCore = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.Atomix]]
deps = ["UnsafeAtomics"]
git-tree-sha1 = "29bb0eb6f578a587a49da16564705968667f5fa8"
uuid = "a9b6321e-bd34-4604-b9c9-b65b8de01458"
version = "1.1.2"

    [deps.Atomix.extensions]
    AtomixCUDAExt = "CUDA"
    AtomixMetalExt = "Metal"
    AtomixOpenCLExt = "OpenCL"
    AtomixoneAPIExt = "oneAPI"

    [deps.Atomix.weakdeps]
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    Metal = "dde4c033-4e86-420c-a63e-0dd931031962"
    OpenCL = "08131aa3-fb12-5dee-8b74-c09406e224a2"
    oneAPI = "8f75cd03-7ff8-4ecb-9b8f-daf728133b1b"

[[deps.AutoHashEquals]]
git-tree-sha1 = "4ec6b48702dacc5994a835c1189831755e4e76ef"
uuid = "15f4f7f2-30c1-5605-9d31-71845cf9641f"
version = "2.2.0"

[[deps.Automa]]
deps = ["PrecompileTools", "SIMD", "TranscodingStreams"]
git-tree-sha1 = "a8f503e8e1a5f583fbef15a8440c8c7e32185df2"
uuid = "67c07d97-cdcb-5c2c-af73-a7f9c32a568b"
version = "1.1.0"

[[deps.AxisAlgorithms]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "WoodburyMatrices"]
git-tree-sha1 = "01b8ccb13d68535d73d2b0c23e39bd23155fb712"
uuid = "13072b0f-2c55-5437-9ae7-d433b7a33950"
version = "1.1.0"

[[deps.AxisArrays]]
deps = ["Dates", "IntervalSets", "IterTools", "RangeArrays"]
git-tree-sha1 = "4126b08903b777c88edf1754288144a0492c05ad"
uuid = "39de3d68-74b9-583c-8d2d-e117c070f3a9"
version = "0.4.8"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.BaseDirs]]
git-tree-sha1 = "bca794632b8a9bbe159d56bf9e31c422671b35e0"
uuid = "18cc8868-cbac-4acf-b575-c8ff214dc66f"
version = "1.3.2"

[[deps.BenchmarkTools]]
deps = ["Compat", "JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "7fecfb1123b8d0232218e2da0c213004ff15358d"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.6.3"

[[deps.BitTwiddlingConvenienceFunctions]]
deps = ["Static"]
git-tree-sha1 = "f21cfd4950cb9f0587d5067e69405ad2acd27b87"
uuid = "62783981-4cbd-42fc-bca8-16325de8dc4b"
version = "0.1.6"

[[deps.BracketingNonlinearSolve]]
deps = ["CommonSolve", "ConcreteStructs", "NonlinearSolveBase", "PrecompileTools", "Reexport", "SciMLBase"]
git-tree-sha1 = "4999dff8efd76814f6662519b985aeda975a1924"
uuid = "70df07ce-3d50-431d-a3e7-ca6ddb60ac1e"
version = "1.11.0"
weakdeps = ["ChainRulesCore", "ForwardDiff"]

    [deps.BracketingNonlinearSolve.extensions]
    BracketingNonlinearSolveChainRulesCoreExt = ["ChainRulesCore", "ForwardDiff"]
    BracketingNonlinearSolveForwardDiffExt = "ForwardDiff"

[[deps.BufferedStreams]]
git-tree-sha1 = "6863c5b7fc997eadcabdbaf6c5f201dc30032643"
uuid = "e1450e63-4bb3-523b-b2a4-4ffa8c0fd77d"
version = "1.2.2"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1b96ea4a01afe0ea4090c5c8039690672dd13f2e"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.9+0"

[[deps.CEnum]]
git-tree-sha1 = "389ad5c84de1ae7cf0e28e381131c98ea87d54fc"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.5.0"

[[deps.CPUSummary]]
deps = ["CpuId", "IfElse", "PrecompileTools", "Preferences", "Static"]
git-tree-sha1 = "f3a21d7fc84ba618a779d1ed2fcca2e682865bab"
uuid = "2a0fbf3d-bb9c-48f3-b0a9-814d99fd7ab9"
version = "0.2.7"

[[deps.CRC32c]]
uuid = "8bf52ea8-c179-5cab-976a-9e18b702a9bc"
version = "1.11.0"

[[deps.CRlibm]]
deps = ["CRlibm_jll"]
git-tree-sha1 = "66188d9d103b92b6cd705214242e27f5737a1e5e"
uuid = "96374032-68de-5a5b-8d9e-752f78720389"
version = "1.0.2"

[[deps.CRlibm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e329286945d0cfc04456972ea732551869af1cfc"
uuid = "4e9b3aee-d8a1-5a3d-ad8b-7d824db253f0"
version = "1.0.1+0"

[[deps.Cairo]]
deps = ["Cairo_jll", "Colors", "Glib_jll", "Graphics", "Libdl", "Pango_jll"]
git-tree-sha1 = "71aa551c5c33f1a4415867fe06b7844faadb0ae9"
uuid = "159f3aea-2a34-519c-b102-8c37f9878175"
version = "1.1.1"

[[deps.CairoMakie]]
deps = ["CRC32c", "Cairo", "Cairo_jll", "Colors", "FileIO", "FreeType", "GeometryBasics", "LinearAlgebra", "Makie", "PrecompileTools"]
git-tree-sha1 = "fa072933899aae6dc61dde934febed8254e66c6a"
uuid = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
version = "0.15.9"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "a21c5464519504e41e0cbc91f0188e8ca23d7440"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.18.5+1"

[[deps.CaratheodoryPruning]]
deps = ["LinearAlgebra", "ProgressBars", "Random"]
git-tree-sha1 = "de17842b2a680ad0048fcb455f62ad87d61a0d84"
uuid = "ab320bfc-8242-4797-bfc4-9370c33880e7"
version = "0.1.1"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra"]
git-tree-sha1 = "e4c6a16e77171a5f5e25e9646617ab1c276c5607"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.26.0"
weakdeps = ["SparseArrays"]

    [deps.ChainRulesCore.extensions]
    ChainRulesCoreSparseArraysExt = "SparseArrays"

[[deps.ChangePrecision]]
deps = ["LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "2ac5097b3caf70b772901abd824e09f991e47296"
uuid = "3cb15238-376d-56a3-8042-d33272777c9a"
version = "1.1.1"

[[deps.CloseOpenIntervals]]
deps = ["Static", "StaticArrayInterface"]
git-tree-sha1 = "05ba0d07cd4fd8b7a39541e31a7b0254704ea581"
uuid = "fb6a15b2-703c-40df-9091-08a04967cfa9"
version = "0.1.13"

[[deps.CodeTracking]]
deps = ["InteractiveUtils", "UUIDs"]
git-tree-sha1 = "b7231a755812695b8046e8471ddc34c8268cbad5"
uuid = "da1fd8a2-8d9e-5ec2-8556-3022fb5608a2"
version = "3.0.0"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "962834c22b66e32aa10f7611c08c8ca4e20749a9"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.8"

[[deps.ColorBrewer]]
deps = ["Colors", "JSON"]
git-tree-sha1 = "07da79661b919001e6863b81fc572497daa58349"
uuid = "a2cac450-b92f-5266-8821-25eda20663c8"
version = "0.4.2"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "PrecompileTools", "Random"]
git-tree-sha1 = "b0fd3f56fa442f81e0a47815c92245acfaaa4e34"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.31.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "67e11ee83a43eb71ddc950302c53bf33f0690dfe"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.12.1"
weakdeps = ["StyledStrings"]

    [deps.ColorTypes.extensions]
    StyledStringsExt = "StyledStrings"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "Requires", "Statistics", "TensorCore"]
git-tree-sha1 = "8b3b6f87ce8f65a2b4f857528fd8d70086cd72b1"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.11.0"
weakdeps = ["SpecialFunctions"]

    [deps.ColorVectorSpace.extensions]
    SpecialFunctionsExt = "SpecialFunctions"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "37ea44092930b1811e666c3bc38065d7d87fcc74"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.13.1"

[[deps.CommonSolve]]
git-tree-sha1 = "78ea4ddbcf9c241827e7035c3a03e2e456711470"
uuid = "38540f10-b2f7-11e9-35d8-d573e4eb0ff2"
version = "0.2.6"

[[deps.CommonSubexpressions]]
deps = ["MacroTools"]
git-tree-sha1 = "cda2cfaebb4be89c9084adaca7dd7333369715c5"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.1"

[[deps.CommonWorldInvalidations]]
git-tree-sha1 = "ae52d1c52048455e85a387fbee9be553ec2b68d0"
uuid = "f70d9fcc-98c5-4d4a-abd7-e4cdeebd8ca8"
version = "1.0.0"

[[deps.Compat]]
deps = ["TOML", "UUIDs"]
git-tree-sha1 = "9d8a54ce4b17aa5bdce0ea5c34bc5e7c340d16ad"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.18.1"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.1.1+0"

[[deps.CompositionsBase]]
git-tree-sha1 = "802bb88cd69dfd1509f6670416bd4434015693ad"
uuid = "a33af91c-f02d-484b-be07-31d278c5ca2b"
version = "0.1.2"
weakdeps = ["InverseFunctions"]

    [deps.CompositionsBase.extensions]
    CompositionsBaseInverseFunctionsExt = "InverseFunctions"

[[deps.ComputePipeline]]
deps = ["Observables", "Preferences"]
git-tree-sha1 = "3b4be73db165146d8a88e47924f464e55ab053cd"
uuid = "95dc2771-c249-4cd0-9c9f-1f3b4330693c"
version = "0.1.7"

[[deps.ConcreteStructs]]
git-tree-sha1 = "f749037478283d372048690eb3b5f92a79432b34"
uuid = "2569d6c7-a4a2-43d3-a901-331e8e4be471"
version = "0.2.3"

[[deps.ConstructionBase]]
git-tree-sha1 = "b4b092499347b18a015186eae3042f72267106cb"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.6.0"
weakdeps = ["IntervalSets", "LinearAlgebra", "StaticArrays"]

    [deps.ConstructionBase.extensions]
    ConstructionBaseIntervalSetsExt = "IntervalSets"
    ConstructionBaseLinearAlgebraExt = "LinearAlgebra"
    ConstructionBaseStaticArraysExt = "StaticArrays"

[[deps.Contour]]
git-tree-sha1 = "439e35b0b36e2e5881738abc8857bd92ad6ff9a8"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.6.3"

[[deps.CpuId]]
deps = ["Markdown"]
git-tree-sha1 = "fcbb72b032692610bfbdb15018ac16a36cf2e406"
uuid = "adafc99b-e345-5852-983c-f28acb93d879"
version = "0.3.1"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataStructures]]
deps = ["OrderedCollections"]
git-tree-sha1 = "e357641bb3e0638d353c4b29ea0e40ea644066a6"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.19.3"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"
version = "1.11.0"

[[deps.DelaunayTriangulation]]
deps = ["AdaptivePredicates", "EnumX", "ExactPredicates", "Random"]
git-tree-sha1 = "c55f5a9fd67bdbc8e089b5a3111fe4292986a8e8"
uuid = "927a84f5-c5f4-47a5-9785-b46e178433df"
version = "1.6.6"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
git-tree-sha1 = "9e2f36d3c96a820c678f2f1f1782582fcf685bae"
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"
version = "1.9.1"

[[deps.DiffEqBase]]
deps = ["ArrayInterface", "BracketingNonlinearSolve", "ConcreteStructs", "DocStringExtensions", "FastBroadcast", "FastClosures", "FastPower", "FunctionWrappers", "FunctionWrappersWrappers", "LinearAlgebra", "Logging", "Markdown", "MuladdMacro", "PrecompileTools", "Printf", "RecursiveArrayTools", "Reexport", "SciMLBase", "SciMLOperators", "SciMLStructures", "Setfield", "Static", "StaticArraysCore", "SymbolicIndexingInterface", "TruncatedStacktraces"]
git-tree-sha1 = "1719cd1b0a12e01775dc6db1577dd6ace1798fee"
uuid = "2b5f629d-d688-5b77-993f-72d75c75574e"
version = "6.210.1"

    [deps.DiffEqBase.extensions]
    DiffEqBaseCUDAExt = "CUDA"
    DiffEqBaseChainRulesCoreExt = "ChainRulesCore"
    DiffEqBaseEnzymeExt = ["ChainRulesCore", "Enzyme"]
    DiffEqBaseFlexUnitsExt = "FlexUnits"
    DiffEqBaseForwardDiffExt = ["ForwardDiff"]
    DiffEqBaseGTPSAExt = "GTPSA"
    DiffEqBaseGeneralizedGeneratedExt = "GeneralizedGenerated"
    DiffEqBaseMPIExt = "MPI"
    DiffEqBaseMeasurementsExt = "Measurements"
    DiffEqBaseMonteCarloMeasurementsExt = "MonteCarloMeasurements"
    DiffEqBaseMooncakeExt = "Mooncake"
    DiffEqBaseReverseDiffExt = "ReverseDiff"
    DiffEqBaseSparseArraysExt = "SparseArrays"
    DiffEqBaseTrackerExt = "Tracker"
    DiffEqBaseUnitfulExt = "Unitful"

    [deps.DiffEqBase.weakdeps]
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
    Enzyme = "7da242da-08ed-463a-9acd-ee780be4f1d9"
    FlexUnits = "76e01b6b-c995-4ce6-8559-91e72a3d4e95"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    GTPSA = "b27dd330-f138-47c5-815b-40db9dd9b6e8"
    GeneralizedGenerated = "6b9d7cbe-bcb9-11e9-073f-15a7a543e2eb"
    MPI = "da04e1cc-30fd-572f-bb4f-1f8673147195"
    Measurements = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
    MonteCarloMeasurements = "0987c9cc-fe09-11e8-30f0-b96dd679fdca"
    Mooncake = "da2b9cff-9c12-43a0-ae48-6db2b0edb7d6"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.DiffEqCallbacks]]
deps = ["ConcreteStructs", "DataStructures", "DiffEqBase", "DifferentiationInterface", "LinearAlgebra", "Markdown", "PrecompileTools", "RecipesBase", "RecursiveArrayTools", "SciMLBase", "StaticArraysCore"]
git-tree-sha1 = "f17b863c2d5d496363fe36c8d8535cc6a33c9952"
uuid = "459566f4-90b8-5000-8ac3-15dfb0a30def"
version = "4.12.0"

    [deps.DiffEqCallbacks.extensions]
    DiffEqCallbacksFunctorsExt = "Functors"

    [deps.DiffEqCallbacks.weakdeps]
    Functors = "d9f16b24-f501-4c13-a1f2-28368ffc5196"

[[deps.DiffResults]]
deps = ["StaticArraysCore"]
git-tree-sha1 = "782dd5f4561f5d267313f23853baaaa4c52ea621"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.1.0"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "23163d55f885173722d1e4cf0f6110cdbaf7e272"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.15.1"

[[deps.DifferentiationInterface]]
deps = ["ADTypes", "LinearAlgebra"]
git-tree-sha1 = "7ae99144ea44715402c6c882bfef2adbeadbc4ce"
uuid = "a0c0ee7d-e4b9-4e03-894e-1c5f64a51d63"
version = "0.7.16"

    [deps.DifferentiationInterface.extensions]
    DifferentiationInterfaceChainRulesCoreExt = "ChainRulesCore"
    DifferentiationInterfaceDiffractorExt = "Diffractor"
    DifferentiationInterfaceEnzymeExt = ["EnzymeCore", "Enzyme"]
    DifferentiationInterfaceFastDifferentiationExt = "FastDifferentiation"
    DifferentiationInterfaceFiniteDiffExt = "FiniteDiff"
    DifferentiationInterfaceFiniteDifferencesExt = "FiniteDifferences"
    DifferentiationInterfaceForwardDiffExt = ["ForwardDiff", "DiffResults"]
    DifferentiationInterfaceGPUArraysCoreExt = "GPUArraysCore"
    DifferentiationInterfaceGTPSAExt = "GTPSA"
    DifferentiationInterfaceMooncakeExt = "Mooncake"
    DifferentiationInterfacePolyesterForwardDiffExt = ["PolyesterForwardDiff", "ForwardDiff", "DiffResults"]
    DifferentiationInterfaceReverseDiffExt = ["ReverseDiff", "DiffResults"]
    DifferentiationInterfaceSparseArraysExt = "SparseArrays"
    DifferentiationInterfaceSparseConnectivityTracerExt = "SparseConnectivityTracer"
    DifferentiationInterfaceSparseMatrixColoringsExt = "SparseMatrixColorings"
    DifferentiationInterfaceStaticArraysExt = "StaticArrays"
    DifferentiationInterfaceSymbolicsExt = "Symbolics"
    DifferentiationInterfaceTrackerExt = "Tracker"
    DifferentiationInterfaceZygoteExt = ["Zygote", "ForwardDiff"]

    [deps.DifferentiationInterface.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    DiffResults = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
    Diffractor = "9f5e2b26-1114-432f-b630-d3fe2085c51c"
    Enzyme = "7da242da-08ed-463a-9acd-ee780be4f1d9"
    EnzymeCore = "f151be2c-9106-41f4-ab19-57ee4f262869"
    FastDifferentiation = "eb9bf01b-bf85-4b60-bf87-ee5de06c00be"
    FiniteDiff = "6a86dc24-6348-571c-b903-95158fe2bd41"
    FiniteDifferences = "26cc04aa-876d-5657-8c51-4c34ba976000"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
    GTPSA = "b27dd330-f138-47c5-815b-40db9dd9b6e8"
    Mooncake = "da2b9cff-9c12-43a0-ae48-6db2b0edb7d6"
    PolyesterForwardDiff = "98d1487c-24ca-40b6-b7ab-df2af84e126b"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    SparseConnectivityTracer = "9f842d2f-2579-4b1d-911e-f412cf18a3f5"
    SparseMatrixColorings = "0a514795-09f3-496d-8182-132a7b665d35"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
    Symbolics = "0c5d862f-8b57-4792-8d23-62f2024744c7"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"
    Zygote = "e88e6eb3-aa80-5325-afca-941959d7151f"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"
version = "1.11.0"

[[deps.Distributions]]
deps = ["AliasTables", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SpecialFunctions", "Statistics", "StatsAPI", "StatsBase", "StatsFuns"]
git-tree-sha1 = "fbcc7610f6d8348428f722ecbe0e6cfe22e672c6"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.123"

    [deps.Distributions.extensions]
    DistributionsChainRulesCoreExt = "ChainRulesCore"
    DistributionsDensityInterfaceExt = "DensityInterface"
    DistributionsTestExt = "Test"

    [deps.Distributions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    DensityInterface = "b429d917-457f-4dbc-8f4c-0cc954292b1d"
    Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.DocStringExtensions]]
git-tree-sha1 = "7442a5dfe1ebb773c29cc2962a8980f47221d76c"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.5"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e3290f2d49e661fbd94046d7e3726ffcb2d41053"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.4+0"

[[deps.EllipsisNotation]]
deps = ["PrecompileTools", "StaticArrayInterface"]
git-tree-sha1 = "df3c9e8000ee77c6b81955025cf18722c95c41a4"
uuid = "da5c29d0-fa7d-589e-88eb-ea29b0a81949"
version = "1.9.0"

[[deps.EnumX]]
git-tree-sha1 = "c49898e8438c828577f04b92fc9368c388ac783c"
uuid = "4e289a0a-7415-4d19-859d-a7e5c4648b56"
version = "1.0.7"

[[deps.EnzymeCore]]
git-tree-sha1 = "990991b8aa76d17693a98e3a915ac7aa49f08d1a"
uuid = "f151be2c-9106-41f4-ab19-57ee4f262869"
version = "0.8.18"
weakdeps = ["Adapt", "ChainRulesCore"]

    [deps.EnzymeCore.extensions]
    AdaptExt = "Adapt"
    EnzymeCoreChainRulesCoreExt = "ChainRulesCore"

[[deps.ExactPredicates]]
deps = ["IntervalArithmetic", "Random", "StaticArrays"]
git-tree-sha1 = "83231673ea4d3d6008ac74dc5079e77ab2209d8f"
uuid = "429591f6-91af-11e9-00e2-59fbe8cec110"
version = "2.2.9"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "27af30de8b5445644e8ffe3bcb0d72049c089cf1"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.7.3+0"

[[deps.ExprTools]]
git-tree-sha1 = "27415f162e6028e81c72b82ef756bf321213b6ec"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.10"

[[deps.ExproniconLite]]
git-tree-sha1 = "c13f0b150373771b0fdc1713c97860f8df12e6c2"
uuid = "55351af7-c7e9-48d6-89ff-24e801d99491"
version = "0.10.14"

[[deps.Extents]]
git-tree-sha1 = "b309b36a9e02fe7be71270dd8c0fd873625332b4"
uuid = "411431e0-e8b7-467b-b5e0-f676ba4f2910"
version = "0.1.6"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "PCRE2_jll", "Zlib_jll", "libaom_jll", "libass_jll", "libfdk_aac_jll", "libva_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "66381d7059b5f3f6162f28831854008040a4e905"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "8.0.1+1"

[[deps.FFTA]]
deps = ["AbstractFFTs", "DocStringExtensions", "LinearAlgebra", "MuladdMacro", "Primes", "Random", "Reexport"]
git-tree-sha1 = "65e55303b72f4a567a51b174dd2c47496efeb95a"
uuid = "b86e33f2-c0db-4aa1-a6e0-ab43e668529e"
version = "0.3.1"

[[deps.FFTW]]
deps = ["AbstractFFTs", "FFTW_jll", "Libdl", "LinearAlgebra", "MKL_jll", "Preferences", "Reexport"]
git-tree-sha1 = "97f08406df914023af55ade2f843c39e99c5d969"
uuid = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
version = "1.10.0"

[[deps.FFTW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6d6219a004b8cf1e0b4dbe27a2860b8e04eba0be"
uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"
version = "3.3.11+0"

[[deps.FastBroadcast]]
deps = ["ArrayInterface", "LinearAlgebra", "Polyester", "Static", "StaticArrayInterface", "StrideArraysCore"]
git-tree-sha1 = "ab1b34570bcdf272899062e1a56285a53ecaae08"
uuid = "7034ab61-46d4-4ed7-9d0f-46aef9175898"
version = "0.3.5"

[[deps.FastClosures]]
git-tree-sha1 = "acebe244d53ee1b461970f8910c235b259e772ef"
uuid = "9aa1b823-49e4-5ca5-8b0f-3971ec8bab6a"
version = "0.3.2"

[[deps.FastGaussQuadrature]]
deps = ["LinearAlgebra", "SpecialFunctions", "StaticArrays"]
git-tree-sha1 = "0044e9f5e49a57e88205e8f30ab73928b05fe5b6"
uuid = "442a2c76-b920-505d-bb47-c5924d526838"
version = "1.1.0"

[[deps.FastPower]]
git-tree-sha1 = "862831f78c7a48681a074ecc9aac09f2de563f71"
uuid = "a4df4552-cc26-4903-aec0-212e50a0e84b"
version = "1.3.1"

    [deps.FastPower.extensions]
    FastPowerEnzymeExt = "Enzyme"
    FastPowerForwardDiffExt = "ForwardDiff"
    FastPowerMeasurementsExt = "Measurements"
    FastPowerMonteCarloMeasurementsExt = "MonteCarloMeasurements"
    FastPowerMooncakeExt = "Mooncake"
    FastPowerReverseDiffExt = "ReverseDiff"
    FastPowerTrackerExt = "Tracker"

    [deps.FastPower.weakdeps]
    Enzyme = "7da242da-08ed-463a-9acd-ee780be4f1d9"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    Measurements = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
    MonteCarloMeasurements = "0987c9cc-fe09-11e8-30f0-b96dd679fdca"
    Mooncake = "da2b9cff-9c12-43a0-ae48-6db2b0edb7d6"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "6522cfb3b8fe97bec632252263057996cbd3de20"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.18.0"

    [deps.FileIO.extensions]
    HTTPExt = "HTTP"

    [deps.FileIO.weakdeps]
    HTTP = "cd3eb016-35fb-5094-929b-558a96fad6f3"

[[deps.FilePaths]]
deps = ["FilePathsBase", "MacroTools", "Reexport"]
git-tree-sha1 = "a1b2fbfe98503f15b665ed45b3d149e5d8895e4c"
uuid = "8fc22ac5-c921-52a6-82fd-178b2807b824"
version = "0.9.0"

    [deps.FilePaths.extensions]
    FilePathsGlobExt = "Glob"
    FilePathsURIParserExt = "URIParser"
    FilePathsURIsExt = "URIs"

    [deps.FilePaths.weakdeps]
    Glob = "c27321d9-0574-5035-807b-f59d2c89b15c"
    URIParser = "30578b45-9adc-5946-b283-645ec420af67"
    URIs = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates"]
git-tree-sha1 = "3bab2c5aa25e7840a4b065805c0cdfc01f3068d2"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.24"
weakdeps = ["Mmap", "Test"]

    [deps.FilePathsBase.extensions]
    FilePathsBaseMmapExt = "Mmap"
    FilePathsBaseTestExt = "Test"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"
version = "1.11.0"

[[deps.FillArrays]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "2f979084d1e13948a3352cf64a25df6bd3b4dca3"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "1.16.0"
weakdeps = ["PDMats", "SparseArrays", "StaticArrays", "Statistics"]

    [deps.FillArrays.extensions]
    FillArraysPDMatsExt = "PDMats"
    FillArraysSparseArraysExt = "SparseArrays"
    FillArraysStaticArraysExt = "StaticArrays"
    FillArraysStatisticsExt = "Statistics"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "05882d6995ae5c12bb5f36dd2ed3f61c98cbb172"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.5"

[[deps.FlameGraphs]]
deps = ["AbstractTrees", "Colors", "FileIO", "FixedPointNumbers", "IndirectArrays", "LeftChildRightSiblingTrees", "Profile"]
git-tree-sha1 = "0166baf81babb91cf78bfcc771d8e87c43d568df"
uuid = "08572546-2f56-4bcf-ba4e-bab62c3a3f89"
version = "1.1.0"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Zlib_jll"]
git-tree-sha1 = "f85dac9a96a01087df6e3a749840015a0ca3817d"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.17.1+0"

[[deps.Format]]
git-tree-sha1 = "9c68794ef81b08086aeb32eeaf33531668d5f5fc"
uuid = "1fa38f19-a742-5d3f-a2b9-30dd87b9d5f8"
version = "1.3.7"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions"]
git-tree-sha1 = "eef4c86803f47dcb61e9b8790ecaa96956fdd8ae"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "1.3.2"
weakdeps = ["StaticArrays"]

    [deps.ForwardDiff.extensions]
    ForwardDiffStaticArraysExt = "StaticArrays"

[[deps.FreeType]]
deps = ["CEnum", "FreeType2_jll"]
git-tree-sha1 = "907369da0f8e80728ab49c1c7e09327bf0d6d999"
uuid = "b38be410-82b0-50bf-ab77-7b57e271db43"
version = "4.1.1"

[[deps.FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "2c5512e11c791d1baed2049c5652441b28fc6a31"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.13.4+0"

[[deps.FreeTypeAbstraction]]
deps = ["BaseDirs", "ColorVectorSpace", "Colors", "FreeType", "GeometryBasics", "Mmap"]
git-tree-sha1 = "4ebb930ef4a43817991ba35db6317a05e59abd11"
uuid = "663a7486-cb36-511b-a19d-713bb74d65c9"
version = "0.10.8"

[[deps.FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "7a214fdac5ed5f59a22c2d9a885a16da1c74bbc7"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.17+0"

[[deps.FunctionWrappers]]
git-tree-sha1 = "d62485945ce5ae9c0c48f124a84998d755bae00e"
uuid = "069b7b12-0de2-55c6-9aab-29f3d0a68a2e"
version = "1.1.3"

[[deps.FunctionWrappersWrappers]]
deps = ["FunctionWrappers"]
git-tree-sha1 = "b104d487b34566608f8b4e1c39fb0b10aa279ff8"
uuid = "77dc65aa-8811-40c2-897b-53d922fa7daf"
version = "0.1.3"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"
version = "1.11.0"

[[deps.GPUArraysCore]]
deps = ["Adapt"]
git-tree-sha1 = "83cf05ab16a73219e5f6bd1bdfa9848fa24ac627"
uuid = "46192b85-c4d5-4398-a991-12ede77f4527"
version = "0.2.0"

[[deps.GaussQuadrature]]
deps = ["SpecialFunctions"]
git-tree-sha1 = "eb6f1f48aa994f3018cbd029a17863c6535a266d"
uuid = "d54b0c1a-921d-58e0-8e36-89d8069c0969"
version = "0.5.8"

[[deps.GeometryBasics]]
deps = ["EarCut_jll", "Extents", "IterTools", "LinearAlgebra", "PrecompileTools", "Random", "StaticArrays"]
git-tree-sha1 = "1f5a80f4ed9f5a4aada88fc2db456e637676414b"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.5.10"

    [deps.GeometryBasics.extensions]
    GeometryBasicsGeoInterfaceExt = "GeoInterface"

    [deps.GeometryBasics.weakdeps]
    GeoInterface = "cf35fbd7-0cd7-5166-be24-54bfbe79505f"

[[deps.GettextRuntime_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll"]
git-tree-sha1 = "45288942190db7c5f760f59c04495064eedf9340"
uuid = "b0724c58-0f36-5564-988d-3bb0596ebc4a"
version = "0.22.4+0"

[[deps.Ghostscript_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Zlib_jll"]
git-tree-sha1 = "38044a04637976140074d0b0621c1edf0eb531fd"
uuid = "61579ee1-b43e-5ca0-a5da-69d92c66a64b"
version = "9.55.1+0"

[[deps.Giflib_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6570366d757b50fabae9f4315ad74d2e40c0560a"
uuid = "59f7168a-df46-5410-90c8-f2779963d0ec"
version = "5.2.3+0"

[[deps.Glib_jll]]
deps = ["Artifacts", "GettextRuntime_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE2_jll", "Zlib_jll"]
git-tree-sha1 = "24f6def62397474a297bfcec22384101609142ed"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.86.3+0"

[[deps.Graphics]]
deps = ["Colors", "LinearAlgebra", "NaNMath"]
git-tree-sha1 = "a641238db938fff9b2f60d08ed9030387daf428c"
uuid = "a2bd30eb-e257-5431-a919-1863eab51364"
version = "1.1.3"

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "8a6dbda1fd736d60cc477d99f2e7a042acfa46e8"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.15+0"

[[deps.Graphviz_jll]]
deps = ["Artifacts", "Cairo_jll", "Expat_jll", "JLLWrappers", "Libdl", "Pango_jll", "Pkg"]
git-tree-sha1 = "a5d45833dda71048117e8a9828bef75c03b18b1c"
uuid = "3c863552-8265-54e4-a6dc-903eb78fde85"
version = "2.50.0+1"

[[deps.GridLayoutBase]]
deps = ["GeometryBasics", "InteractiveUtils", "Observables"]
git-tree-sha1 = "93d5c27c8de51687a2c70ec0716e6e76f298416f"
uuid = "3955a311-db13-416c-9275-1d80ed98e5e9"
version = "0.11.2"

[[deps.Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[deps.HDF5]]
deps = ["Compat", "HDF5_jll", "Libdl", "MPIPreferences", "Mmap", "Preferences", "Printf", "Random", "Requires", "UUIDs"]
git-tree-sha1 = "e856eef26cf5bf2b0f95f8f4fc37553c72c8641c"
uuid = "f67ccb44-e63f-5c2f-98bd-6dc0ccc4ba2f"
version = "0.17.2"
weakdeps = ["MPI"]

    [deps.HDF5.extensions]
    MPIExt = "MPI"

[[deps.HDF5_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "LazyArtifacts", "LibCURL_jll", "Libdl", "MPICH_jll", "MPIPreferences", "MPItrampoline_jll", "MicrosoftMPI_jll", "OpenMPI_jll", "OpenSSL_jll", "TOML", "Zlib_jll", "libaec_jll"]
git-tree-sha1 = "e94f84da9af7ce9c6be049e9067e511e17ff89ec"
uuid = "0234f1f7-429e-5d53-9886-15a909be8d59"
version = "1.14.6+0"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll"]
git-tree-sha1 = "f923f9a774fcf3f5cb761bfa43aeadd689714813"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "8.5.1+0"

[[deps.HostCPUFeatures]]
deps = ["BitTwiddlingConvenienceFunctions", "IfElse", "Libdl", "Preferences", "Static"]
git-tree-sha1 = "af9ab7d1f70739a47f03be78771ebda38c3c71bf"
uuid = "3e5b6fbb-0976-4d2c-9146-d79de83f2fb0"
version = "0.1.18"

[[deps.Hwloc]]
deps = ["CEnum", "Hwloc_jll", "Printf"]
git-tree-sha1 = "6a3d80f31ff87bc94ab22a7b8ec2f263f9a6a583"
uuid = "0e44f5e4-bd66-52a0-8798-143a42290a1d"
version = "3.3.0"
weakdeps = ["AbstractTrees"]

    [deps.Hwloc.extensions]
    HwlocTrees = "AbstractTrees"

[[deps.Hwloc_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "XML2_jll", "Xorg_libpciaccess_jll"]
git-tree-sha1 = "157e2e5838984449e44af851a52fe374d56b9ada"
uuid = "e33a78d0-f292-5ffc-b300-72abe9b543c8"
version = "2.13.0+0"

[[deps.HypergeometricFunctions]]
deps = ["LinearAlgebra", "OpenLibm_jll", "SpecialFunctions"]
git-tree-sha1 = "68c173f4f449de5b438ee67ed0c9c748dc31a2ec"
uuid = "34004b35-14d8-5ef3-9330-4cdb6864b03a"
version = "0.3.28"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "179267cfa5e712760cd43dcae385d7ea90cc25a4"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.5"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "d1a86724f81bcd184a38fd284ce183ec067d71a0"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "1.0.0"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "0ee181ec08df7d7c911901ea38baf16f755114dc"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "1.0.0"

[[deps.IfElse]]
git-tree-sha1 = "debdd00ffef04665ccbb3e150747a77560e8fad1"
uuid = "615f187c-cbe4-4ef1-ba3b-2fcf58d6d173"
version = "0.1.1"

[[deps.ImageAxes]]
deps = ["AxisArrays", "ImageBase", "ImageCore", "Reexport", "SimpleTraits"]
git-tree-sha1 = "e12629406c6c4442539436581041d372d69c55ba"
uuid = "2803e5a7-5153-5ecf-9a86-9b4c37f5f5ac"
version = "0.6.12"

[[deps.ImageBase]]
deps = ["ImageCore", "Reexport"]
git-tree-sha1 = "eb49b82c172811fd2c86759fa0553a2221feb909"
uuid = "c817782e-172a-44cc-b673-b171935fbb9e"
version = "0.1.7"

[[deps.ImageCore]]
deps = ["ColorVectorSpace", "Colors", "FixedPointNumbers", "MappedArrays", "MosaicViews", "OffsetArrays", "PaddedViews", "PrecompileTools", "Reexport"]
git-tree-sha1 = "8c193230235bbcee22c8066b0374f63b5683c2d3"
uuid = "a09fc81d-aa75-5fe9-8630-4744c3626534"
version = "0.10.5"

[[deps.ImageIO]]
deps = ["FileIO", "IndirectArrays", "JpegTurbo", "LazyModules", "Netpbm", "OpenEXR", "PNGFiles", "QOI", "Sixel", "TiffImages", "UUIDs", "WebP"]
git-tree-sha1 = "696144904b76e1ca433b886b4e7edd067d76cbf7"
uuid = "82e4d734-157c-48bb-816b-45c225c6df19"
version = "0.6.9"

[[deps.ImageMetadata]]
deps = ["AxisArrays", "ImageAxes", "ImageBase", "ImageCore"]
git-tree-sha1 = "2a81c3897be6fbcde0802a0ebe6796d0562f63ec"
uuid = "bc367c6b-8a6b-528e-b4bd-a4b897500b49"
version = "0.9.10"

[[deps.Imath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "dcc8d0cd653e55213df9b75ebc6fe4a8d3254c65"
uuid = "905a6f67-0a94-5f89-b386-d35d92009cd1"
version = "3.2.2+0"

[[deps.IndirectArrays]]
git-tree-sha1 = "012e604e1c7458645cb8b436f8fba789a51b257f"
uuid = "9b13fd28-a010-5f03-acff-a1bbcff69959"
version = "1.0.0"

[[deps.Inflate]]
git-tree-sha1 = "d1b1b796e47d94588b3757fe84fbf65a5ec4a80d"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.5"

[[deps.IntegerMathUtils]]
git-tree-sha1 = "4c1acff2dc6b6967e7e750633c50bc3b8d83e617"
uuid = "18e54dd8-cb9d-406c-a71d-865a43cbb235"
version = "0.1.3"

[[deps.IntelITT]]
deps = ["ittapi_jll"]
git-tree-sha1 = "74949bfa394cfbe5ca0eee90a348a1dd464704c4"
uuid = "c9b2f978-7543-4802-ae44-75068f23ee64"
version = "0.2.1"

[[deps.IntelOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl"]
git-tree-sha1 = "ec1debd61c300961f98064cfb21287613ad7f303"
uuid = "1d5cc7b8-4909-519e-a0f8-d0f5ad9712d0"
version = "2025.2.0+0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

[[deps.Interpolations]]
deps = ["Adapt", "AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "65d505fa4c0d7072990d659ef3fc086eb6da8208"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.16.2"
weakdeps = ["ForwardDiff", "Unitful"]

    [deps.Interpolations.extensions]
    InterpolationsForwardDiffExt = "ForwardDiff"
    InterpolationsUnitfulExt = "Unitful"

[[deps.IntervalArithmetic]]
deps = ["CRlibm", "MacroTools", "OpenBLASConsistentFPCSR_jll", "Printf", "Random", "RoundingEmulator"]
git-tree-sha1 = "02b61501dbe6da3b927cc25dacd7ce32390ee970"
uuid = "d1acc4aa-44c8-5952-acd4-ba5d80a2a253"
version = "1.0.2"

    [deps.IntervalArithmetic.extensions]
    IntervalArithmeticArblibExt = "Arblib"
    IntervalArithmeticDiffRulesExt = "DiffRules"
    IntervalArithmeticForwardDiffExt = "ForwardDiff"
    IntervalArithmeticIntervalSetsExt = "IntervalSets"
    IntervalArithmeticLinearAlgebraExt = "LinearAlgebra"
    IntervalArithmeticRecipesBaseExt = "RecipesBase"
    IntervalArithmeticSparseArraysExt = "SparseArrays"

    [deps.IntervalArithmetic.weakdeps]
    Arblib = "fb37089c-8514-4489-9461-98f9c8763369"
    DiffRules = "b552c78f-8df3-52c6-915a-8e097449b14b"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
    RecipesBase = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.IntervalSets]]
git-tree-sha1 = "d966f85b3b7a8e49d034d27a189e9a4874b4391a"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.7.13"
weakdeps = ["Random", "RecipesBase", "Statistics"]

    [deps.IntervalSets.extensions]
    IntervalSetsRandomExt = "Random"
    IntervalSetsRecipesBaseExt = "RecipesBase"
    IntervalSetsStatisticsExt = "Statistics"

[[deps.InverseFunctions]]
git-tree-sha1 = "a779299d77cd080bf77b97535acecd73e1c5e5cb"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.17"
weakdeps = ["Dates", "Test"]

    [deps.InverseFunctions.extensions]
    InverseFunctionsDatesExt = "Dates"
    InverseFunctionsTestExt = "Test"

[[deps.IrrationalConstants]]
git-tree-sha1 = "b2d91fe939cae05960e760110b328288867b5758"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.6"

[[deps.Isoband]]
deps = ["isoband_jll"]
git-tree-sha1 = "f9b6d97355599074dc867318950adaa6f9946137"
uuid = "f1662d9f-8043-43de-a69a-05efc1cc6ff4"
version = "0.1.1"

[[deps.IterTools]]
git-tree-sha1 = "42d5f897009e7ff2cf88db414a389e5ed1bdd023"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.10.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "0533e564aae234aff59ab625543145446d8b6ec2"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.7.1"

[[deps.JSON]]
deps = ["Dates", "Logging", "Parsers", "PrecompileTools", "StructUtils", "UUIDs", "Unicode"]
git-tree-sha1 = "b3ad4a0255688dcb895a52fafbaae3023b588a90"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "1.4.0"

    [deps.JSON.extensions]
    JSONArrowExt = ["ArrowTypes"]

    [deps.JSON.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"

[[deps.Jieko]]
deps = ["ExproniconLite"]
git-tree-sha1 = "2f05ed29618da60c06a87e9c033982d4f71d0b6c"
uuid = "ae98c720-c025-4a4a-838c-29b094483192"
version = "0.2.1"

[[deps.JpegTurbo]]
deps = ["CEnum", "FileIO", "ImageCore", "JpegTurbo_jll", "TOML"]
git-tree-sha1 = "9496de8fb52c224a2e3f9ff403947674517317d9"
uuid = "b835a17e-a41a-41e7-81f0-2f016b05efe0"
version = "0.1.6"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "b6893345fd6658c8e475d40155789f4860ac3b21"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.1.4+0"

[[deps.JuliaSyntax]]
git-tree-sha1 = "937da4713526b96ac9a178e2035019d3b78ead4a"
uuid = "70703baa-626e-46a2-a12c-08ffd08c73b4"
version = "0.4.10"

[[deps.JuliaSyntaxHighlighting]]
deps = ["JuliaSyntax", "StyledStrings"]
git-tree-sha1 = "19ecee1ea81c60156486a92b062e443b6bba60b7"
uuid = "ac6e5ff7-fb65-4e79-a425-ec3bc9c03011"
version = "0.1.0"

[[deps.KernelAbstractions]]
deps = ["Adapt", "Atomix", "InteractiveUtils", "MacroTools", "PrecompileTools", "Requires", "StaticArrays", "UUIDs"]
git-tree-sha1 = "fb14a863240d62fbf5922bf9f8803d7df6c62dc8"
uuid = "63c18a36-062a-441e-b654-da1e3ab1ce7c"
version = "0.9.40"
weakdeps = ["EnzymeCore", "LinearAlgebra", "SparseArrays"]

    [deps.KernelAbstractions.extensions]
    EnzymeExt = "EnzymeCore"
    LinearAlgebraExt = "LinearAlgebra"
    SparseArraysExt = "SparseArrays"

[[deps.KernelDensity]]
deps = ["Distributions", "DocStringExtensions", "FFTA", "Interpolations", "StatsBase"]
git-tree-sha1 = "4260cfc991b8885bf747801fb60dd4503250e478"
uuid = "5ab0869b-81aa-558d-bb23-cbf5423bbe9b"
version = "0.6.11"

[[deps.Kronecker]]
deps = ["LinearAlgebra", "NamedDims", "SparseArrays", "StatsBase"]
git-tree-sha1 = "9253429e28cceae6e823bec9ffde12460d79bb38"
uuid = "2c470bb0-bcc8-11e8-3dad-c9649493f05e"
version = "0.5.5"

[[deps.LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "059aabebaa7c82ccb853dd4a0ee9d17796f7e1bc"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.3+0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "aaafe88dccbd957a8d82f7d05be9b69172e0cee3"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "4.0.1+0"

[[deps.LIKWID]]
deps = ["CEnum", "Libdl", "OrderedCollections", "PrettyTables", "Unitful"]
git-tree-sha1 = "b21dcbf20aca355bd2e1039d9731dd1d879cc0d4"
uuid = "bf22376a-e803-4184-b2ed-56326e3bff83"
version = "0.4.5"

[[deps.LLVMOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "eb62a3deb62fc6d8822c0c4bef73e4412419c5d8"
uuid = "1d63c593-3942-5779-bab2-d838dc0a180e"
version = "18.1.8+0"

[[deps.LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1c602b1127f4751facb671441ca72715cc95938a"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.3+0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "dda21b8cbd6a6c40d9d02a73230f9d70fed6918c"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.4.0"

[[deps.Latexify]]
deps = ["Format", "Ghostscript_jll", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "OrderedCollections", "Requires"]
git-tree-sha1 = "44f93c47f9cd6c7e431f2f2091fcba8f01cd7e8f"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.16.10"

    [deps.Latexify.extensions]
    DataFramesExt = "DataFrames"
    SparseArraysExt = "SparseArrays"
    SymEngineExt = "SymEngine"
    TectonicExt = "tectonic_jll"

    [deps.Latexify.weakdeps]
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    SymEngine = "123dc426-2d89-5057-bbad-38513e3affd8"
    tectonic_jll = "d7dd28d6-a5e6-559c-9131-7eb760cdacc5"

[[deps.LayoutPointers]]
deps = ["ArrayInterface", "LinearAlgebra", "ManualMemory", "SIMDTypes", "Static", "StaticArrayInterface"]
git-tree-sha1 = "a9eaadb366f5493a5654e843864c13d8b107548c"
uuid = "10f19ff3-798f-405d-979b-55457f8fc047"
version = "0.1.17"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"
version = "1.11.0"

[[deps.LazyModules]]
git-tree-sha1 = "a560dd966b386ac9ae60bdd3a3d3a326062d3c3e"
uuid = "8cdb02fc-e678-4876-92c5-9defec4f444e"
version = "0.3.1"

[[deps.LeftChildRightSiblingTrees]]
deps = ["AbstractTrees"]
git-tree-sha1 = "95ba48564903b43b2462318aa243ee79d81135ff"
uuid = "1d6d02ad-be62-4b6b-8a6d-2f90e265016e"
version = "0.2.1"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.6.0+0"

[[deps.LibGit2]]
deps = ["Base64", "LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"
version = "1.11.0"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.7.2+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.0+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"
version = "1.11.0"

[[deps.Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c8da7e6a91781c41a863611c7e966098d783c57a"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.4.7+0"

[[deps.Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "d36c21b9e7c172a44a10484125024495e2625ac0"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.7.1+1"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "be484f5c92fad0bd8acfef35fe017900b0b73809"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.18.0+0"

[[deps.Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "97bbca976196f2a1eb9607131cb108c69ec3f8a6"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.41.3+0"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "XZ_jll", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "f04133fe05eff1667d2054c53d59f9122383fe05"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.7.2+0"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "d0205286d9eceadc518742860bf23f703779a3d6"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.41.3+0"

[[deps.LightXML]]
deps = ["Libdl", "XML2_jll"]
git-tree-sha1 = "aa971a09f0f1fe92fe772713a564aa48abe510df"
uuid = "9c8b4983-aa76-5018-a973-4c85ecc9e179"
version = "0.9.3"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.11.0"

[[deps.LinearMaps]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "7f6be2e4cdaaf558623d93113d6ddade7b916209"
uuid = "7a12625a-238d-50fd-b39a-03d52299707e"
version = "3.11.4"
weakdeps = ["ChainRulesCore", "SparseArrays", "Statistics"]

    [deps.LinearMaps.extensions]
    LinearMapsChainRulesCoreExt = "ChainRulesCore"
    LinearMapsSparseArraysExt = "SparseArrays"
    LinearMapsStatisticsExt = "Statistics"

[[deps.LinuxPerf]]
deps = ["PrettyTables", "Printf"]
git-tree-sha1 = "793e5feace327e3fcbc63168fe6e01e9a73abc8c"
uuid = "b4c46c6c-4fb0-484d-a11a-41bc3392d094"
version = "0.4.2"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "13ca9e2586b89836fd20cccf56e57e2b9ae7f38f"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.29"

    [deps.LogExpFunctions.extensions]
    LogExpFunctionsChainRulesCoreExt = "ChainRulesCore"
    LogExpFunctionsChangesOfVariablesExt = "ChangesOfVariables"
    LogExpFunctionsInverseFunctionsExt = "InverseFunctions"

    [deps.LogExpFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ChangesOfVariables = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"
version = "1.11.0"

[[deps.LoggingExtras]]
deps = ["Dates", "Logging"]
git-tree-sha1 = "f00544d95982ea270145636c181ceda21c4e2575"
uuid = "e6f89c97-d47a-5376-807f-9c37f3926c36"
version = "1.2.0"

[[deps.LoopVectorization]]
deps = ["ArrayInterface", "CPUSummary", "CloseOpenIntervals", "DocStringExtensions", "HostCPUFeatures", "IfElse", "LayoutPointers", "LinearAlgebra", "OffsetArrays", "PolyesterWeave", "PrecompileTools", "SIMDTypes", "SLEEFPirates", "Static", "StaticArrayInterface", "ThreadingUtilities", "UnPack", "VectorizationBase"]
git-tree-sha1 = "a9fc7883eb9b5f04f46efb9a540833d1fad974b3"
uuid = "bdcacae8-1622-11e9-2a5c-532679323890"
version = "0.12.173"

    [deps.LoopVectorization.extensions]
    ForwardDiffExt = ["ChainRulesCore", "ForwardDiff"]
    ForwardDiffNNlibExt = ["ForwardDiff", "NNlib"]
    SpecialFunctionsExt = "SpecialFunctions"

    [deps.LoopVectorization.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    NNlib = "872c559c-99b0-510c-b3b7-b6c96a88d5cd"
    SpecialFunctions = "276daf66-3868-5448-9aa4-cd146d93841b"

[[deps.MIMEs]]
git-tree-sha1 = "c64d943587f7187e751162b3b84445bbbd79f691"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "1.1.0"

[[deps.MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "oneTBB_jll"]
git-tree-sha1 = "282cadc186e7b2ae0eeadbd7a4dffed4196ae2aa"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2025.2.0+0"

[[deps.MPI]]
deps = ["Distributed", "DocStringExtensions", "Libdl", "MPIABI_jll", "MPICH_jll", "MPIPreferences", "MPItrampoline_jll", "MicrosoftMPI_jll", "OpenMPI_jll", "PkgVersion", "PrecompileTools", "Requires", "Serialization", "Sockets"]
git-tree-sha1 = "f53e40f779b860bd813441a3b6bc434f48c99ee1"
uuid = "da04e1cc-30fd-572f-bb4f-1f8673147195"
version = "0.20.24"

    [deps.MPI.extensions]
    AMDGPUExt = "AMDGPU"
    CUDAExt = "CUDA"

    [deps.MPI.weakdeps]
    AMDGPU = "21141c5a-9bdb-4563-92ae-f87d6854732e"
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"

[[deps.MPIABI_jll]]
deps = ["Artifacts", "Hwloc_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "MPIPreferences", "TOML"]
git-tree-sha1 = "fdc0f7ca9e7e645d1114b93c9eee98f352b59a0c"
uuid = "b5ada748-db0f-5fc0-8972-9331c762740c"
version = "0.1.3+0"

[[deps.MPICH_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Hwloc_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "MPIPreferences", "TOML"]
git-tree-sha1 = "9341048b9f723f2ae2a72a5269ac2f15f80534dc"
uuid = "7cb0a576-ebde-5e09-9194-50597f1243b4"
version = "4.3.2+0"

[[deps.MPIPreferences]]
deps = ["Libdl", "Preferences"]
git-tree-sha1 = "8e98d5d80b87403c311fd51e8455d4546ba7a5f8"
uuid = "3da0fdf6-3ccc-4f1b-acd9-58baa6c99267"
version = "0.1.12"

[[deps.MPItrampoline_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "MPIPreferences", "TOML"]
git-tree-sha1 = "36c2d142e7d45fb98b5f83925213feb3292ca348"
uuid = "f1f71cc9-e9ae-5b93-9b94-4fe0e1ad3748"
version = "5.5.5+0"

[[deps.MacroTools]]
git-tree-sha1 = "1e0228a030642014fe5cfe68c2c0a818f9e3f522"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.16"

[[deps.Makie]]
deps = ["Animations", "Base64", "CRC32c", "ColorBrewer", "ColorSchemes", "ColorTypes", "Colors", "ComputePipeline", "Contour", "Dates", "DelaunayTriangulation", "Distributions", "DocStringExtensions", "Downloads", "FFMPEG_jll", "FileIO", "FilePaths", "FixedPointNumbers", "Format", "FreeType", "FreeTypeAbstraction", "GeometryBasics", "GridLayoutBase", "ImageBase", "ImageIO", "InteractiveUtils", "Interpolations", "IntervalSets", "InverseFunctions", "Isoband", "KernelDensity", "LaTeXStrings", "LinearAlgebra", "MacroTools", "Markdown", "MathTeXEngine", "Observables", "OffsetArrays", "PNGFiles", "Packing", "Pkg", "PlotUtils", "PolygonOps", "PrecompileTools", "Printf", "REPL", "Random", "RelocatableFolders", "Scratch", "ShaderAbstractions", "Showoff", "SignedDistanceFields", "SparseArrays", "Statistics", "StatsBase", "StatsFuns", "StructArrays", "TriplotBase", "UnicodeFun", "Unitful"]
git-tree-sha1 = "68af66ec16af8b152309310251ecb4fbfe39869f"
uuid = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
version = "0.24.9"

    [deps.Makie.extensions]
    MakieDynamicQuantitiesExt = "DynamicQuantities"

    [deps.Makie.weakdeps]
    DynamicQuantities = "06fc5a27-2a28-4c7c-a15d-362465fb6821"

[[deps.ManualMemory]]
git-tree-sha1 = "bcaef4fc7a0cfe2cba636d84cda54b5e4e4ca3cd"
uuid = "d125e4d3-2237-4719-b19c-fa641b8a4667"
version = "0.1.8"

[[deps.MappedArrays]]
git-tree-sha1 = "0ee4497a4e80dbd29c058fcee6493f5219556f40"
uuid = "dbb5928d-eab1-5f90-85c2-b9b0edb7c900"
version = "0.4.3"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.MathTeXEngine]]
deps = ["AbstractTrees", "Automa", "DataStructures", "FreeTypeAbstraction", "GeometryBasics", "LaTeXStrings", "REPL", "RelocatableFolders", "UnicodeFun"]
git-tree-sha1 = "7eb8cdaa6f0e8081616367c10b31b9d9b34bb02a"
uuid = "0a4f8689-d25c-4efe-a92b-7142dfc1aa53"
version = "0.6.7"

[[deps.MaybeInplace]]
deps = ["ArrayInterface", "LinearAlgebra", "MacroTools"]
git-tree-sha1 = "54e2fdc38130c05b42be423e90da3bade29b74bd"
uuid = "bb5d69b7-63fc-4a16-80bd-7e42200c7bdb"
version = "0.1.4"
weakdeps = ["SparseArrays"]

    [deps.MaybeInplace.extensions]
    MaybeInplaceSparseArraysExt = "SparseArrays"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.6+0"

[[deps.MicrosoftMPI_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bc95bf4149bf535c09602e3acdf950d9b4376227"
uuid = "9237b28f-5490-5468-be7b-bb81f5f5e6cf"
version = "10.1.4+3"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "ec4f7fbeab05d7747bdf98eb74d130a2a2ed298d"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.2.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"
version = "1.11.0"

[[deps.MosaicViews]]
deps = ["MappedArrays", "OffsetArrays", "PaddedViews", "StackViews"]
git-tree-sha1 = "7b86a5d4d70a9f5cdf2dacb3cbe6d251d1a61dbe"
uuid = "e94cdb99-869f-56ef-bcf0-1ae2bcbe0389"
version = "0.3.4"

[[deps.Moshi]]
deps = ["ExproniconLite", "Jieko"]
git-tree-sha1 = "53f817d3e84537d84545e0ad749e483412dd6b2a"
uuid = "2e0e35c7-a2e4-4343-998d-7ef72827ed2d"
version = "0.3.7"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2023.12.12"

[[deps.MuladdMacro]]
git-tree-sha1 = "cac9cc5499c25554cba55cd3c30543cff5ca4fab"
uuid = "46d2c3a1-f734-5fdb-9937-b9b9aeba4221"
version = "0.2.4"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "9b8215b1ee9e78a293f99797cd31375471b2bcae"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.1.3"

[[deps.NamedDims]]
deps = ["LinearAlgebra", "Statistics"]
git-tree-sha1 = "f9e4a49ecd1ea2eccfb749a506fa882c094152b4"
uuid = "356022a1-0364-5f58-8944-0da4b18d706f"
version = "1.2.3"

    [deps.NamedDims.extensions]
    AbstractFFTsExt = "AbstractFFTs"
    ChainRulesCoreExt = "ChainRulesCore"
    CovarianceEstimationExt = "CovarianceEstimation"
    TrackerExt = "Tracker"

    [deps.NamedDims.weakdeps]
    AbstractFFTs = "621f4979-c628-5d54-868e-fcf4e3e8185c"
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    CovarianceEstimation = "587fd27a-f159-11e8-2dae-1979310e6154"
    Requires = "ae029012-a4dd-5104-9daa-d747884805df"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"

[[deps.Netpbm]]
deps = ["FileIO", "ImageCore", "ImageMetadata"]
git-tree-sha1 = "d92b107dbb887293622df7697a2223f9f8176fcd"
uuid = "f09324ee-3d7c-5217-9330-fc30815ba969"
version = "1.1.1"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.NodesAndModes]]
deps = ["DelimitedFiles", "LinearAlgebra", "SpecialFunctions", "StaticArrays"]
git-tree-sha1 = "ee6719b4ed5fd08b654017648bf5fa2e2dc8f1ec"
uuid = "7aca2e03-f7e2-4192-9ec8-f4ca66d597fb"
version = "1.1.0"

[[deps.NonlinearSolveBase]]
deps = ["ADTypes", "Adapt", "ArrayInterface", "CommonSolve", "Compat", "ConcreteStructs", "DifferentiationInterface", "EnzymeCore", "FastClosures", "LinearAlgebra", "LogExpFunctions", "Markdown", "MaybeInplace", "PreallocationTools", "Preferences", "Printf", "RecursiveArrayTools", "SciMLBase", "SciMLJacobianOperators", "SciMLLogging", "SciMLOperators", "SciMLStructures", "Setfield", "StaticArraysCore", "SymbolicIndexingInterface", "TimerOutputs"]
git-tree-sha1 = "4f595a0977d6e048fa1e3c382b088b950f8c7934"
uuid = "be0214bd-f91f-a760-ac4e-3421ce2b2da0"
version = "2.15.0"

    [deps.NonlinearSolveBase.extensions]
    NonlinearSolveBaseBandedMatricesExt = "BandedMatrices"
    NonlinearSolveBaseChainRulesCoreExt = "ChainRulesCore"
    NonlinearSolveBaseEnzymeExt = ["ChainRulesCore", "Enzyme"]
    NonlinearSolveBaseForwardDiffExt = "ForwardDiff"
    NonlinearSolveBaseLineSearchExt = "LineSearch"
    NonlinearSolveBaseLinearSolveExt = "LinearSolve"
    NonlinearSolveBaseMooncakeExt = "Mooncake"
    NonlinearSolveBaseReverseDiffExt = "ReverseDiff"
    NonlinearSolveBaseSparseArraysExt = "SparseArrays"
    NonlinearSolveBaseSparseMatrixColoringsExt = "SparseMatrixColorings"
    NonlinearSolveBaseTrackerExt = "Tracker"

    [deps.NonlinearSolveBase.weakdeps]
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    Enzyme = "7da242da-08ed-463a-9acd-ee780be4f1d9"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    LineSearch = "87fe0de2-c867-4266-b59a-2f0a94fc965b"
    LinearSolve = "7ed4a6bd-45f5-4d41-b270-4a48e9bafcae"
    Mooncake = "da2b9cff-9c12-43a0-ae48-6db2b0edb7d6"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    SparseMatrixColorings = "0a514795-09f3-496d-8182-132a7b665d35"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"

[[deps.Observables]]
git-tree-sha1 = "7438a59546cf62428fc9d1bc94729146d37a7225"
uuid = "510215fc-4207-5dde-b226-833fc4488ee2"
version = "0.5.5"

[[deps.Octavian]]
deps = ["CPUSummary", "IfElse", "LoopVectorization", "ManualMemory", "PolyesterWeave", "PrecompileTools", "Static", "StaticArrayInterface", "ThreadingUtilities", "VectorizationBase"]
git-tree-sha1 = "21d5b4557036561266a7578ae3f9914d18ae5685"
uuid = "6fd5a793-0b7e-452c-907f-f8bfe9c57db4"
version = "0.3.29"

    [deps.Octavian.extensions]
    ForwardDiffExt = "ForwardDiff"
    HyperDualNumbersExt = "HyperDualNumbers"

    [deps.Octavian.weakdeps]
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    HyperDualNumbers = "50ceba7f-c3ee-5a84-a6e8-3ad40456ec97"

[[deps.OffsetArrays]]
git-tree-sha1 = "117432e406b5c023f665fa73dc26e79ec3630151"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.17.0"
weakdeps = ["Adapt"]

    [deps.OffsetArrays.extensions]
    OffsetArraysAdaptExt = "Adapt"

[[deps.Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "b6aa4566bb7ae78498a5e68943863fa8b5231b59"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.6+0"

[[deps.OpenBLASConsistentFPCSR_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "f2b3b9e52a5eb6a3434c8cca67ad2dde011194f4"
uuid = "6cdc7f73-28fd-5e50-80fb-958a8875b1af"
version = "0.3.30+0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.27+1"

[[deps.OpenEXR]]
deps = ["Colors", "FileIO", "OpenEXR_jll"]
git-tree-sha1 = "97db9e07fe2091882c765380ef58ec553074e9c7"
uuid = "52e1d378-f018-4a11-a4be-720524705ac7"
version = "0.3.3"

[[deps.OpenEXR_jll]]
deps = ["Artifacts", "Imath_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "df9b7c88c2e7a2e77146223c526bf9e236d5f450"
uuid = "18a262bb-aa17-5467-a713-aee519bc75cb"
version = "3.4.4+0"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.5+0"

[[deps.OpenMPI_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Hwloc_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "MPIPreferences", "TOML", "Zlib_jll"]
git-tree-sha1 = "2f3d05e419b6125ffe06e55784102e99325bdbe2"
uuid = "fe0851c0-eecd-5654-98d4-656369965a5c"
version = "5.0.10+0"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c9cbeda6aceffc52d8a0017e71db27c7a7c0beaf"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.5.5+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1346c9208249809840c91b26703912dff463d335"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.6+0"

[[deps.Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e2bb57a313a74b8104064b7efd01406c0a50d2ff"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.6.1+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "05868e21324cede2207c6f0f466b4bfef6d5e7ee"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.8.1"

[[deps.OrdinaryDiffEqCore]]
deps = ["ADTypes", "Accessors", "Adapt", "ArrayInterface", "ConcreteStructs", "DataStructures", "DiffEqBase", "DocStringExtensions", "EnumX", "EnzymeCore", "FastBroadcast", "FastClosures", "FastPower", "FillArrays", "FunctionWrappersWrappers", "InteractiveUtils", "LinearAlgebra", "Logging", "MacroTools", "MuladdMacro", "Polyester", "PrecompileTools", "Preferences", "Random", "RecursiveArrayTools", "Reexport", "SciMLBase", "SciMLLogging", "SciMLOperators", "SciMLStructures", "Static", "StaticArrayInterface", "StaticArraysCore", "SymbolicIndexingInterface", "TruncatedStacktraces"]
git-tree-sha1 = "9b8819db9b1ce0633a990fb2384a0fdcbb27fa14"
uuid = "bbf590c4-e513-4bbe-9b18-05decba2e5d8"
version = "3.20.0"

    [deps.OrdinaryDiffEqCore.extensions]
    OrdinaryDiffEqCoreMooncakeExt = "Mooncake"
    OrdinaryDiffEqCoreSparseArraysExt = "SparseArrays"

    [deps.OrdinaryDiffEqCore.weakdeps]
    Mooncake = "da2b9cff-9c12-43a0-ae48-6db2b0edb7d6"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.OrdinaryDiffEqLowStorageRK]]
deps = ["Adapt", "DiffEqBase", "FastBroadcast", "MuladdMacro", "OrdinaryDiffEqCore", "Polyester", "PrecompileTools", "Preferences", "RecursiveArrayTools", "Reexport", "SciMLBase", "Static", "StaticArrays"]
git-tree-sha1 = "bd032c73716bc538033af041ca8903df6c813bfd"
uuid = "b0944070-b475-4768-8dec-fb6eb410534d"
version = "1.12.0"

[[deps.P4est]]
deps = ["CEnum", "MPI", "MPIPreferences", "P4est_jll", "Preferences", "Reexport", "UUIDs"]
git-tree-sha1 = "6a924bc3d05ebb09de7e8294a30c022461a44720"
uuid = "7d669430-f675-4ae7-b43e-fab78ec5a902"
version = "0.4.13"

[[deps.P4est_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl", "MPICH_jll", "MPIPreferences", "MPItrampoline_jll", "MicrosoftMPI_jll", "OpenMPI_jll", "Pkg", "TOML", "Zlib_jll"]
git-tree-sha1 = "70c2d9a33b8810198314a5722ee3e9520110b28d"
uuid = "6b5a15aa-cf52-5330-8376-5e5d90283449"
version = "2.8.1+2"

[[deps.PCRE2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "efcefdf7-47ab-520b-bdef-62a2eaa19f15"
version = "10.42.0+1"

[[deps.PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "e4cff168707d441cd6bf3ff7e4832bdf34278e4a"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.37"
weakdeps = ["StatsBase"]

    [deps.PDMats.extensions]
    StatsBaseExt = "StatsBase"

[[deps.PNGFiles]]
deps = ["Base64", "CEnum", "ImageCore", "IndirectArrays", "OffsetArrays", "libpng_jll"]
git-tree-sha1 = "cf181f0b1e6a18dfeb0ee8acc4a9d1672499626c"
uuid = "f57f5aa1-a3ce-4bc8-8ab9-96f992907883"
version = "0.4.4"

[[deps.PProf]]
deps = ["AbstractTrees", "CodecZlib", "EnumX", "FlameGraphs", "Libdl", "OrderedCollections", "Profile", "ProgressMeter", "ProtoBuf", "pprof_jll"]
git-tree-sha1 = "2b62c1a1fde38c21023d5786cd37ef95d9d7acd4"
uuid = "e4faabce-9ead-11e9-39d9-4379958e3056"
version = "3.2.0"

[[deps.Packing]]
deps = ["GeometryBasics"]
git-tree-sha1 = "bc5bf2ea3d5351edf285a06b0016788a121ce92c"
uuid = "19eb6ba3-879d-56ad-ad62-d5c202156566"
version = "0.5.1"

[[deps.PaddedViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "0fac6313486baae819364c52b4f483450a9d793f"
uuid = "5432bcbf-9aad-5242-b902-cca2824c8663"
version = "0.5.12"

[[deps.Pango_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "FriBidi_jll", "Glib_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "0662b083e11420952f2e62e17eddae7fc07d5997"
uuid = "36c8627f-9965-5494-a995-c6b170f724f3"
version = "1.57.0+0"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "7d2f8f21da5db6a806faf7b9b292296da42b2810"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.3"

[[deps.PathIntersections]]
deps = ["ForwardDiff", "GaussQuadrature", "LinearAlgebra", "SparseArrays", "StaticArrays"]
git-tree-sha1 = "730201a293befb624c7b3d76ccbd326b0c689067"
uuid = "4c1a95c7-462a-4a7e-b284-959c63fbf1dc"
version = "0.3.0"

[[deps.Pixman_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "LLVMOpenMP_jll", "Libdl"]
git-tree-sha1 = "db76b1ecd5e9715f3d043cec13b2ec93ce015d53"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.44.2+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "Random", "SHA", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.11.0"
weakdeps = ["REPL"]

    [deps.Pkg.extensions]
    REPLExt = "REPL"

[[deps.PkgVersion]]
deps = ["Pkg"]
git-tree-sha1 = "f9501cc0430a26bc3d156ae1b5b0c1b47af4d6da"
uuid = "eebad327-c553-4316-9ea0-9fa01ccd7688"
version = "0.3.3"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "PrecompileTools", "Printf", "Random", "Reexport", "StableRNGs", "Statistics"]
git-tree-sha1 = "26ca162858917496748aad52bb5d3be4d26a228a"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.4.4"

[[deps.PlutoTeachingTools]]
deps = ["Downloads", "HypertextLiteral", "Latexify", "Markdown", "PlutoUI"]
git-tree-sha1 = "90b41ced6bacd8c01bd05da8aed35c5458891749"
uuid = "661c6b06-c737-4d37-b85c-46df65de6f69"
version = "0.4.7"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "Downloads", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "3ac7038a98ef6977d44adeadc73cc6f596c08109"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.79"

[[deps.Polyester]]
deps = ["ArrayInterface", "BitTwiddlingConvenienceFunctions", "CPUSummary", "IfElse", "ManualMemory", "PolyesterWeave", "Static", "StaticArrayInterface", "StrideArraysCore", "ThreadingUtilities"]
git-tree-sha1 = "16bbc30b5ebea91e9ce1671adc03de2832cff552"
uuid = "f517fe37-dbe3-4b94-8317-1923a5111588"
version = "0.7.19"

[[deps.PolyesterWeave]]
deps = ["BitTwiddlingConvenienceFunctions", "CPUSummary", "IfElse", "Static", "ThreadingUtilities"]
git-tree-sha1 = "645bed98cd47f72f67316fd42fc47dee771aefcd"
uuid = "1d0040c9-8b98-4ee7-8388-3f51789ca0ad"
version = "0.2.2"

[[deps.PolygonOps]]
git-tree-sha1 = "77b3d3605fc1cd0b42d95eba87dfcd2bf67d5ff6"
uuid = "647866c9-e3ac-4575-94e7-e3d426903924"
version = "0.1.2"

[[deps.PolynomialBases]]
deps = ["ArgCheck", "AutoHashEquals", "FFTW", "FastGaussQuadrature", "LinearAlgebra", "Requires", "SimpleUnPack", "SpecialFunctions"]
git-tree-sha1 = "d04bec789dce5ff61e8f128b6aee0eda09a3855f"
uuid = "c74db56a-226d-5e98-8bb0-a6049094aeea"
version = "0.4.25"

[[deps.PreallocationTools]]
deps = ["Adapt", "ArrayInterface", "PrecompileTools"]
git-tree-sha1 = "dc8d6bde5005a0eac05ae8faf1eceaaca166cfa4"
uuid = "d236fae5-4411-538c-8e31-a6e3d9e00b46"
version = "1.1.2"

    [deps.PreallocationTools.extensions]
    PreallocationToolsForwardDiffExt = "ForwardDiff"
    PreallocationToolsReverseDiffExt = "ReverseDiff"
    PreallocationToolsSparseConnectivityTracerExt = "SparseConnectivityTracer"

    [deps.PreallocationTools.weakdeps]
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
    SparseConnectivityTracer = "9f842d2f-2579-4b1d-911e-f412cf18a3f5"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "5aa36f7049a63a1528fe8f7c3f2113413ffd4e1f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.1"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "8b770b60760d4451834fe79dd483e318eee709c4"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.5.2"

[[deps.PrettyTables]]
deps = ["Crayons", "LaTeXStrings", "Markdown", "PrecompileTools", "Printf", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "1101cd475833706e4d0e7b122218257178f48f34"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "2.4.0"

[[deps.Primes]]
deps = ["IntegerMathUtils"]
git-tree-sha1 = "25cdd1d20cd005b52fc12cb6be3f75faaf59bb9b"
uuid = "27ebfcd6-29c5-5fa9-bf4b-fb8fc14df3ae"
version = "0.5.7"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"
version = "1.11.0"

[[deps.Profile]]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"
version = "1.11.0"

[[deps.ProfileCanvas]]
deps = ["Base64", "JSON", "Pkg", "Profile", "REPL"]
git-tree-sha1 = "990016fb1508b0726a70039f39569720d054c78d"
uuid = "efd6af41-a80b-495e-886c-e51b0c7d77a3"
version = "0.1.7"

[[deps.ProgressBars]]
deps = ["Printf"]
git-tree-sha1 = "b437cdb0385ed38312d91d9c00c20f3798b30256"
uuid = "49802e3a-d2f1-5c88-81d8-b72133a6f568"
version = "1.5.1"

[[deps.ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "fbb92c6c56b34e1a2c4c36058f68f332bec840e7"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.11.0"

[[deps.ProtoBuf]]
deps = ["BufferedStreams", "EnumX", "TOML"]
git-tree-sha1 = "da18083a52d9d57bbe6dadaacad39731e5f7be39"
uuid = "3349acd9-ac6a-5e09-bcdb-63829b23a429"
version = "1.3.0"

[[deps.PtrArrays]]
git-tree-sha1 = "4fbbafbc6251b883f4d2705356f3641f3652a7fe"
uuid = "43287f4e-b6f4-7ad1-bb20-aadabca52c3d"
version = "1.4.0"

[[deps.QOI]]
deps = ["ColorTypes", "FileIO", "FixedPointNumbers"]
git-tree-sha1 = "472daaa816895cb7aee81658d4e7aec901fa1106"
uuid = "4b34888f-f399-49d4-9bb3-47ed5cae4e65"
version = "1.0.2"

[[deps.QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "9da16da70037ba9d701192e27befedefb91ec284"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.11.2"

    [deps.QuadGK.extensions]
    QuadGKEnzymeExt = "Enzyme"

    [deps.QuadGK.weakdeps]
    Enzyme = "7da242da-08ed-463a-9acd-ee780be4f1d9"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "StyledStrings", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"
version = "1.11.0"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
version = "1.11.0"

[[deps.RangeArrays]]
git-tree-sha1 = "b9039e93773ddcfc828f12aadf7115b4b4d225f5"
uuid = "b3c3ace0-ae52-54e7-9d0b-2c1406fd6b9d"
version = "0.3.2"

[[deps.Ratios]]
deps = ["Requires"]
git-tree-sha1 = "1342a47bf3260ee108163042310d26f2be5ec90b"
uuid = "c84ed2f1-dad5-54f0-aa8e-dbefe2724439"
version = "0.4.5"
weakdeps = ["FixedPointNumbers"]

    [deps.Ratios.extensions]
    RatiosFixedPointNumbersExt = "FixedPointNumbers"

[[deps.RecipesBase]]
deps = ["PrecompileTools"]
git-tree-sha1 = "5c3d09cc4f31f5fc6af001c250bf1278733100ff"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.3.4"

[[deps.RecursiveArrayTools]]
deps = ["Adapt", "ArrayInterface", "DocStringExtensions", "GPUArraysCore", "LinearAlgebra", "PrecompileTools", "RecipesBase", "StaticArraysCore", "SymbolicIndexingInterface"]
git-tree-sha1 = "18d2a6fd1ea9a8205cadb3a5704f8e51abdd748b"
uuid = "731186ca-8d62-57ce-b412-fbd966d074cd"
version = "3.48.0"

    [deps.RecursiveArrayTools.extensions]
    RecursiveArrayToolsFastBroadcastExt = "FastBroadcast"
    RecursiveArrayToolsForwardDiffExt = "ForwardDiff"
    RecursiveArrayToolsKernelAbstractionsExt = "KernelAbstractions"
    RecursiveArrayToolsMeasurementsExt = "Measurements"
    RecursiveArrayToolsMonteCarloMeasurementsExt = "MonteCarloMeasurements"
    RecursiveArrayToolsReverseDiffExt = ["ReverseDiff", "Zygote"]
    RecursiveArrayToolsSparseArraysExt = ["SparseArrays"]
    RecursiveArrayToolsStatisticsExt = "Statistics"
    RecursiveArrayToolsStructArraysExt = "StructArrays"
    RecursiveArrayToolsTablesExt = ["Tables"]
    RecursiveArrayToolsTrackerExt = "Tracker"
    RecursiveArrayToolsZygoteExt = "Zygote"

    [deps.RecursiveArrayTools.weakdeps]
    FastBroadcast = "7034ab61-46d4-4ed7-9d0f-46aef9175898"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    KernelAbstractions = "63c18a36-062a-441e-b654-da1e3ab1ce7c"
    Measurements = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
    MonteCarloMeasurements = "0987c9cc-fe09-11e8-30f0-b96dd679fdca"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
    StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
    Tables = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"
    Zygote = "e88e6eb3-aa80-5325-afca-941959d7151f"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.RelocatableFolders]]
deps = ["SHA", "Scratch"]
git-tree-sha1 = "ffdaf70d81cf6ff22c2b6e733c900c3321cab864"
uuid = "05181044-ff0b-4ac5-8273-598c1e38db00"
version = "1.0.1"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "62389eeff14780bfe55195b7204c0d8738436d64"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.1"

[[deps.Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "5b3d50eb374cea306873b371d3f8d3915a018f0b"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.9.0"

[[deps.Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "58cdd8fb2201a6267e1db87ff148dd6c1dbd8ad8"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.5.1+0"

[[deps.RoundingEmulator]]
git-tree-sha1 = "40b9edad2e5287e05bd413a38f61a8ff55b9557b"
uuid = "5eaf0fd0-dfba-4ccb-bf02-d820a40db705"
version = "0.2.1"

[[deps.RuntimeGeneratedFunctions]]
deps = ["ExprTools", "SHA", "Serialization"]
git-tree-sha1 = "7257165d5477fd1025f7cb656019dcb6b0512c38"
uuid = "7e49a35a-f44a-4d26-94aa-eba1b4ca6b47"
version = "0.5.17"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SIMD]]
deps = ["PrecompileTools"]
git-tree-sha1 = "e24dc23107d426a096d3eae6c165b921e74c18e4"
uuid = "fdea26ae-647d-5447-a871-4b548cad5224"
version = "3.7.2"

[[deps.SIMDTypes]]
git-tree-sha1 = "330289636fb8107c5f32088d2741e9fd7a061a5c"
uuid = "94e857df-77ce-4151-89e5-788b33177be4"
version = "0.1.0"

[[deps.SLEEFPirates]]
deps = ["IfElse", "Static", "VectorizationBase"]
git-tree-sha1 = "456f610ca2fbd1c14f5fcf31c6bfadc55e7d66e0"
uuid = "476501e8-09a2-5ece-8869-fb82de89a1fa"
version = "0.6.43"

[[deps.SciMLBase]]
deps = ["ADTypes", "Accessors", "Adapt", "ArrayInterface", "CommonSolve", "ConstructionBase", "Distributed", "DocStringExtensions", "EnumX", "FunctionWrappersWrappers", "IteratorInterfaceExtensions", "LinearAlgebra", "Logging", "Markdown", "Moshi", "PreallocationTools", "PrecompileTools", "Preferences", "Printf", "RecipesBase", "RecursiveArrayTools", "Reexport", "RuntimeGeneratedFunctions", "SciMLLogging", "SciMLOperators", "SciMLPublic", "SciMLStructures", "StaticArraysCore", "Statistics", "SymbolicIndexingInterface"]
git-tree-sha1 = "8787e28326c99b0c9c706b51da525ad09d03c56f"
uuid = "0bca4576-84f4-4d90-8ffe-ffa030f20462"
version = "2.149.0"

    [deps.SciMLBase.extensions]
    SciMLBaseChainRulesCoreExt = "ChainRulesCore"
    SciMLBaseDifferentiationInterfaceExt = "DifferentiationInterface"
    SciMLBaseDistributionsExt = "Distributions"
    SciMLBaseEnzymeExt = "Enzyme"
    SciMLBaseForwardDiffExt = "ForwardDiff"
    SciMLBaseMLStyleExt = "MLStyle"
    SciMLBaseMakieExt = "Makie"
    SciMLBaseMeasurementsExt = "Measurements"
    SciMLBaseMonteCarloMeasurementsExt = "MonteCarloMeasurements"
    SciMLBaseMooncakeExt = "Mooncake"
    SciMLBasePartialFunctionsExt = "PartialFunctions"
    SciMLBasePyCallExt = "PyCall"
    SciMLBasePythonCallExt = "PythonCall"
    SciMLBaseRCallExt = "RCall"
    SciMLBaseReverseDiffExt = "ReverseDiff"
    SciMLBaseTrackerExt = "Tracker"
    SciMLBaseZygoteExt = ["Zygote", "ChainRulesCore"]

    [deps.SciMLBase.weakdeps]
    ChainRules = "082447d4-558c-5d27-93f4-14fc19e9eca2"
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    DifferentiationInterface = "a0c0ee7d-e4b9-4e03-894e-1c5f64a51d63"
    Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
    Enzyme = "7da242da-08ed-463a-9acd-ee780be4f1d9"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    MLStyle = "d8e11817-5142-5d16-987a-aa16d5891078"
    Makie = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
    Measurements = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
    MonteCarloMeasurements = "0987c9cc-fe09-11e8-30f0-b96dd679fdca"
    Mooncake = "da2b9cff-9c12-43a0-ae48-6db2b0edb7d6"
    PartialFunctions = "570af359-4316-4cb7-8c74-252c00c2016b"
    PyCall = "438e738f-606a-5dbb-bf0a-cddfbfd45ab0"
    PythonCall = "6099a3de-0909-46bc-b1f4-468b9a2dfc0d"
    RCall = "6f49c342-dc21-5d91-9882-a32aef131414"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"
    Zygote = "e88e6eb3-aa80-5325-afca-941959d7151f"

[[deps.SciMLJacobianOperators]]
deps = ["ADTypes", "ArrayInterface", "ConcreteStructs", "ConstructionBase", "DifferentiationInterface", "FastClosures", "LinearAlgebra", "SciMLBase", "SciMLOperators"]
git-tree-sha1 = "e96d5e96debf7f80a50d0b976a13dea556ccfd3a"
uuid = "19f34311-ddf3-4b8b-af20-060888a46c0e"
version = "0.1.12"

[[deps.SciMLLogging]]
deps = ["Logging", "LoggingExtras", "Preferences"]
git-tree-sha1 = "0161be062570af4042cf6f69e3d5d0b0555b6927"
uuid = "a6db7da4-7206-11f0-1eab-35f2a5dbe1d1"
version = "1.9.1"

    [deps.SciMLLogging.extensions]
    SciMLLoggingTracyExt = "Tracy"

    [deps.SciMLLogging.weakdeps]
    Tracy = "e689c965-62c8-4b79-b2c5-8359227902fd"

[[deps.SciMLOperators]]
deps = ["Accessors", "ArrayInterface", "DocStringExtensions", "LinearAlgebra"]
git-tree-sha1 = "794c760e6aafe9f40dcd7dd30526ea33f0adc8b7"
uuid = "c0aeaf25-5076-4817-a8d5-81caf7dfa961"
version = "1.15.1"
weakdeps = ["SparseArrays", "StaticArraysCore"]

    [deps.SciMLOperators.extensions]
    SciMLOperatorsSparseArraysExt = "SparseArrays"
    SciMLOperatorsStaticArraysCoreExt = "StaticArraysCore"

[[deps.SciMLPublic]]
git-tree-sha1 = "0ba076dbdce87ba230fff48ca9bca62e1f345c9b"
uuid = "431bcebd-1456-4ced-9d72-93c2757fff0b"
version = "1.0.1"

[[deps.SciMLStructures]]
deps = ["ArrayInterface", "PrecompileTools"]
git-tree-sha1 = "607f6867d0b0553e98fc7f725c9f9f13b4d01a32"
uuid = "53ae85a6-f571-4167-b2af-e1d143709226"
version = "1.10.0"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "9b81b8393e50b7d4e6d0a9f14e192294d3b7c109"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.3.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "StaticArraysCore"]
git-tree-sha1 = "c5391c6ace3bc430ca630251d02ea9687169ca68"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "1.1.2"

[[deps.ShaderAbstractions]]
deps = ["ColorTypes", "FixedPointNumbers", "GeometryBasics", "LinearAlgebra", "Observables", "StaticArrays"]
git-tree-sha1 = "818554664a2e01fc3784becb2eb3a82326a604b6"
uuid = "65257c39-d410-5151-9873-9b3e5be5013e"
version = "0.5.0"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"
version = "1.11.0"

[[deps.Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[deps.SignedDistanceFields]]
deps = ["Statistics"]
git-tree-sha1 = "3949ad92e1c9d2ff0cd4a1317d5ecbba682f4b92"
uuid = "73760f76-fbc4-59ce-8f25-708e95d2df96"
version = "0.4.1"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "be8eeac05ec97d379347584fa9fe2f5f76795bcb"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.5"

[[deps.SimpleUnPack]]
git-tree-sha1 = "58e6353e72cde29b90a69527e56df1b5c3d8c437"
uuid = "ce78b400-467f-4804-87d8-8f486da07d0a"
version = "1.1.0"

[[deps.Sixel]]
deps = ["Dates", "FileIO", "ImageCore", "IndirectArrays", "OffsetArrays", "REPL", "libsixel_jll"]
git-tree-sha1 = "0494aed9501e7fb65daba895fb7fd57cc38bc743"
uuid = "45858cf5-a6b0-47a3-bbea-62219f50df47"
version = "0.1.5"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"
version = "1.11.0"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "64d974c2e6fdf07f8155b5b2ca2ffa9069b608d9"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.2"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.11.0"

[[deps.SpecialFunctions]]
deps = ["IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "5acc6a41b3082920f79ca3c759acbcecf18a8d78"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.7.1"
weakdeps = ["ChainRulesCore"]

    [deps.SpecialFunctions.extensions]
    SpecialFunctionsChainRulesCoreExt = "ChainRulesCore"

[[deps.StableRNGs]]
deps = ["Random"]
git-tree-sha1 = "4f96c596b8c8258cc7d3b19797854d368f243ddc"
uuid = "860ef19b-820b-49d6-a774-d7a799459cd3"
version = "1.0.4"

[[deps.StableTasks]]
git-tree-sha1 = "c4f6610f85cb965bee5bfafa64cbeeda55a4e0b2"
uuid = "91464d47-22a1-43fe-8b7f-2d57ee82463f"
version = "0.1.7"

[[deps.StackViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "be1cf4eb0ac528d96f5115b4ed80c26a8d8ae621"
uuid = "cae243ae-269e-4f55-b966-ac2d0dc13c15"
version = "0.1.2"

[[deps.StartUpDG]]
deps = ["CaratheodoryPruning", "ConstructionBase", "FillArrays", "HDF5", "Kronecker", "LinearAlgebra", "NodesAndModes", "PathIntersections", "Printf", "RecipesBase", "RecursiveArrayTools", "Reexport", "Setfield", "SparseArrays", "StaticArrays", "Triangulate", "WriteVTK"]
git-tree-sha1 = "91f439ae63dd9dedc38e734a30335ef0bf1dd11e"
uuid = "472ebc20-7c99-4d4b-9470-8fde4e9faa0f"
version = "1.3.4"

    [deps.StartUpDG.extensions]
    StartUpDGSummationByPartsOperatorsExt = "SummationByPartsOperators"
    TriangulatePlotsExt = "Plots"

    [deps.StartUpDG.weakdeps]
    Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
    SummationByPartsOperators = "9f78cca6-572e-554e-b819-917d2f1cf240"

[[deps.Static]]
deps = ["CommonWorldInvalidations", "IfElse", "PrecompileTools", "SciMLPublic"]
git-tree-sha1 = "49440414711eddc7227724ae6e570c7d5559a086"
uuid = "aedffcd0-7271-4cad-89d0-dc628f76c6d3"
version = "1.3.1"

[[deps.StaticArrayInterface]]
deps = ["ArrayInterface", "Compat", "IfElse", "LinearAlgebra", "PrecompileTools", "SciMLPublic", "Static"]
git-tree-sha1 = "aa1ea41b3d45ac449d10477f65e2b40e3197a0d2"
uuid = "0d7ed370-da01-4f52-bd93-41d350b8b718"
version = "1.9.0"
weakdeps = ["OffsetArrays", "StaticArrays"]

    [deps.StaticArrayInterface.extensions]
    StaticArrayInterfaceOffsetArraysExt = "OffsetArrays"
    StaticArrayInterfaceStaticArraysExt = "StaticArrays"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "PrecompileTools", "Random", "StaticArraysCore"]
git-tree-sha1 = "246a8bb2e6667f832eea063c3a56aef96429a3db"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.9.18"
weakdeps = ["ChainRulesCore", "Statistics"]

    [deps.StaticArrays.extensions]
    StaticArraysChainRulesCoreExt = "ChainRulesCore"
    StaticArraysStatisticsExt = "Statistics"

[[deps.StaticArraysCore]]
git-tree-sha1 = "6ab403037779dae8c514bad259f32a447262455a"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.4"

[[deps.Statistics]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "ae3bb1eb3bba077cd276bc5cfc337cc65c3075c0"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.1"
weakdeps = ["SparseArrays"]

    [deps.Statistics.extensions]
    SparseArraysExt = ["SparseArrays"]

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "178ed29fd5b2a2cfc3bd31c13375ae925623ff36"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.8.0"

[[deps.StatsBase]]
deps = ["AliasTables", "DataAPI", "DataStructures", "IrrationalConstants", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "aceda6f4e598d331548e04cc6b2124a6148138e3"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.34.10"

[[deps.StatsFuns]]
deps = ["HypergeometricFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "91f091a8716a6bb38417a6e6f274602a19aaa685"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "1.5.2"
weakdeps = ["ChainRulesCore", "InverseFunctions"]

    [deps.StatsFuns.extensions]
    StatsFunsChainRulesCoreExt = "ChainRulesCore"
    StatsFunsInverseFunctionsExt = "InverseFunctions"

[[deps.StrideArrays]]
deps = ["ArrayInterface", "LinearAlgebra", "LoopVectorization", "Octavian", "Random", "SLEEFPirates", "Static", "StaticArrayInterface", "StaticArraysCore", "Statistics", "StrideArraysCore", "VectorizationBase", "VectorizedRNG", "VectorizedStatistics"]
git-tree-sha1 = "a009ced9a1952b91f3982a6e06df672189c6cbc9"
uuid = "d1fa6d79-ef01-42a6-86c9-f7c551f8593b"
version = "0.1.29"

[[deps.StrideArraysCore]]
deps = ["ArrayInterface", "CloseOpenIntervals", "IfElse", "LayoutPointers", "LinearAlgebra", "ManualMemory", "SIMDTypes", "Static", "StaticArrayInterface", "ThreadingUtilities"]
git-tree-sha1 = "83151ba8065a73f53ca2ae98bc7274d817aa30f2"
uuid = "7792a7ef-975c-4747-a70f-980b88e8d1da"
version = "0.5.8"

[[deps.StringManipulation]]
deps = ["PrecompileTools"]
git-tree-sha1 = "d05693d339e37d6ab134c5ab53c29fce5ee5d7d5"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.4.4"

[[deps.StructArrays]]
deps = ["ConstructionBase", "DataAPI", "Tables"]
git-tree-sha1 = "a2c37d815bf00575332b7bd0389f771cb7987214"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.7.2"
weakdeps = ["Adapt", "GPUArraysCore", "KernelAbstractions", "LinearAlgebra", "SparseArrays", "StaticArrays"]

    [deps.StructArrays.extensions]
    StructArraysAdaptExt = "Adapt"
    StructArraysGPUArraysCoreExt = ["GPUArraysCore", "KernelAbstractions"]
    StructArraysLinearAlgebraExt = "LinearAlgebra"
    StructArraysSparseArraysExt = "SparseArrays"
    StructArraysStaticArraysExt = "StaticArrays"

[[deps.StructUtils]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "28145feabf717c5d65c1d5e09747ee7b1ff3ed13"
uuid = "ec057cc2-7a8d-4b58-b3b3-92acb9f63b42"
version = "2.6.3"

    [deps.StructUtils.extensions]
    StructUtilsMeasurementsExt = ["Measurements"]
    StructUtilsTablesExt = ["Tables"]

    [deps.StructUtils.weakdeps]
    Measurements = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
    Tables = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"

[[deps.StyledStrings]]
uuid = "f489334b-da3d-4c2e-b8f0-e476e12c162b"
version = "1.11.0"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.7.0+0"

[[deps.SummationByPartsOperators]]
deps = ["ArgCheck", "AutoHashEquals", "FFTW", "InteractiveUtils", "LinearAlgebra", "LoopVectorization", "MuladdMacro", "PolynomialBases", "PrecompileTools", "RecursiveArrayTools", "Reexport", "Requires", "SciMLBase", "SimpleUnPack", "SparseArrays", "StaticArrayInterface", "StaticArrays", "Unrolled"]
git-tree-sha1 = "69342830cc590266758f8a7c584d5a2dd92ffca3"
uuid = "9f78cca6-572e-554e-b819-917d2f1cf240"
version = "0.5.90"

    [deps.SummationByPartsOperators.extensions]
    SummationByPartsOperatorsBandedMatricesExt = "BandedMatrices"
    SummationByPartsOperatorsDiffEqCallbacksExt = "DiffEqCallbacks"
    SummationByPartsOperatorsForwardDiffExt = "ForwardDiff"
    SummationByPartsOperatorsOptimForwardDiffExt = ["Optim", "ForwardDiff"]
    SummationByPartsOperatorsStructArraysExt = "StructArrays"

    [deps.SummationByPartsOperators.weakdeps]
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    DiffEqCallbacks = "459566f4-90b8-5000-8ac3-15dfb0a30def"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    Optim = "429524aa-4258-5aef-a3af-852621145aeb"
    StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"

[[deps.SymbolicIndexingInterface]]
deps = ["Accessors", "ArrayInterface", "RuntimeGeneratedFunctions", "StaticArraysCore"]
git-tree-sha1 = "b19cf024a2b11d72bef7c74ac3d1cbe86ec9e4ed"
uuid = "2efcf032-c050-4f8e-a9bb-153293bab1f5"
version = "0.3.44"
weakdeps = ["PrettyTables"]

    [deps.SymbolicIndexingInterface.extensions]
    SymbolicIndexingInterfacePrettyTablesExt = "PrettyTables"

[[deps.SysInfo]]
deps = ["Dates", "DelimitedFiles", "Hwloc", "PrecompileTools", "Random", "Serialization"]
git-tree-sha1 = "7aaebfbf5b3a39268f4a0caaa43e878e1138d25c"
uuid = "90a7ee08-a23f-48b9-9006-0e0e2a9e4608"
version = "0.3.0"

[[deps.T8code]]
deps = ["CEnum", "Libdl", "MPI", "MPIPreferences", "Preferences", "Reexport", "UUIDs", "t8code_jll"]
git-tree-sha1 = "1b5ef460f156ed68e3affb67f48e2b4bec9915e4"
uuid = "d0cc0030-9a40-4274-8435-baadcfd54fa1"
version = "0.7.4"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "OrderedCollections", "TableTraits"]
git-tree-sha1 = "f2c1efbc8f3a609aadf318094f8fc5204bdaf344"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.12.1"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
version = "1.11.0"

[[deps.ThreadPinning]]
deps = ["DelimitedFiles", "Libdl", "LinearAlgebra", "PrecompileTools", "Preferences", "Random", "StableTasks", "SysInfo", "ThreadPinningCore"]
git-tree-sha1 = "d47dbc7862f69ce1973fff227237275ff4a10781"
uuid = "811555cd-349b-4f26-b7bc-1f208b848042"
version = "1.0.2"
weakdeps = ["Distributed", "MPI"]

    [deps.ThreadPinning.extensions]
    DistributedExt = "Distributed"
    MPIExt = "MPI"

[[deps.ThreadPinningCore]]
deps = ["LinearAlgebra", "PrecompileTools", "StableTasks"]
git-tree-sha1 = "bb3c6f3b5600fbff028c43348365681b34d06499"
uuid = "6f48bc29-05ce-4cc8-baad-4adcba581a18"
version = "0.4.5"

[[deps.ThreadingUtilities]]
deps = ["ManualMemory"]
git-tree-sha1 = "d969183d3d244b6c33796b5ed01ab97328f2db85"
uuid = "8290d209-cae3-49c0-8002-c8c24d57dab5"
version = "0.5.5"

[[deps.TiffImages]]
deps = ["ColorTypes", "DataStructures", "DocStringExtensions", "FileIO", "FixedPointNumbers", "IndirectArrays", "Inflate", "Mmap", "OffsetArrays", "PkgVersion", "PrecompileTools", "ProgressMeter", "SIMD", "UUIDs"]
git-tree-sha1 = "08c10bc34f4e7743f530793d0985bf3c254e193d"
uuid = "731e570b-9d59-4bfa-96dc-6df516fadf69"
version = "0.11.8"

[[deps.TimerOutputs]]
deps = ["ExprTools", "Printf"]
git-tree-sha1 = "3748bd928e68c7c346b52125cf41fff0de6937d0"
uuid = "a759f4b9-e2f1-59dc-863e-4aeb61b1ea8f"
version = "0.5.29"
weakdeps = ["FlameGraphs"]

    [deps.TimerOutputs.extensions]
    FlameGraphsExt = "FlameGraphs"

[[deps.TranscodingStreams]]
git-tree-sha1 = "0c45878dcfdcfa8480052b6ab162cdd138781742"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.11.3"

[[deps.Triangle_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "bc4c7bb314cd0ac8bb36152f637fcd764e95748e"
uuid = "5639c1d2-226c-5e70-8d55-b3095415a16a"
version = "1.6.3+0"

[[deps.Triangulate]]
deps = ["DocStringExtensions", "Triangle_jll"]
git-tree-sha1 = "fd348d50587253dff8efb7a34b997effccf44427"
uuid = "f7e6ffb2-c36d-4f8f-a77e-16e897189344"
version = "3.0.1"

[[deps.Tricks]]
git-tree-sha1 = "311349fd1c93a31f783f977a71e8b062a57d4101"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.13"

[[deps.TriplotBase]]
git-tree-sha1 = "4d4ed7f294cda19382ff7de4c137d24d16adc89b"
uuid = "981d1d27-644d-49a2-9326-4793e63143c3"
version = "0.1.0"

[[deps.TriplotRecipes]]
deps = ["RecipesBase", "TriplotBase"]
git-tree-sha1 = "fceb3b0f37ff6ccf3c70b9c5198d2eefec46ada0"
uuid = "808ab39a-a642-4abf-81ff-4cb34ebbffa3"
version = "0.1.2"

[[deps.Trixi]]
deps = ["Accessors", "Adapt", "CodeTracking", "ConstructionBase", "DataStructures", "DelimitedFiles", "DiffEqBase", "DiffEqCallbacks", "Downloads", "EllipsisNotation", "FillArrays", "ForwardDiff", "HDF5", "KernelAbstractions", "LinearAlgebra", "LinearMaps", "LoopVectorization", "MPI", "MuladdMacro", "Octavian", "OffsetArrays", "P4est", "Polyester", "PrecompileTools", "Preferences", "Printf", "RecipesBase", "RecursiveArrayTools", "Reexport", "Requires", "SciMLBase", "SimpleUnPack", "SparseArrays", "StableRNGs", "StartUpDG", "Static", "StaticArrayInterface", "StaticArrays", "StrideArrays", "StructArrays", "SummationByPartsOperators", "T8code", "TimerOutputs", "Triangulate", "TriplotBase", "TriplotRecipes", "TrixiBase", "UUIDs"]
git-tree-sha1 = "8b9e993cdcd1e6c2a874b3c43d22152258ba6104"
uuid = "a7f1ee26-1774-49b1-8366-f1abc58fbfcb"
version = "0.15.8"

    [deps.Trixi.extensions]
    TrixiCUDAExt = "CUDA"
    TrixiConvexECOSExt = ["Convex", "ECOS"]
    TrixiMakieExt = "Makie"
    TrixiNLsolveExt = "NLsolve"
    TrixiSparseConnectivityTracerExt = "SparseConnectivityTracer"

    [deps.Trixi.weakdeps]
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    Convex = "f65535da-76fb-5f13-bab9-19810c17039a"
    ECOS = "e2685f51-7e38-5353-a97d-a921fd2c8199"
    Makie = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
    NLsolve = "2774e3e8-f4cf-5e23-947b-6d7e65073b56"
    SparseConnectivityTracer = "9f842d2f-2579-4b1d-911e-f412cf18a3f5"

[[deps.TrixiBase]]
deps = ["ChangePrecision", "TimerOutputs"]
git-tree-sha1 = "e3349c809f5f6677312ffe2e62fc6a49cb3e82f1"
uuid = "9a0f1c46-06d5-4909-a5a3-ce25d3fa3284"
version = "0.1.8"
weakdeps = ["MPI"]

    [deps.TrixiBase.extensions]
    TrixiBaseMPIExt = "MPI"

[[deps.TruncatedStacktraces]]
deps = ["InteractiveUtils", "MacroTools", "Preferences"]
git-tree-sha1 = "ea3e54c2bdde39062abf5a9758a23735558705e1"
uuid = "781d530d-4396-4725-bb49-402e4bee1e77"
version = "1.4.0"

[[deps.URIs]]
git-tree-sha1 = "bef26fb046d031353ef97a82e3fdb6afe7f21b1a"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.6.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"
version = "1.11.0"

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"
version = "1.11.0"

[[deps.UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[deps.Unitful]]
deps = ["Dates", "LinearAlgebra", "Random"]
git-tree-sha1 = "57e1b2c9de4bd6f40ecb9de4ac1797b81970d008"
uuid = "1986cc42-f94f-5a68-af5c-568840ba703d"
version = "1.28.0"
weakdeps = ["ConstructionBase", "ForwardDiff", "InverseFunctions", "LaTeXStrings", "Latexify", "NaNMath", "Printf"]

    [deps.Unitful.extensions]
    ConstructionBaseUnitfulExt = "ConstructionBase"
    ForwardDiffExt = "ForwardDiff"
    InverseFunctionsUnitfulExt = "InverseFunctions"
    LatexifyExt = ["Latexify", "LaTeXStrings"]
    NaNMathExt = "NaNMath"
    PrintfExt = "Printf"

[[deps.Unrolled]]
deps = ["MacroTools"]
git-tree-sha1 = "6cc9d682755680e0f0be87c56392b7651efc2c7b"
uuid = "9602ed7d-8fef-5bc8-8597-8f21381861e8"
version = "0.1.5"

[[deps.UnsafeAtomics]]
git-tree-sha1 = "b13c4edda90890e5b04ba24e20a310fbe6f249ff"
uuid = "013be700-e6cd-48c3-b4a1-df204f14c38f"
version = "0.3.0"

    [deps.UnsafeAtomics.extensions]
    UnsafeAtomicsLLVM = ["LLVM"]

    [deps.UnsafeAtomics.weakdeps]
    LLVM = "929cbde3-209d-540e-8aea-75f648917ca0"

[[deps.VTKBase]]
git-tree-sha1 = "c2d0db3ef09f1942d08ea455a9e252594be5f3b6"
uuid = "4004b06d-e244-455f-a6ce-a5f9919cc534"
version = "1.0.1"

[[deps.VectorizationBase]]
deps = ["ArrayInterface", "CPUSummary", "HostCPUFeatures", "IfElse", "LayoutPointers", "Libdl", "LinearAlgebra", "SIMDTypes", "Static", "StaticArrayInterface"]
git-tree-sha1 = "d1d9a935a26c475ebffd54e9c7ad11627c43ea85"
uuid = "3d5dd08c-fd9d-11e8-17fa-ed2836048c2f"
version = "0.21.72"

[[deps.VectorizedRNG]]
deps = ["Distributed", "Random", "SLEEFPirates", "UnPack", "VectorizationBase"]
git-tree-sha1 = "5ca83562ba95272d8709c6c91e31e23c3c4c9825"
uuid = "33b4df10-0173-11e9-2a0c-851a7edac40e"
version = "0.2.25"
weakdeps = ["Requires", "StaticArraysCore"]

    [deps.VectorizedRNG.extensions]
    VectorizedRNGStaticArraysExt = ["StaticArraysCore"]

[[deps.VectorizedStatistics]]
deps = ["LoopVectorization", "PrecompileTools", "Static"]
git-tree-sha1 = "e6b69204f739942b70e647b7013cf6adeeb4fb79"
uuid = "3b853605-1c98-4422-8364-4bd93ee0529e"
version = "0.5.11"

[[deps.WebP]]
deps = ["CEnum", "ColorTypes", "FileIO", "FixedPointNumbers", "ImageCore", "libwebp_jll"]
git-tree-sha1 = "aa1ca3c47f119fbdae8770c29820e5e6119b83f2"
uuid = "e3aaa7dc-3e4b-44e0-be63-ffb868ccd7c1"
version = "0.1.3"

[[deps.WoodburyMatrices]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "248a7031b3da79a127f14e5dc5f417e26f9f6db7"
uuid = "efce3f68-66dc-5838-9240-27a6d6f5f9b6"
version = "1.1.0"

[[deps.WriteVTK]]
deps = ["Base64", "CodecZlib", "FillArrays", "LightXML", "TranscodingStreams", "VTKBase"]
git-tree-sha1 = "a329e0b6310244173690d6a4dfc6d1141f9b9370"
uuid = "64499a7a-5c06-52f2-abe2-ccb03c286192"
version = "1.21.2"

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Zlib_jll"]
git-tree-sha1 = "80d3930c6347cfce7ccf96bd3bafdf079d9c0390"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.13.9+0"

[[deps.XZ_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "9cce64c0fdd1960b597ba7ecda2950b5ed957438"
uuid = "ffd25f8a-64ca-5728-b0f7-c24cf3aae800"
version = "5.8.2+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "808090ede1d41644447dd5cbafced4731c56bd2f"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.8.13+0"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "aa1261ebbac3ccc8d16558ae6799524c450ed16b"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.13+0"

[[deps.Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "52858d64353db33a56e13c341d7bf44cd0d7b309"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.6+0"

[[deps.Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "1a4a26870bf1e5d26cd585e38038d399d7e65706"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.8+0"

[[deps.Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "75e00946e43621e09d431d9b95818ee751e6b2ef"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "6.0.2+0"

[[deps.Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "7ed9347888fac59a618302ee38216dd0379c480d"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.12+0"

[[deps.Xorg_libpciaccess_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "4909eb8f1cbf6bd4b1c30dd18b2ead9019ef2fad"
uuid = "a65dc6b1-eb27-53a1-bb3e-dea574b5389e"
version = "0.18.1+0"

[[deps.Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libXau_jll", "Xorg_libXdmcp_jll"]
git-tree-sha1 = "bfcaf7ec088eaba362093393fe11aa141fa15422"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.17.1+0"

[[deps.Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "a63799ff68005991f9d9491b6e95bd3478d783cb"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.6.0+0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "446b23e73536f84e8037f5dce465e92275f6a308"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.7+1"

[[deps.isoband_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51b5eeb3f98367157a7a12a1fb0aa5328946c03c"
uuid = "9a68df92-36a6-505f-a73e-abb412b6bfb4"
version = "0.2.3+0"

[[deps.ittapi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "d16390a41ca6eb6af3e34bbca4399a67a1b458fc"
uuid = "f03c7084-70eb-500e-bb85-e99cbc517f87"
version = "3.25.5+0"

[[deps.libaec_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "13b760f97c6e753b47df30cb438d4dc3b50df282"
uuid = "477f73a3-ac25-53e9-8cc3-50b2fa2566f0"
version = "1.1.5+0"

[[deps.libaom_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "371cc681c00a3ccc3fbc5c0fb91f58ba9bec1ecf"
uuid = "a4ae2306-e953-59d6-aa16-d00cac43593b"
version = "3.13.1+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "125eedcb0a4a0bba65b657251ce1d27c8714e9d6"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.17.4+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.11.0+0"

[[deps.libdrm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libpciaccess_jll"]
git-tree-sha1 = "63aac0bcb0b582e11bad965cef4a689905456c03"
uuid = "8e53e030-5e6c-5a89-a30b-be5b7263a166"
version = "2.4.125+1"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "646634dd19587a56ee2f1199563ec056c5f228df"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.4+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "e015f211ebb898c8180887012b938f3851e719ac"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.55+0"

[[deps.libsixel_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "libpng_jll"]
git-tree-sha1 = "c1733e347283df07689d71d61e14be986e49e47a"
uuid = "075b6546-f08a-558a-be8f-8157d0f608a5"
version = "1.10.5+0"

[[deps.libva_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll", "Xorg_libXext_jll", "Xorg_libXfixes_jll", "libdrm_jll"]
git-tree-sha1 = "7dbf96baae3310fe2fa0df0ccbb3c6288d5816c9"
uuid = "9a156e7d-b971-5f62-b2c9-67348b8fb97c"
version = "2.23.0+0"

[[deps.libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll"]
git-tree-sha1 = "11e1772e7f3cc987e9d3de991dd4f6b2602663a5"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.8+0"

[[deps.libwebp_jll]]
deps = ["Artifacts", "Giflib_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libglvnd_jll", "Libtiff_jll", "libpng_jll"]
git-tree-sha1 = "4e4282c4d846e11dce56d74fa8040130b7a95cb3"
uuid = "c5f90fcd-3b7e-5836-afba-fc50a0988cb2"
version = "1.6.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.59.0+0"

[[deps.oneTBB_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl"]
git-tree-sha1 = "1350188a69a6e46f799d3945beef36435ed7262f"
uuid = "1317d2d5-d96f-522e-a858-c73665f53c3e"
version = "2022.0.0+1"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"

[[deps.pprof_jll]]
deps = ["Artifacts", "Graphviz_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "41bcaa13dd41f13b2290944e5e5be035e90c6bc4"
uuid = "cf2c5f97-e748-59fa-a03f-dda3c62118cb"
version = "2.0.0+0"

[[deps.t8code_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl", "MPICH_jll", "MPIPreferences", "MPItrampoline_jll", "MicrosoftMPI_jll", "OpenMPI_jll", "TOML", "Zlib_jll"]
git-tree-sha1 = "cf073e7d4275b8a030140936639f3d6a5eeb3e74"
uuid = "4ee9bed8-4011-53f7-90c2-22363c2f500d"
version = "3.0.1+0"

[[deps.x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "14cc7083fc6dff3cc44f2bc435ee96d06ed79aa7"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "10164.0.1+0"

[[deps.x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e7b67590c14d487e734dcb925924c5dc43ec85f3"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "4.1.0+0"
"""

# ╔═╡ Cell order:
# ╠═25935904-4644-4ce2-83e9-d08c22b5e40d
# ╟─820eef38-86d2-4b03-8989-0dc4d4c86929
# ╟─2aeda4bd-aa1c-46fc-8183-79f8c75e5172
# ╟─97f862e8-268b-4bff-8bdc-842aecffc2f1
# ╟─5c4c21e4-1a90-11f0-2f05-47d877772576
# ╟─f3108f38-2bb4-4af7-b864-1805bb3cbef5
# ╟─f11fb041-4587-4dc2-b201-5a5b27a32dff
# ╟─4040ca9a-acbe-40fe-9a81-95996c4b64b2
# ╟─4f60569e-a86b-4488-ac35-1554ae2b79ea
# ╟─68ae253d-2a29-44e0-b217-98c3c1b5bc60
# ╠═b238fccf-56a8-47a9-950f-b1bfedf3bbd8
# ╠═c37a3eda-4ce4-4ad3-8011-4c4c6376775d
# ╟─be74fa8a-21d6-4ee0-814c-bbaea5904934
# ╠═56f31a4a-8bea-4738-9c38-9630a67fb4e6
# ╠═71f5f0a0-b472-48e8-ad8f-1a2b515d81fe
# ╠═93756400-7346-4fa0-ad5e-06591a6cd8d8
# ╠═317f1ca5-5d8e-4820-abbf-682464866bcb
# ╠═066f84af-45ef-4ff7-9016-d4e2f95d42d1
# ╟─80ef7628-0f17-48d2-9bcf-21e3e3985455
# ╟─7838acb6-3786-44ad-ae40-b78d252d59a8
# ╠═08e3642e-8e06-4906-b235-1b31bdc1eb42
# ╟─948f8590-9a26-4b26-998d-ac0c8f5c50f4
# ╠═492c4348-0b0d-4e52-a4c9-d80283f7bc98
# ╠═dde9da1d-a6b1-4ca9-b8d4-f9a164b089cb
# ╠═7c31dec3-dcf8-4366-96c8-98bd9d426faf
# ╠═8a01f348-9e96-448f-97b3-b193c5f7a36a
# ╟─0115a2f6-ae33-45e3-bebf-924f7c3e8e05
# ╠═3eb69d4f-5d7b-4b08-b274-f51f7c33970a
# ╟─f953aace-06b6-4101-924c-3218140fc09a
# ╠═1255bdf3-a32f-45e9-b589-2da4883d775b
# ╟─5c8c666a-8a8b-4f37-8bde-3a29b75c9c43
# ╠═68d0783c-6651-4432-bdbc-3be4d3f6ea65
# ╠═89b11df3-7a2f-463f-954a-f7f6c137af8d
# ╠═6db6a364-60af-4afc-bdcf-3f2f29e5aaa7
# ╟─8ac7e33b-2279-4b3b-9c44-9cc7bdb4d256
# ╠═e03e9d1c-0d1c-4bbc-848e-0fd81ddd5e8a
# ╟─8ef05b61-e2ce-4b9f-a42c-f7f2dc664852
# ╠═9790f509-046b-4714-bfba-b77019c806ae
# ╟─3e717bde-a8d7-41b3-a52e-694efd22ff38
# ╟─e8dd5d43-7a39-4f4c-9465-a25ad4dae287
# ╟─14b79b92-6ff8-476f-b403-63c797d99567
# ╠═7e51fbab-eea5-4d05-82fd-44d37e91e9b7
# ╟─ac46f42b-ec7d-46d3-a4ad-d5c887a93327
# ╠═bef23b0e-fd7f-4fab-aec7-de0e38a5b847
# ╠═c48f8d56-a11c-4e94-b98f-b44c4516b0af
# ╟─ad5f2707-572a-4245-ba52-078c67f1b17f
# ╠═3f02c140-c408-4f0c-9d73-5348d2b4af4d
# ╠═9840f078-63ff-4efc-9d45-6e0198d2624d
# ╠═36762f71-e535-4048-ac68-ea1fc6859de1
# ╟─9b28e25b-493a-4e74-bc44-e996f639b8d1
# ╠═43abf4bc-d98d-4162-9cb5-2f531ffb7fb4
# ╠═74ae8f13-c09d-4e51-ba56-e5b230e13f1f
# ╠═acd1a03d-1114-44e3-a970-3f418539d2db
# ╠═84973c7a-2d17-49c3-b627-a804dcefd35b
# ╟─03fed1dd-004c-4fba-8ce3-7625f1c25820
# ╠═9d058445-37e5-4201-b7f2-c658125bc126
# ╟─5bdf8023-ce43-44e2-beff-229ff6455d84
# ╟─0c145a21-ec7e-4509-9b1d-8844a89f65aa
# ╠═054e1fe2-fc02-4b05-a3db-30f09fe1e7ff
# ╠═55167a98-2dd4-4751-a4cf-7bdce3032bb1
# ╠═194c38a6-4256-4f1d-861c-07700442b0ea
# ╠═866bcf04-f70d-4c5d-91b9-fa59e54f14c6
# ╟─ed204cae-226f-423d-b056-a02bb25664d0
# ╟─d732846e-8c4d-4243-b886-4dde461da524
# ╠═203a1ab2-caaa-4530-8b30-fc4d522019b1
# ╠═1709a94e-5bc6-4c57-ae03-e48b14ef7c5a
# ╠═801a3777-6bd0-439a-977a-5ded24b68825
# ╟─2897d2e7-58d8-42ce-b0cd-22c206b94e25
# ╟─ea252115-6131-4cf5-ad03-dc8bfea1c392
# ╟─fa5243df-79a9-4e36-a14a-18d20babbd08
# ╟─faf4b6b2-e191-4af1-9527-c8cb3e9f6e71
# ╟─898ad034-31b8-4ef5-a58e-06757a6d34cb
# ╟─a8098f14-c792-441d-817d-e4bc1124fd55
# ╟─88bc8fac-06e1-45cc-86e7-dee875bd0e78
# ╠═06e23433-30df-467c-8c8c-2d3bc115a24d
# ╠═947272bd-1fbb-4eb3-8775-967b4dae9df2
# ╠═386da2f5-3285-494f-baaa-86f139bdf3a6
# ╠═a01059d0-67ec-4cf7-9d36-3049145ffc39
# ╠═3edd3985-e3b1-4a5a-90d1-647f3c42a000
# ╠═63fc1a79-8c7c-47b2-8926-cdaf965f063e
# ╟─8799a9ce-1c36-4fb3-a038-a9c259abb5bc
# ╠═4fce5337-e204-4fa4-95eb-4bc1e31b54d1
# ╠═4f5bfc23-252d-46a2-8eac-ec4446cc915b
# ╟─652ccd92-71ee-427d-b21e-fec27640e99e
# ╟─8e52812b-7b8c-4e69-ae11-04e1b6da4b85
# ╠═29384daa-5276-4a2d-81d5-578749335a75
# ╟─6182daf1-5332-4b68-a9a5-1ae0c9a39882
# ╟─50499b7e-4ff9-4279-ab02-214e857c3d55
# ╟─d39720df-ab2e-440e-861b-be0b09859477
# ╟─6a3f8b13-990a-48ba-8bb5-1132b819c0fa
# ╟─b10de1e6-653c-4c12-b7d5-a4980e010ce7
# ╠═74428e50-7739-4d92-84bf-f7e355c63128
# ╠═11c0a32b-2b01-429f-af5d-adddd56a2963
# ╠═9446cf71-0dd9-4aaf-9f93-5fc80ac8176d
# ╠═fb395623-26e6-4d4f-a418-136ab2fdb6b0
# ╟─a83e3be5-e97a-4945-8c97-1e8ddfa80917
# ╠═9a210aff-9ca5-4df3-a197-9aaf372951eb
# ╠═8e2aa324-0a75-4b7c-beb8-a689d72315a0
# ╠═1dd35fb1-87e5-4fe5-af95-25ba71560e4a
# ╠═bcd3aa5c-f42c-4300-bdee-67a6e4154497
# ╠═177940b1-781b-43e2-a300-091c00313b6f
# ╠═85978b71-25df-4aa1-93d1-4a236b6f2110
# ╟─3db655ff-4d88-4165-a8ec-e49141bd6d7e
# ╟─b5231b36-ac16-4451-aba8-bb31652e903e
# ╠═5b702c30-d19a-4391-99ba-cc1b0173c1ad
# ╟─59913f9e-3a75-4a98-b7e0-2d4702453f48
# ╟─a08e1c6f-14d4-4d50-ad4f-9682e0780af8
# ╟─37ee5ec0-7264-49de-96ac-948fbafbf0e1
# ╠═4203bd1f-61e4-401f-8c5b-e4c4b3c1d95b
# ╠═8e24417d-8e8c-41ec-b2c7-0a19b518e1c4
# ╠═d611bde5-5c88-4069-975c-92f2d1f354f1
# ╠═4e8037ea-3aab-424a-b0be-f4e7b1e048ac
# ╠═93b8c0d7-d7f9-4d53-9209-fe21d3113aef
# ╟─d483b892-e4db-4207-b427-284d024fa7a8
# ╠═14bc747c-3bf8-4831-a7ea-dda24200ff0d
# ╟─1a6d3e16-753f-47b5-9e05-6405dfd6dfa0
# ╟─49fb6e38-b545-466f-aa84-fcf41e3c1607
# ╟─978f5dfa-ad45-4982-b451-d4afbd430530
# ╠═9a083aa8-d7df-479a-9b3c-6d83812d7930
# ╠═2902eb1a-442e-4a75-a6bd-3fb498c5ddf6
# ╠═876c2320-c6bf-4a71-9c17-d16bd4868b7e
# ╠═d5e28e66-b609-44c0-8fc1-7a15d2034be2
# ╟─60093202-d8fd-4e78-b76f-2bc69775eacb
# ╟─b269b4e8-8738-4abd-a4ab-7c1682252f9b
# ╟─f15244e7-8b92-4972-8af0-ea689a83f700
# ╠═69e35f64-1429-413e-8e11-8b785251ddcd
# ╟─11f8a810-830d-47cd-902e-8fe96aca1149
# ╟─f84dd0b3-fef4-4f52-b9d6-e09197e8d49a
# ╟─c20d320d-8bc3-4407-91ad-7b98a9956090
# ╠═aad3dddf-c6b1-4c60-94fd-b7a31861aa7c
# ╠═a57c204a-e329-4ad9-a3d7-a88b3020efbd
# ╠═90585941-f47d-4e48-b2e4-ebe402cbd29c
# ╠═0b65c669-1f2b-4bc2-8f7b-d30a1b19a1db
# ╟─d3c47968-1b79-44cc-8625-58fa5c82990a
# ╠═f08a7392-5f7e-45f8-a713-adb51eb43a7e
# ╟─3979717b-c8d8-4a30-ae36-f923e702d484
# ╠═3f344124-fd06-453d-ad16-c9d1e62fb9bd
# ╠═5f572c39-66af-4adf-9e16-7462422b7254
# ╠═7fd5e1f7-3ac5-4f9e-8c6c-dc6a397bdc13
# ╠═f500571a-0726-49f7-8ac2-884eb9a26728
# ╠═5c3cc925-4873-4d90-9911-a9dc927c9228
# ╠═c3dbf98a-a629-4188-abe2-9d8792b0f8f5
# ╠═c0c1651b-9343-439a-b4c1-d5c37cbdf494
# ╟─3d6beb54-a1e1-4373-b759-d335a0a73e54
# ╟─1d0f5763-e7a4-4dd5-8a12-1a229c245cb8
# ╟─1c868eb8-988d-469a-a0d5-4e640030afdc
# ╠═9e246b82-e6b2-4e70-9d04-29a3ad8ccc26
# ╟─663bf708-3587-4b89-9310-6762ad6a7fc4
# ╠═644724b7-5104-460d-ace9-93432e41fe2e
# ╟─99ceea1c-cfc3-413e-bd7e-199f0dd37f74
# ╠═f26973b0-f952-46b8-89fc-3e3ec53c7d7a
# ╠═3585b48e-2a72-43a3-a66e-dfa539a3f473
# ╠═82ecf1cb-88d1-47ab-a70b-3472f5450dc8
# ╠═41ada7f5-4d9c-4611-9cba-cc761847e082
# ╠═111edbf4-218a-4f69-a42a-ed1ee5291d74
# ╠═a63c2727-5620-4d96-a2c2-1c156d361dc9
# ╠═7b7e6228-0e38-4c3f-807c-1444cfd23968
# ╠═5abf32f0-bc53-4369-b537-023ed6f4c83b
# ╠═be00f1de-8eef-457c-a300-36f4010fc2b7
# ╠═d6bb2f8e-8f69-4001-92fa-dbd321785799
# ╟─176a75bd-f0c5-4e68-8045-7319333d4052
# ╠═a0819e29-a1c1-4bd5-8ca8-a087946b0247
# ╠═2acabb56-87fe-4242-a497-c1d43e3ecdfb
# ╠═b8ba3334-b2b4-45b3-b9f3-7470502f803b
# ╠═9b7a0beb-852f-410d-8dab-f133911485db
# ╟─8e5ad5e5-915c-494f-8026-8e7db6fe3fb6
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
