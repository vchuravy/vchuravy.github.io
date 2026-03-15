### A Pluto.jl notebook ###
# v0.20.24

#> [frontmatter]
#> chapter = "1"
#> section = "3"
#> order = "3"
#> title = "Performance Engineering"
#> date = "2025-04-30"
#> tags = ["module1", "track_performance"]
#> layout = "layout.jlhtml"
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

# ╔═╡ 08e3642e-8e06-4906-b235-1b31bdc1eb42
with_terminal() do
	@code_warntype sum(data)
end

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

# ╔═╡ 978f5dfa-ad45-4982-b451-d4afbd430530
md"""
### Instrumentation

It can be hard to correlate profiles with our programs, instrumentation makes it easier to define semantically important portions.

- [TimerOutputs](https://github.com/KristofferC/TimerOutputs.jl)
- [NVTX](https://github.com/JuliaGPU/NVTX.jl)
- [Tracy](https://github.com/topolarity/Tracy.jl)
- [IntelITT.jl](https://github.com/JuliaPerf/IntelITT.j)

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

# ╔═╡ Cell order:
# ╠═25935904-4644-4ce2-83e9-d08c22b5e40d
# ╟─820eef38-86d2-4b03-8989-0dc4d4c86929
# ╟─2aeda4bd-aa1c-46fc-8183-79f8c75e5172
# ╠═97f862e8-268b-4bff-8bdc-842aecffc2f1
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
# ╟─fa5243df-79a9-4e36-a14a-18d20babbd08
# ╟─faf4b6b2-e191-4af1-9527-c8cb3e9f6e71
# ╟─898ad034-31b8-4ef5-a58e-06757a6d34cb
# ╟─978f5dfa-ad45-4982-b451-d4afbd430530
# ╠═9a083aa8-d7df-479a-9b3c-6d83812d7930
# ╠═2902eb1a-442e-4a75-a6bd-3fb498c5ddf6
# ╠═876c2320-c6bf-4a71-9c17-d16bd4868b7e
# ╠═d5e28e66-b609-44c0-8fc1-7a15d2034be2
# ╟─60093202-d8fd-4e78-b76f-2bc69775eacb
# ╠═b269b4e8-8738-4abd-a4ab-7c1682252f9b
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
# ╠═3d6beb54-a1e1-4373-b759-d335a0a73e54
# ╠═1d0f5763-e7a4-4dd5-8a12-1a229c245cb8
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
