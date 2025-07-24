### A Pluto.jl notebook ###
# v0.20.13

#> [frontmatter]
#> title = "Summer of Programming Languages: Julia"
#> license = "MIT"
#> 
#>     [[frontmatter.author]]
#>     name = "Valentin Churavy"
#>     image = "https://avatars.githubusercontent.com/u/145258?v=4"
#>     url = "https://vchuravy.dev"
#>     [[frontmatter.author]]
#>     name = "Mosè Giordano"

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

# ╔═╡ 83fd4129-f9bf-47af-a9ea-505511909ebe
begin
	using PlutoUI, PlutoTeachingTools
	using PlutoUI: Slider
	PlutoUI.TableOfContents(; depth=4)
end

# ╔═╡ ba43faa3-6752-49ac-87e3-8dbd896ad38a
begin
	using CairoMakie
	set_theme!(theme_latexfonts();
			   fontsize = 16,
			   Lines = (linewidth = 2,),
			   markersize = 16)
end

# ╔═╡ ded87217-cdc0-48de-9bbd-d5ac81f2f873
using CondaPkg; CondaPkg.add("seaborn")

# ╔═╡ 1a7f20f9-a69c-49a2-a012-ed59657cc29f
using PythonCall, RDatasets

# ╔═╡ 03ee0f1f-ca85-4690-83c1-22dcb3519f09
using PairPlots

# ╔═╡ e036e0b1-60f5-4670-9956-15e74d010ee9
using MPI, Serialization, StaticArrays

# ╔═╡ 0e88ed74-261d-4aad-82dc-ed8076684406
using Measurements

# ╔═╡ 9b48b14c-2222-4275-b63c-0d3206bb13ad
using Unitful

# ╔═╡ dac9fce8-80b2-4d43-a6ac-c0c13612987d
using OrdinaryDiffEqTsit5

# ╔═╡ ee513355-3149-4235-bdfd-79b80d317103
using StochasticRounding

# ╔═╡ 76440f57-0381-423c-aa50-1fa830876b20
using Statistics

# ╔═╡ 2c753716-0af8-4e9a-ad79-e06eb35db64f


# ╔═╡ 63ba95f0-0a04-11ee-30b5-65d2b018e857
md"""
# Summer of Programming Languages: Julia
**Julia for Research Software Engineering**
"""

# ╔═╡ 38bd2812-84ed-4c07-a3c1-a647803b0541
md"""
[https://vchuravy.dev/talks/summer\_of\_rse/](https://vchuravy.dev/talks/summer_of_rse/)
"""

# ╔═╡ 6fc6fe75-b249-48cc-9e85-6c942cb56b86
md"""
## Who are we?

###### Valentin Churavy
RSE/PostDoc working on the Julia compiler and runtime.
My goal is to make HPC and GPU based programming easier and more accessible,
I work with science teams to help them maximise their usage of Julia.

###### Mosè Giordano

RSE at UCL, working of various HPC-related projects.
My not-so-secret mission is to spread the use of Julia in HPC.
"""

# ╔═╡ 26178e23-33e5-4294-bb03-c54b29fa6dd1


# ╔═╡ 1c983ad9-bd78-422c-a703-97f0a3d08b91
md"""
## What's Julia? 🟢 🟣 🔴

Julia is a modern, dynamic, general-purpose, compiled programming language.
It's interactive ("like Python"), can be used in a REPL or notebooks, like Jupyter (it's the "Ju") or Pluto (this one🎈).
Julia has a runtime which includes a just-in-time (JIT) compiler and a garbage collector (GC), for automatic memory management.

Julia is mainly used for technical computing, and addresses a gap in the programming language landscape for numerical computing.


Main paradigm of Julia is multiple dispatch, what functions do depend on type and number of _all_ arguments.
"""

# ╔═╡ 573ac61e-7c9f-41cc-baa6-7c4216432f5e


# ╔═╡ 787967f5-78f0-41d3-b786-078dfe3c5a8d
md"""
## Why Julia? 😍

* Explorable & Understandable
* Composability thanks to multiple dispatch
* User-defined types are as fast and compact as built-ins
* Code that is close to the mathematics
* No need to switch languages for performance...
* ...but you can still call C-like shared libraries with simple Foreign Function Interface (FFI) if you want to
* MIT licensed: free and open source
"""

# ╔═╡ de2c0e2c-d462-4ba4-ade3-451e7c1c8783


# ╔═╡ 2e9c1107-4378-4afb-b2e7-3c86f72473fa
md"""
## What is the 2 language problem?

You start out proto-typing in one language (high-level, dynamic), but performance forces you to switch to a different one (low-level, static).

- For convinience use a scripting language (Python, R, Matlab, ...)
- but do all the hard stuff in a systems language (C, C++, Fortran)

Pragmatic for many applications, but has drawbacks

- aren't the hard parts exactly where you need an easier language
- creates a social barrier -- a wall between users and developers
- "sandwich problem" -- layering of system & user code is expensive
- prohibits full stack optimisations

## Julia for RSEs?

**Tearing down barriers of collaboration**

- Fostering collaboration
- Low-barrier from package user to package developer
- One codebase to rule them all
- Understandable and explorable performance

!!! info
    Native test-framework and wide-adoption of CI through-out the ecosystem!

## Julia now!

- Recently released v1.11, comming soon v1.12
- Stable language foundation
- Vibrant package ecosystem
- Yearly developer conference, all talks and workshops on Youtube.
- Excellent native GPU computing support
"""

# ╔═╡ 5ddcd487-5751-45ad-94f5-801318818207


# ╔═╡ b80a8dd9-f3fd-4ff4-8190-3132e07762fc
md"""
## Getting started with Julia

!!! info 
    [Modern Julia Workflows](https://modernjuliaworkflows.org/) is an excellent resource to get started with. 

#### Installation

Use `juliaup`
```shell
curl -fsSL https://install.julialang.org | sh
```

##### Resources

- Modern Julia Workflows: [https://modernjuliaworkflows.org](https://modernjuliaworkflows.org)
- Discourse: [https://discourse.julialang.org](https://discourse.julialang.org)
- Documentation: [https://docs.julialang.org](https://docs.julialang.org)
- Community Calendar: [https://julialang.org/community/#events](https://julialang.org/community/#events)

"""

# ╔═╡ 03ee88c3-7ca8-4614-9c6d-bd8822d41482


# ╔═╡ faee4e9d-4e85-452b-87d1-4d85c96c677f
md"""
## A brief introduction to Julia
"""

# ╔═╡ 10eb2910-38b3-4102-8e8d-8ef8ec1e31d0
import ForwardDiff

# ╔═╡ 6e00db9e-2879-4cae-9342-9dfec7509b81
md"""
### The Newton method in 1D
based of https://featured.plutojl.org/computational-thinking/newton.html
"""

# ╔═╡ ad3a219b-ce0d-466f-b5c2-20cb882742d5
md"""
We would like to solve equations like $f(x) = g(x)$. 
We rewrite that by moving all the terms to one side of the equation so that we can write $h(x) = 0$, with $h(x) := f(x) - g(x)$.

A point $x^*$ such that $h(x^*) = 0$ is called a **root** or **zero** of $h$.

The Newton method finds zeros, and hence solves the original equation.
"""

# ╔═╡ a6196d15-a9f5-4e1b-9988-85c827d2bd27
md"""
The idea of the Newton method is to *follow the direction in which the function is pointing*! We do this by building a **tangent line** at the current position and following that instead, until it hits the $x$-axis.

Let's look at that visually:
"""

# ╔═╡ a2c827ec-c813-421a-83c9-e593bfdacfb7
md"""
n = $(@bind n2 Slider(0:10, show_value=true, default=1))
"""

# ╔═╡ d9603b23-dff0-41e9-9291-70ebeaf8e7f1
md"""
x₀ = $(@bind x02 Slider(-10:10, show_value=true, default=6))
"""

# ╔═╡ 8096e64f-15d6-4f55-8b08-6f4e130098ee
md"""
n = $(@bind n Slider(0:10, show_value=true, default=1))
"""

# ╔═╡ 3d184ac4-83ca-42ec-96b5-a12a59a0b4a0
md"""
x₀ = $(@bind x0 Slider(-10:10, show_value=true, default=6))
"""

# ╔═╡ ed67a442-9891-4018-adc4-eef06c3efba7
md"""
```julia
function newton(f, n, x0)
	f′ = x -> ForwardDiff.derivative(f, x)
    for i in 1:n
		x0 -= f(x0) / f′(x0)
	end
	return x0
end
```
"""

# ╔═╡ 55c3f97d-509b-407d-b26c-9c6ac5f96936
straight(x0, y0, x, m) = y0 + m * (x - x0)

# ╔═╡ 2573aee2-3cef-430f-a4eb-0e5bf29e2c21
function newton(f, n, x_range, x0, ymin=-10, ymax=10)
    
    f′ = x -> ForwardDiff.derivative(f, x)

	fig = Figure(size=(400, 300))
	ax = Axis(fig[1,1])
	ylims!(ax, ymin, ymax)
	
	lines!(ax, x_range, f)

	hlines!(ax, 0.0, color=:magenta, linestyle=:dash, linewidth=3)
	scatter!(ax, x0, 0, color=:green)
	annotation!(ax, x0, -5, text=L"x_0", fontsize=14)
	
	for i in 1:n
		lines!(ax, [x0, x0], [0, f(x0)], color=:gray, alpha=0.5)
		scatter!(ax, x0, f(x0), color=:red)
		
		m = f′(x0)

		lines!(ax, x_range, [straight(x0, f(x0), x, m) for x in x_range], 		  color=:blue, alpha=0.5, linestyle=:dash, linewidth=2)

		x1 = x0 - f(x0) / m

		scatter!(ax, x1, 0, color = :green)
		annotation!(ax, x1, -5, text=L"x_%$i", fontsize=14) 
		
		x0 = x1

	end
	fig
end

# ╔═╡ e879dcdb-c8aa-41f9-86ec-4588199ab72c
let
	f(x) = x^2 - 2

	newton(f, n2, -1:0.01:10, x02, -10, 70)
end

# ╔═╡ d37fcb33-5d29-401e-ada2-e4bc892cf573
let
	f(x) = 0.2x^3 - 4x + 1
	
	newton(f, n, -10:0.01:10, x0, -10, 70)
end

# ╔═╡ 6c5188ae-10b0-4124-b68b-9d86acbf35de


# ╔═╡ 299f10aa-0ba7-4e67-a4f5-b2a885b379b3
md"""
## Package manager

One package manager, provided together with the language. 

- Native notion of "environment"
- `Project.toml`: Describes the dependencies and compatibilities
- `Manifest.toml`: Record of precise versions of all direct & indirect dependencies


"""

# ╔═╡ d4e70769-687f-46ab-9fbf-a959c2b12f9c
md"""
```sh
> julia --project=example
```

```
(example) pkg> add BenchmarkTools
   Resolving package versions...
    Updating `~/example/Project.toml`
  [6e4b80f9] + BenchmarkTools v1.6.0
    Updating `~/example/Manifest.toml`
  [6e4b80f9] + BenchmarkTools v1.6.0
  [34da2185] + Compat v4.17.0
  [682c06a0] + JSON v0.21.4
    ...
```

```
(example) pkg> status
Status `~/example/Project.toml`
  [6e4b80f9] BenchmarkTools v1.6.0
```

```
(example) pkg> rm BenchmarkTools
    Updating `~/example/Project.toml`
  [6e4b80f9] - BenchmarkTools v1.6.0
    Updating `~/example/Manifest.toml`
  [6e4b80f9] - BenchmarkTools v1.6.0
  [34da2185] - Compat v4.17.0
  [682c06a0] - JSON v0.21.4
```
"""

# ╔═╡ d022561a-780b-4964-86e4-db47a408ed54
md"""
### Binaries included

!!! note
    Major usability pain points of modern languages is the integration of dependencies from C/C++, reliably across multiple operating systems.

Julia provides JLL packages that wrap binaries, and automatically install the **right** one for your current platforms.

Uses:

- Binarybuilder: (https://binarybuilder.org/)
  - Sandboxed cross-compiler
  - Encodes best practices

- Yggdrasil: (https://github.com/JuliaPackaging/Yggdrasil/)
  - Collection of build recipes
"""

# ╔═╡ 54793dd0-52ed-4c07-a75d-cf9132c00647


# ╔═╡ 23a741a2-63e7-4eb4-aa2c-55fa888fd27d
md"""
## Interaction with other languages
"""

# ╔═╡ b1dcb967-cfd4-4961-9c70-d9e027be5eee
md"""
## Interaction with C & Fortran libraries

- Julia has direct foreign call support for C & Fortran
  - [`@ccall`](https://docs.julialang.org/en/v1/base/c/#Base.@ccall)
  - [`Calling C and Fortran`](https://docs.julialang.org/en/v1/manual/calling-c-and-fortran-code)

- Automatic wrapper generation with [Clang.jl](https://github.com/JuliaInterop/Clang.jl)

- `@cfunction` creates a C-function pointer to use as a callback
- Be careful around GC interactions!

"""

# ╔═╡ 2497e952-8220-46e5-a1c5-4c24631bc026
md"""
### Example: UCX.jl

```julia
function ucp_put_nb(ep, buffer, length, remote_addr, rkey, cb)
    ccall(
        (:ucp_put_nb, libucp),
        ucs_status_ptr_t,
        (ucp_ep_h, Ptr{Cvoid}, Csize_t, UInt64, ucp_rkey_h, ucp_send_callback_t),
        ep, buffer, length, remote_addr, rkey, cb)
end
```

```julia
function send_callback(req::Ptr{Cvoid}, status::API.ucs_status_t, user_data::Ptr{Cvoid})
    @assert user_data !== C_NULL
    request = UCXRequest(user_data)
    request.status = status
    notify(request)
    API.ucp_request_free(req)
    nothing
end

function put!(ep::UCXEndpoint, request, data::Ptr, nbytes, remote_addr, rkey)
    cb = @cfunction(send_callback, Cvoid, (Ptr{Cvoid}, API.ucs_status_t, Ptr{Cvoid}))
    ptr = ucp_put_nb(ep, data, nbytes, remote_addr, rkey, cb)
    return handle_request(request, ptr)
end

function put!(ep::UCXEndpoint, buffer, nbytes, remote_addr, rkey)
    request = UCXRequest(ep, buffer) # rooted through ep.worker
    GC.@preserve buffer begin
        data = pointer(buffer)
        put!(ep, request, data, nbytes, remote_addr, rkey)
    end
end
```
"""

# ╔═╡ 8b6e60f0-a09b-41c9-a8bb-90c5b9086870


# ╔═╡ ef7e56fe-7950-4346-9992-b67b2ddbaf78
md"""
### Interaction with Python
	
"""

# ╔═╡ 02e4483d-4e68-4a88-9247-f56e3902ed9b
iris = dataset("datasets", "iris")

# ╔═╡ 1f6fb5c4-d80a-4c46-83cd-7323d9a92e4f
sns = pyimport("seaborn"); sns.set_theme();

# ╔═╡ db3b56fc-000b-4b36-8e2e-812a81d1d902
sns.pairplot(pytable(iris), hue="Species")

# ╔═╡ e492bead-3364-4f53-82d1-de15bc50d411
function pairplot_by(df, column)
	grouped = groupby(df, column)

	colors = Makie.wong_colors()
	default = (
        PairPlots.Scatter(markersize=6),
        PairPlots.MarginDensity()
	)

	series = Any[]
	for (i, key) in enumerate(keys(grouped))
		subdf = select(grouped[key], Not(column))
		push!(series, 
			  PairPlots.Series(subdf, 
							   color=colors[i],
							   label=string(only(key))) => default)
	end
	pairplot(series...)
end

# ╔═╡ b07c4d06-8b81-40c3-ad25-0edd4cced919
pairplot_by(iris, :Species)

# ╔═╡ dd245fa6-91db-4cf4-82df-ee5869dc26be


# ╔═╡ 456e3273-7bcf-4c98-9a31-732ad5d312dd
md"""
## Types and multiple dispatch

Julia is dynamically typed, but types are at the fore-front of programming.
Abstract type hierarchy for method selection and dispatch.

```julia
abstract type Number end
abstract type Real <: Number end
struct Dual{T<:Number} <: Number
	primal::T
	tangent::T
end
```

**Not** object-oriented, but multiple-dispatch/multi-methods based.

### Crash course on multiple dispatch 🪨📜✂️

_Based on the blogpost "[Rock–paper–scissors game in less than 10 lines of code](https://giordano.github.io/blog/2017-11-03-rock-paper-scissors)"._
"""

# ╔═╡ 8f2437a9-45cf-4f8b-9808-11126097928d
begin
	abstract type Shape end
	struct Rock     <: Shape end
	struct Paper    <: Shape end
	struct Scissors <: Shape end
	play(::Type{Paper}, ::Type{Rock})     = "Paper wins"
	play(::Type{Paper}, ::Type{Scissors}) = "Scissors wins"
	play(::Type{Rock},  ::Type{Scissors}) = "Rock wins"
	play(::Type{T},     ::Type{T}) where {T<: Shape} = "Tie, try again"
	play(a::Type{<:Shape}, b::Type{<:Shape}) = play(b, a) # Commutativity
end

# ╔═╡ 7278d4e8-322e-43d6-ab8d-b306c661fbc6
play(Paper, Scissors)

# ╔═╡ 686ff2ce-1f6d-435a-b93b-0d7c9ba6f680
play(Rock, Paper)

# ╔═╡ ec185c9f-7909-47d8-8cc6-05b252d72a5d
play(Scissors, Scissors)

# ╔═╡ 5fc10869-ac5e-4440-ac36-eed90bffef8c
@which play(Rock, Scissors)

# ╔═╡ a9825a63-1915-45c7-afd8-cac52cf7330c
play(Scissors, rand([Scissors, Paper, Rock]))

# ╔═╡ c9418101-649a-4c12-812a-c9cf5cd10c6c


# ╔═╡ f09b6ee6-eea3-480f-b7b8-395b1575fdbe
md"""
## What makes a language dynamic?

- Commonly: Referring to the type system.
  - **Static**: Types are checked before run-time.
  - **Dynamic**: Types are checkd on the fly, during execution
  - Often: The type of a **variable** can change during execution.

- More interestingly: Closed-world vs open-world semantics
  - Can code be added during runtime?
  - Litmus test: The presence of **eval**

- Struct layout:
  - Can one change the fields of a object/class/struct at runtime?

Dynamic semantics are a **spectrum**

Julia has a dynamic type system, open-world semantics, but struct layout is static.
"""

# ╔═╡ d928bb49-1cd2-444a-a8bc-1076ff4647fd


# ╔═╡ c379062d-8b73-4b2a-a1ea-3ed2175ab7d8
md"""
## Compilation of a dynamic language.

Julia uses LLVM for it's compilation pipeline.


### Compiler stages
1. Parsing
2. Lowering
3. Abstract interpretation based type-inference
4. High-level optimizations
5. Codegen to LLVM IR
6. LLVM middle-end
7. LLVM backend
8. Native code
"""

# ╔═╡ 639f9f11-aa65-473b-b24d-44f60b913d83
Meta.@dump 1.0 + 2.0

# ╔═╡ e42751a8-be45-418e-854d-6802ae47d8cd
@code_typed optimize = false 1.0 + 2.0

# ╔═╡ 42f1ca4e-2a03-47a7-be15-20a67c25f020
with_terminal() do
	@code_llvm debuginfo=:none 1.0 + 2.0
end

# ╔═╡ 9c5fb5b0-76b6-4ff8-b4ba-f6a66754241f
with_terminal() do
	@code_native debuginfo=:none 1.0 + 2.0
end

# ╔═╡ 04c84b54-ad4e-4dea-b858-4ec17c25ab0e


# ╔═╡ 3630cd0e-2fb7-4de8-aebf-559933164a61
md"""
## Julia and MPI
"""

# ╔═╡ 0f4a5c91-93cb-4677-afaa-2de023353b23
md"""
The `@mpi` macro executes a block as an MPI program. 

!!! note
    Each block is isolated from another, and as such you need to setup state independently.

!!! warning
    The `@mpi` macro is purely to make MPI work in Pluto for teaching, but should be **not** used for any real uses. Furthermore, always wrap your blocks in `let` and not `begin` to not confuse Pluto.
"""

# ╔═╡ 93da471a-b064-4349-8d69-851f8b5e53ad
np = 4

# ╔═╡ 2f8da3b2-b91e-439c-873f-171e50585d29
macro mpi(np, expr)
	path, io = mktemp()
	control_io_path = path * ".ji"
	println(io, "using MPI, Serialization")
	println(io, "__mpi = begin")
	println(io, expr)
	println(io, "end")
	println(io, """
	__mpi = MPI.gather(__mpi, MPI.COMM_WORLD; root=0)
	if MPI.Comm_rank(MPI.COMM_WORLD) == 0
		Serialization.serialize("$control_io_path", __mpi)
	end
	""")
	close(io)
	quote
		let np = $(esc(np))
			path = $path
			run(`$(mpiexec()) -np $(np) $(Base.julia_cmd()) --project=$(Base.active_project()) $(path)`)
		end
		v = Serialization.deserialize($control_io_path)
		rm($control_io_path)
		all(isnothing, v) ? nothing : v
	end
end

# ╔═╡ fa98c58b-e61b-4762-a89f-58cf6b5a50d0
@mpi np let
	using StaticArrays
	
	MPI.Init()
	comm = MPI.COMM_WORLD

	x = ones(SVector{3, Float64})
	sum = MPI.Allreduce([x], +, comm)

	if MPI.Comm_rank(comm) == 0
		@show sum
	end
	nothing
end

# ╔═╡ c739f61d-7104-4ae4-9934-fc98657fc2fc
md"""
Compute $\int_0^1 \frac{4}{1+x^2} dx = [4 * atan(x)]_0^1$ which evaluates to π
"""

# ╔═╡ 60264a97-d85f-44ef-9012-cc2c3e8b4e03
pis = @mpi np let
	MPI.Init()	
	comm = MPI.COMM_WORLD
	rank = MPI.Comm_rank(comm)

	n = 50_000_000

	s = 0.0
    for i = rank + 1 : MPI.Comm_size(comm) : n 
        x = (i - .5)/n 
        s += 4/(1 + x^2) 
    end
    mypi = s/n
    our_π = MPI.Reduce(mypi, MPI.SUM, comm; root=0)
    if rank == 0
        println("Error our_π - π: $(our_π - π)") 
    end
    mypi
end	

# ╔═╡ 52047e5f-8e1f-4587-a24b-7aab97dd4b6d
our_π = sum(pis)

# ╔═╡ 20422ed4-459b-4486-87fd-afc27d00fc07


# ╔═╡ 1914c723-d9cd-4269-9a3d-ce617c854ce4
md"""
## GPU computing in Julia
"""

# ╔═╡ 9532853d-67b2-4980-a7ea-3fc872694d92
md"""
### Composable infrastructure

#### Core
- [GPUCompiler.jl](https://github.com/JuliaGPU/GPUCompiler.jl): Takes native Julia code and compiles it directly to GPUs
- [GPUArrays.jl](https://github.com/JuliaGPU/GPUArrays.jl): High-level array based common functionality
- [KernelAbstractions.jl](https://github.com/JuliaGPU/KernelAbstractions.jl): Vendor-agnostic kernel programming language
- [Adapt.jl](https://github.com/JuliaGPU/Adapt.jl): Translate complex structs across the host-device boundary

#### Vendor specific
- [CUDA.jl](https://github.com/JuliaGPU/CUDA.jl)
- [AMDGPU.jl](https://github.com/JuliaGPU/AMDGPU.jl)
- [oneAPI.jl](https://github.com/JuliaGPU/oneAPI.jl)
- [Metal.jl](https://github.com/JuliaGPU/Metal.jl)

"""

# ╔═╡ fe95495e-674f-4d0a-a330-8ee9b0d91b6a
md"""
### Different layers of abstraction

#### Vendor-specific
```julia
using CUDA

function saxpy!(a,X,Y)
	i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
	if i <= length(Y)
		@inbounds Y[i] = a * X[i] + Y[i]
	end
	return nothing
end

@cuda threads=32 blocks=cld(length(Y), 32) saxpy!(a, X, Y)
```

#### KernelAbstractions

```julia
using KernelAbstractions
using CUDA

@kernel function saxpy!(a, @Const(X), Y)
    I = @index(Global)
    @inbounds Y[I] = a * X[I] + Y[I]
end

saxpy!(CUDABackend())(a, X, Y, ndrange=length(Y))
```

#### Array abstractions

```julia
Y .= a .* X .+ Y
```

"""

# ╔═╡ f8177941-5884-4233-985d-e7142e6c064b
md"""
#### How to use KernelAbstractions

- Use `@kernel function mykernel(args...) end` to write a GPU-style program
- Instantiate kernel for a backend `kernel = mykernel(backend)`
- Backends come from Vendor specific libraries
- `KA.allocate(backend, ...)` to obtain memory
- Launch kernel `kernel(args..., ndrange=...)` while specifying the grid to execute over.
"""

# ╔═╡ 148b545d-4d38-432e-885f-f6f712c3f12f
TwoColumn(
md"""
```julia
function vadd(a, b, c)
	for i in eachindex(c)
		c[i] = a[i] + b[i]
	end
end



a = rand(N)
b = rand(N)
c = similar(a)

	
vadd(a, b, c)
```
""",
md"""
```julia
import KernelAbstractions as KA
	
@kernel function vadd(a, b, c)
	i = @index(Global)
	c[i] = a[i] + b[i]
end

backend = CUDABackend()
a = KA.allocate(backend, Float32, N)
b = KA.allocate(backend, Float32, N)
c = similar(a)

vadd_kernel = vadd(backend)
vadd_kernel(a, b, c; ndrange=size(c))
```
""")

# ╔═╡ 9358f02a-273d-4747-9dc8-34994e087375
md"""
#### Asynchronous operations

!!! warn
    GPU operations are asynchronous with regards to the host! They are **ordered** with respect to each other, but special care must be taken when using Julia's task based programming together with GPU programming.

The JuliaGPU ecosystem **synchronizes** the GPU on access, so when you move data from and to the GPU we wait for all the kernels to finish!
"""

# ╔═╡ f1d654bb-a970-440d-8591-8363618fb9f7
md"""
!!! note
	When benchmarking you need to synchronize the device!

	```julia
		@benchmark begin 
			vadd_kernel(a, b, c; ndrange=size(c))
			KA.synchronize(backend)
		end
	```
	Otherwise you are only measuring the **launch** of the kernel.
"""

# ╔═╡ ff999e4d-9581-44f7-9ef3-47c496fec310
md"""
### High-level array based programming

Julia and GPUArrays.jl provide support for an efficient GPU programming environment build around array abstractions and higher-order functions.

- **Vocabulary of operations**: `map`, `broadcast`, `scan`, `reduce`, ... 
  Map naturally onto GPU execution models
- **Compiled to efficient code**: multiple dispatch, specialization
  Write generic, reusable applications
- BLAS (matrix-multiply, ...), and other libraries like FFT

> Array operators using multiple dispatch: a design methodology for array implementations in dynamic languages 
> 
> [(doi:10.1145/2627373.2627383)](https://www.doi.org/10.1145/2627373.2627383)

> Rapid software prototyping for heterogeneous and distributed platforms 
>
> [(doi:10.1016/j.advengsoft.2019.02.002)](https://www.doi.org/10.1016/j.advengsoft.2019.02.002)
"""

# ╔═╡ cf29f290-477e-4ac4-99dc-d4705d49ad0e
md"""
Array types -- **where** memory resides and **how** code is executed.

|  |  |
| --- | --- |
|  `A = Matrix{Float64}(undef, 64, 32)`   | CPU   |
|  `A = CuMatrix{Float64}(undef, 64, 32)`   | Nvidia GPU   |
|  `A = ROCMatrix{Float64}(undef, 64, 32)`   | AMD GPU   |

!!! info
    Data movement is explicit.
"""

# ╔═╡ d5e1d232-4a88-45f1-ace5-0f2c1ba47423
md"""
### What makes an application portable?

1. Can I **run** it on a different compute architecture
    1. Different CPU architectures
    2. We live in a mult GPU vendor world
2. Does it **compute** the same thing?
    1. Can I develop on one platform and move to another later?
3. Does it achieve the same **performance**?
4. Can I take advantage of platform **specific** capabilities?

"""

# ╔═╡ 5a3c565c-2a5f-436c-90ba-92ccbb39509d
md"""
### Adapt.jl

[Adapt.jl](https://github.com/JuliaGPU/Adapt.jl) is a lightweight dependency that you can use to convert complex structures from CPU to GPU.

```julia
using Adapt
adapt(CuArray, ::Adjoint{Array})::Adjoint{CuArray}
```

```julia
struct Model{T<:Number, AT<:AbstractArray{T}}
   data::AT
end

Adapt.adapt_structure(to, x::Model) = Model(adapt(to, x.data))


cpu = Model(rand(64, 64));
using CUDA

gpu = adapt(CuArray, cpu)
Model{Float64, CuArray{Float64, 2, CUDA.Mem.DeviceBuffer}}(...)
```
"""

# ╔═╡ 7d5f4c81-6913-4bee-a8e0-e5fe01e436db
md"""
## Shared-memory parallelism

- Julia is task-based (`M:N`-threading, green threads)
- `Channel`, locks and atomics

```julia
function pfib(n::Int)
    if n <= 1
        return n
    end
    t = Threads.@spawn pfib(n-2)
    return pfib(n-1) + fetch(t)::Int
end
```

```julia
using Base.Threads: @threads
function prefix_threads!(⊕, y::AbstractVector)
	l = length(y)
	k = ceil(Int, log2(l))
	# do reduce phase
	for j = 1:k
		@threads for i = 2^j:2^j:min(l, 2^k)
			@inbounds y[i] = y[i - 2^(j - 1)] ⊕ y[i]
		end
	end
	# do expand phase
	for j = (k - 1):-1:1
		@threads for i = 3*2^(j - 1):2^j:min(l, 2^k)
			@inbounds y[i] = y[i - 2^(j - 1)] ⊕ y[i]
		end
	end
	return y
end
A = fill(1, 500_000)
prefix_threads!(+, A)
```

From

> Nash et al., (2021). Basic Threading Examples in JuliaLang v1.3. JuliaCon Proceedings, 1(1), 54, [https://doi.org/10.21105/jcon.00054](https://doi.org/10.21105/jcon.00054)
"""

# ╔═╡ 57e85657-b6de-4d47-94d8-02b54361293d
md"""
!!! note
    [OhMyThreads.jl](https://github.com/JuliaFolds2/OhMyThreads.jl) provides a user-friendly interface beyond `@threads`.
"""

# ╔═╡ 4be44ed7-b08e-4c6d-91ef-48e9a157b072
md"""
## Composability
"""

# ╔═╡ 08a09de0-6950-4a8f-8068-9143857a3bd6
md"""
### Plotting solution of differential equations with numbers with uncertainties and units

#### Radioactive Decay of Carbon-14
"""

# ╔═╡ bbdd1803-648a-4fa9-a392-07dd354ace85
begin
	# Half-life and mean lifetime of radiocarbon, in years
	t_12 = (5730 ± 40) * u"yr"
	τ = t_12 / log(2)
end

# ╔═╡ 41830083-98a4-46b2-9714-afd310a9bf54
begin
	# Setup
	u₀_decay = (1 ± 0) * u"kg" # Initial quantity
	tspan_decay = (0.0, 10000.0) .* u"yr" # Timespan
end

# ╔═╡ 31c8a6e2-a609-4522-912c-c9c7f709f8ab
# Define the problem
radioactivedecay(u, p, t) = - u / τ

# ╔═╡ da264f24-d747-4c0d-a431-14c70955ff4d
begin
	# Pass to solver
	prob_decay = ODEProblem(radioactivedecay, u₀_decay, tspan_decay)
	sol_decay = solve(prob_decay, Tsit5(), reltol = 1e-8 * u"kg")
end

# ╔═╡ 42f4e4dd-a760-4920-98db-103185337f47
# Analytic solution
u_decay = u₀_decay * exp.(- sol_decay.t / τ)

# ╔═╡ f4007ce0-f608-4288-bf8c-9da751f47e89
@bind decay_plot MultiCheckBox(["Numerical", "Analytic"]; default=["Numerical", "Analytic"])

# ╔═╡ c0ce6535-542e-4b7f-95e8-880109981aa6
let
	fig = Figure()
	ax = Axis(fig[1,1], title="Solution")
	if "Numerical" in decay_plot
		lines!(ax, sol_decay.t, sol_decay';
			   label = "Numerical")
		errorbars!(ax, sol_decay.t, sol_decay';
				   label = "Numerical", whiskerwidth=7)
	end
	if "Analytic" in decay_plot
		lines!(ax, sol_decay.t, u_decay;
			   label = "Analytic")
		errorbars!(ax, sol_decay.t, u_decay;
				   label = "Analytic", whiskerwidth=7)
	end
	axislegend(ax; merge = true)
	ax2 = Axis(fig[2,1], title="Error")
	lines!(ax2, sol_decay.t, sol_decay' .- u_decay)
	fig
end

# ╔═╡ c79b4ac1-2ddd-49ee-a32c-66bee0fd9d21
md"""
## Support for a diverse set of numerical datatypes
"""

# ╔═╡ 2b833425-088e-4319-844a-785faf316756
md"""
### Stochastic rounding 🎲

Sometimes randomness can be quite useful!

Real numbers constitue a continuous set $\mathbb{R}$, but finite precision numbers used in computers are a part of a discrete set $F \subset \mathbb{R}$.
When computers do operations involving floating point numbers in $F$, the true result $x \in \mathbb{R}$ will be approximated by a number $\hat{x} \in F$, which is typically chosen deterministically to be the nearest number in $F$: this is called "nearest rounding".

Stochastic rounding is an alternative rounding mode to classic deterministic rounding, which randomly rounds a number $x \in \mathbb{R}$ to either of the two nearest floating point numbers of the result $\lfloor x \rfloor$ (previous number in $F$) or $\lceil x \rceil$ (following number in $F$) with the following rule:

```math
\mathrm{round}(x) = \begin{cases}
\lfloor x \rfloor & \text{with probability } P(x) \\[6pt]
\lceil x \rceil   & \text{with probability } 1 - P(x)
\end{cases}
```

Common choices are $P(x) = 1/2$ or, more interestingly,

```math
P(x) = \frac{x - \lfloor x \rfloor}{\lceil x \rceil - \lfloor x \rfloor}
```

In the following we'll always talk about the latter probability function $P(x)$.

$(Resource("https://nickhigham.files.wordpress.com/2020/06/stoch_round_fig2.jpg"))
(source: "[What Is Stochastic Rounding?](https://nhigham.com/2020/07/07/what-is-stochastic-rounding/)" by Nick Higham)

Stochastic rounding is useful because the _average_ result of operations matches the expected mathematical result.
In a statistical sense, it retains some of the information that is discarded by a deterministic rounding scheme, smoothing out numerical rounding errors due to limited precisions.
This is particularly important when using low-precision floating point numbers like `Float16`.
For contrast, deterministic rounding modes like nearest rounding introduce a bias, which is more severe as the precision of the numbers is lower.

Let's do an exercise on the CPU with classical nearest rounding.
We define a function to do the naive sequential sum of a vector of numbers, because the `sum` function in Julia uses [pairwise summation](https://en.wikipedia.org/wiki/Pairwise_summation), which would have better accuracy.
"""

# ╔═╡ 26352f5f-fb5d-4810-b990-75390e560e67
naive_sum(v) = foldl(+, v)

# ╔═╡ c46665fe-b0cc-40b1-af74-b3fd7ad776ea
x = fill(Float16(0.9), 3000);

# ╔═╡ 3720089a-bba8-47aa-a259-02f00e830fcd
naive_sum(x)

# ╔═╡ 91cda445-5025-433d-b2f6-09061853025b
eps(Float16(2048))

# ╔═╡ bf7cd2b5-e5ff-4f24-b507-286ae8c2ab12
naive_sum(x) ≈ x[1] * length(x)

# ╔═╡ 8f5dcc84-3fcc-4da6-81a7-6aa28ccc18a5
let
	fig = Figure()
	ax = Axis(fig[1,1], title="Accumulative Error", ylabel="Error", xlabel="Number of summations")
	r = 1:length(x)
	err = map(N->foldl(+, view(x, 1:N)), r) .- (0.9 .* r)
	lines!(ax, r, err)
	fig
end

# ╔═╡ fd39b86f-3454-476a-88a5-a8d8abf99266
x_sr = Float16sr.(x);

# ╔═╡ fcd917f9-f93a-4726-999e-59bf92e3aeea
naive_sum(x_sr)

# ╔═╡ 6e233a0e-7c78-4b65-83da-04a31be93933
let
	fig = Figure()
	ax = Axis(fig[1,1], title="Accumulative Error (Stochastic Rounding)", ylabel="Error", xlabel="Number of summations")
	r = 1:length(x_sr)
	for i in 1:5
		# err = cumsum(x_sr) .- (0.9 .* r)
		err = accumulate(+, x_sr) .- (0.9 .* r)
		lines!(ax, r, err)
	end
	fig
end

# ╔═╡ 60714855-9f57-410d-84cf-31d3273d441e
sums_sr = map(_-> naive_sum(x_sr), 1:10000)

# ╔═╡ cfda8bda-cfc9-4fa8-9790-d3206bfc3e19
extrema(sums_sr)

# ╔═╡ 17ad78e6-43ca-44ea-bcae-15e52bde7851
mean(Float64.(sums_sr))

# ╔═╡ 0e254ca8-b0d8-4d64-96ae-e54501f9b744
std(Float64.(sums_sr))

# ╔═╡ 1bac2902-10ef-46cc-8f75-f5326bbdc64b
median(sums_sr)

# ╔═╡ 00f773b8-c632-436d-af00-b599e68fd9e1
let 
	fig = Figure()
	ax = Axis(fig[1,1])
	stephist!(ax, sums_sr, label="Stochastic Rounding", color=:green)
	vlines!(ax, [naive_sum(x),], label="Nearest Rounding")
	vlines!(ax, [x[1] * length(x)], label="True value")
	axislegend(ax; position=:ct)
	fig
end

# ╔═╡ 02fb1cf1-cacb-4676-a1a1-4c43fdde2bb4
md"""
## Static compilation
"""

# ╔═╡ 2b10fe3c-f116-4cf1-ad32-48072f1353a3
md"""
```julia

module C_FHist

using FHist: Hist1D, _fast_bincounts_1d!

Base.@ccallable function hist1d(input::Ptr{Cdouble}, Ninput::Clong, 
								bincounts::Ptr{Cdouble}, Nbincounts::Clong,
								start::Cdouble, step::Cdouble,
								stop::Cdouble)::Cvoid

    np_input = unsafe_wrap(Array{Float64}, input, Ninput, own=false)
    np_bincounts = unsafe_wrap(Array{Float64}, bincounts, Nbincounts, own=false)
    binedges = start:step:stop
    h = Hist1D(; bincounts=np_bincounts, binedges)
    _fast_bincounts_1d!(h, np_input, binedges)
    return nothing
end

end
```
"""

# ╔═╡ 2ce2e87f-56a1-4ae7-a771-7bf3fc2de3cb
md"""
```sh
julia +1.12 --project=.. juliac.jl --output-lib libfhistjl.so --compile-ccallable --experimental --trim C_FHist.jl
```
"""

# ╔═╡ cc4b2a33-6f33-460b-8ac2-1d7a53f879bc
md"""
```python

import ctypes

lib = ctypes.CDLL('./libjlsum.so')
lib.jlsum.argtypes = [
        ctypes.POINTER(ctypes.c_double), ctypes.c_long,
        ]
lib.jlsum.restype = ctypes.c_double
def jlsum(a):
    res = lib.jlsum(
            a.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), 
            ctypes.c_long(len(a)), 
            )
    return res
```
"""

# ╔═╡ 7a8696cd-a587-40c3-827b-ede47869feec
md"""
## Community
"""

# ╔═╡ 4c128164-c772-4551-a108-c3c30500c571
md"""
### JuliaCon

Yearly developer conference (usually late July)! [https://juliacon.org](https://juliacon.org).

Talks are recorded and online on Youtube: [https://www.youtube.com/@TheJuliaLanguage](https://www.youtube.com/@TheJuliaLanguage)

"""

# ╔═╡ 74655914-6c3e-4c19-bf85-fa0a4035b1c3
md"""
### Workgroup meetings

- JuliaGPU
- JuliaHPC

**Community Calendar:** [https://julialang.org/community/#events](https://julialang.org/community/#events)

"""

# ╔═╡ 345e9e3c-ce8c-4758-a5b7-cb027e4ef678
md"""
### Online spaces
"""

# ╔═╡ 70ba8bc7-8cdc-49ae-bfa2-2e96f693c728
md"""
- Discourse: [https://discourse.julialang.org](https://discourse.julialang.org)
- Zulip & Slack: [https://julialang.org/community/#community_channels](https://julialang.org/community/#community_channels)
"""

# ╔═╡ d53d1ed1-c0ab-4f3e-bac7-8db42371f596
md"""
## How to continue

- Modern Julia Workflows: [https://modernjuliaworkflows.org](https://modernjuliaworkflows.org)
- Documentation: [https://docs.julialang.org](https://docs.julialang.org)
- [2025 RSE Course](https://vchuravy.dev/rse-course)
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
CondaPkg = "992eb4ea-22a4-4c89-a5bb-47a3300528ab"
ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
MPI = "da04e1cc-30fd-572f-bb4f-1f8673147195"
Measurements = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
OrdinaryDiffEqTsit5 = "b1df2697-797e-41e3-8120-5422d3b24e4a"
PairPlots = "43a3c2be-4208-490b-832a-a21dcd55d7da"
PlutoTeachingTools = "661c6b06-c737-4d37-b85c-46df65de6f69"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
PythonCall = "6099a3de-0909-46bc-b1f4-468b9a2dfc0d"
RDatasets = "ce6b1742-4840-55fa-b093-852dadbb1d8b"
Serialization = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
StochasticRounding = "3843c9a1-1f18-49ff-9d99-1b4c8a8e97ed"
Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[compat]
CairoMakie = "~0.15.4"
CondaPkg = "~0.2.29"
ForwardDiff = "~1.0.1"
MPI = "~0.20.22"
Measurements = "~2.14.0"
OrdinaryDiffEqTsit5 = "~1.2.0"
PairPlots = "~3.0.2"
PlutoTeachingTools = "~0.4.1"
PlutoUI = "~0.7.68"
PythonCall = "~0.9.26"
RDatasets = "~0.7.7"
StaticArrays = "~1.9.14"
StochasticRounding = "~0.8.3"
Unitful = "~1.23.1"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.11.5"
manifest_format = "2.0"
project_hash = "2544417cebadda0a21df116d9b2a2e9661548111"

[[deps.ADTypes]]
git-tree-sha1 = "be7ae030256b8ef14a441726c4c37766b90b93a3"
uuid = "47edcb42-4c32-4615-8424-f2b9edc5f35b"
version = "1.15.0"
weakdeps = ["ChainRulesCore", "ConstructionBase", "EnzymeCore"]

    [deps.ADTypes.extensions]
    ADTypesChainRulesCoreExt = "ChainRulesCore"
    ADTypesConstructionBaseExt = "ConstructionBase"
    ADTypesEnzymeCoreExt = "EnzymeCore"

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
git-tree-sha1 = "3b86719127f50670efe356bc11073d84b4ed7a5d"
uuid = "7d9f7c33-5ae7-4f3b-8dc6-eff91059b697"
version = "0.1.42"

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
git-tree-sha1 = "f7817e2e585aa6d924fd714df1e2a84be7896c60"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "4.3.0"
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

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.ArrayInterface]]
deps = ["Adapt", "LinearAlgebra"]
git-tree-sha1 = "9606d7832795cbef89e06a550475be300364a8aa"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "7.19.0"

    [deps.ArrayInterface.extensions]
    ArrayInterfaceBandedMatricesExt = "BandedMatrices"
    ArrayInterfaceBlockBandedMatricesExt = "BlockBandedMatrices"
    ArrayInterfaceCUDAExt = "CUDA"
    ArrayInterfaceCUDSSExt = "CUDSS"
    ArrayInterfaceChainRulesCoreExt = "ChainRulesCore"
    ArrayInterfaceChainRulesExt = "ChainRules"
    ArrayInterfaceGPUArraysCoreExt = "GPUArraysCore"
    ArrayInterfaceReverseDiffExt = "ReverseDiff"
    ArrayInterfaceSparseArraysExt = "SparseArrays"
    ArrayInterfaceStaticArraysCoreExt = "StaticArraysCore"
    ArrayInterfaceTrackerExt = "Tracker"

    [deps.ArrayInterface.weakdeps]
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    BlockBandedMatrices = "ffab5731-97b5-5995-9138-79e8c1846df0"
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    CUDSS = "45b445bb-4962-46a0-9369-b4df9d0f772e"
    ChainRules = "082447d4-558c-5d27-93f4-14fc19e9eca2"
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    StaticArraysCore = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

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
git-tree-sha1 = "16351be62963a67ac4083f748fdb3cca58bfd52f"
uuid = "39de3d68-74b9-583c-8d2d-e117c070f3a9"
version = "0.4.7"

[[deps.BFloat16s]]
deps = ["LinearAlgebra", "Printf", "Random"]
git-tree-sha1 = "3b642331600250f592719140c60cf12372b82d66"
uuid = "ab4f0b2a-ad5b-11e8-123f-65d77653426b"
version = "0.5.1"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.BaseDirs]]
git-tree-sha1 = "bca794632b8a9bbe159d56bf9e31c422671b35e0"
uuid = "18cc8868-cbac-4acf-b575-c8ff214dc66f"
version = "1.3.2"

[[deps.BitTwiddlingConvenienceFunctions]]
deps = ["Static"]
git-tree-sha1 = "f21cfd4950cb9f0587d5067e69405ad2acd27b87"
uuid = "62783981-4cbd-42fc-bca8-16325de8dc4b"
version = "0.1.6"

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
deps = ["CpuId", "IfElse", "PrecompileTools", "Static"]
git-tree-sha1 = "5a97e67919535d6841172016c9530fd69494e5ec"
uuid = "2a0fbf3d-bb9c-48f3-b0a9-814d99fd7ab9"
version = "0.2.6"

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

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "PrecompileTools", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings", "WorkerUtilities"]
git-tree-sha1 = "deddd8725e5e1cc49ee205a1964256043720a6c3"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.15"

[[deps.Cairo]]
deps = ["Cairo_jll", "Colors", "Glib_jll", "Graphics", "Libdl", "Pango_jll"]
git-tree-sha1 = "71aa551c5c33f1a4415867fe06b7844faadb0ae9"
uuid = "159f3aea-2a34-519c-b102-8c37f9878175"
version = "1.1.1"

[[deps.CairoMakie]]
deps = ["CRC32c", "Cairo", "Cairo_jll", "Colors", "FileIO", "FreeType", "GeometryBasics", "LinearAlgebra", "Makie", "PrecompileTools"]
git-tree-sha1 = "22c63a303e8d6ff1a02a0933d579dbdb6e0f2925"
uuid = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
version = "0.15.4"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "fde3bf89aead2e723284a8ff9cdf5b551ed700e8"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.18.5+0"

[[deps.Calculus]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "9cb23bbb1127eefb022b022481466c0f1127d430"
uuid = "49dc2e85-a5d0-5ad3-a950-438e2897f1b9"
version = "0.5.2"

[[deps.CategoricalArrays]]
deps = ["DataAPI", "Future", "Missings", "Printf", "Requires", "Statistics", "Unicode"]
git-tree-sha1 = "1568b28f91293458345dabba6a5ea3f183250a61"
uuid = "324d7699-5711-5eae-9e2f-1d82baa6b597"
version = "0.10.8"
weakdeps = ["JSON", "RecipesBase", "SentinelArrays", "StructTypes"]

    [deps.CategoricalArrays.extensions]
    CategoricalArraysJSONExt = "JSON"
    CategoricalArraysRecipesBaseExt = "RecipesBase"
    CategoricalArraysSentinelArraysExt = "SentinelArrays"
    CategoricalArraysStructTypesExt = "StructTypes"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra"]
git-tree-sha1 = "06ee8d1aa558d2833aa799f6f0b31b30cada405f"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.25.2"
weakdeps = ["SparseArrays"]

    [deps.ChainRulesCore.extensions]
    ChainRulesCoreSparseArraysExt = "SparseArrays"

[[deps.CloseOpenIntervals]]
deps = ["Static", "StaticArrayInterface"]
git-tree-sha1 = "05ba0d07cd4fd8b7a39541e31a7b0254704ea581"
uuid = "fb6a15b2-703c-40df-9091-08a04967cfa9"
version = "0.1.13"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "962834c22b66e32aa10f7611c08c8ca4e20749a9"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.8"

[[deps.ColorBrewer]]
deps = ["Colors", "JSON"]
git-tree-sha1 = "e771a63cc8b539eca78c85b0cabd9233d6c8f06f"
uuid = "a2cac450-b92f-5266-8821-25eda20663c8"
version = "0.4.1"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "PrecompileTools", "Random"]
git-tree-sha1 = "a656525c8b46aa6a1c76891552ed5381bb32ae7b"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.30.0"

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
git-tree-sha1 = "0eee5eb66b1cf62cd6ad1b460238e60e4b09400c"
uuid = "38540f10-b2f7-11e9-35d8-d573e4eb0ff2"
version = "0.2.4"

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
git-tree-sha1 = "3a3dfb30697e96a440e4149c8c51bf32f818c0f3"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.17.0"
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
git-tree-sha1 = "e215ba0e9a9e9377f2ed87cf3eb26840c8990585"
uuid = "95dc2771-c249-4cd0-9c9f-1f3b4330693c"
version = "0.1.3"

[[deps.ConcreteStructs]]
git-tree-sha1 = "f749037478283d372048690eb3b5f92a79432b34"
uuid = "2569d6c7-a4a2-43d3-a901-331e8e4be471"
version = "0.2.3"

[[deps.CondaPkg]]
deps = ["JSON3", "Markdown", "MicroMamba", "Pidfile", "Pkg", "Preferences", "Scratch", "TOML", "pixi_jll"]
git-tree-sha1 = "93e81a68a84dba7e652e61425d982cd71a1a0835"
uuid = "992eb4ea-22a4-4c89-a5bb-47a3300528ab"
version = "0.2.29"

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

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "DataStructures", "Future", "InlineStrings", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrecompileTools", "PrettyTables", "Printf", "Random", "Reexport", "SentinelArrays", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "fb61b4812c49343d7ef0b533ba982c46021938a6"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.7.0"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "4e1fe97fdaed23e9dc21d4d664bea76b65fc50a0"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.22"

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
git-tree-sha1 = "5620ff4ee0084a6ab7097a27ba0c19290200b037"
uuid = "927a84f5-c5f4-47a5-9785-b46e178433df"
version = "1.6.4"

[[deps.DiffEqBase]]
deps = ["ArrayInterface", "ConcreteStructs", "DataStructures", "DocStringExtensions", "EnumX", "EnzymeCore", "FastBroadcast", "FastClosures", "FastPower", "FunctionWrappers", "FunctionWrappersWrappers", "LinearAlgebra", "Logging", "Markdown", "MuladdMacro", "Parameters", "PrecompileTools", "Printf", "RecursiveArrayTools", "Reexport", "SciMLBase", "SciMLOperators", "SciMLStructures", "Setfield", "Static", "StaticArraysCore", "Statistics", "SymbolicIndexingInterface", "TruncatedStacktraces"]
git-tree-sha1 = "52af5ee5af4eb6ca03b3782bf65c1e5fc3024c86"
uuid = "2b5f629d-d688-5b77-993f-72d75c75574e"
version = "6.178.0"

    [deps.DiffEqBase.extensions]
    DiffEqBaseCUDAExt = "CUDA"
    DiffEqBaseChainRulesCoreExt = "ChainRulesCore"
    DiffEqBaseDistributionsExt = "Distributions"
    DiffEqBaseEnzymeExt = ["ChainRulesCore", "Enzyme"]
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

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"
version = "1.11.0"

[[deps.Distributions]]
deps = ["AliasTables", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SpecialFunctions", "Statistics", "StatsAPI", "StatsBase", "StatsFuns"]
git-tree-sha1 = "3e6d038b77f22791b8e3472b7c633acea1ecac06"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.120"

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

[[deps.DoubleFloats]]
deps = ["GenericLinearAlgebra", "LinearAlgebra", "Polynomials", "Printf", "Quadmath", "Random", "Requires", "SpecialFunctions"]
git-tree-sha1 = "1ee9bc92a6b862a5ad556c52a3037249209bec1a"
uuid = "497a8b3b-efae-58df-a0af-a86822472b78"
version = "1.4.3"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e3290f2d49e661fbd94046d7e3726ffcb2d41053"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.4+0"

[[deps.EnumX]]
git-tree-sha1 = "bddad79635af6aec424f53ed8aad5d7555dc6f00"
uuid = "4e289a0a-7415-4d19-859d-a7e5c4648b56"
version = "1.0.5"

[[deps.EnzymeCore]]
git-tree-sha1 = "8272a687bca7b5c601c0c24fc0c71bff10aafdfd"
uuid = "f151be2c-9106-41f4-ab19-57ee4f262869"
version = "0.8.12"
weakdeps = ["Adapt"]

    [deps.EnzymeCore.extensions]
    AdaptExt = "Adapt"

[[deps.ExactPredicates]]
deps = ["IntervalArithmetic", "Random", "StaticArrays"]
git-tree-sha1 = "b3f2ff58735b5f024c392fde763f29b057e4b025"
uuid = "429591f6-91af-11e9-00e2-59fbe8cec110"
version = "2.2.8"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "d55dffd9ae73ff72f1c0482454dcf2ec6c6c4a63"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.6.5+0"

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
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "PCRE2_jll", "Zlib_jll", "libaom_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "eaa040768ea663ca695d442be1bc97edfe6824f2"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "6.1.3+0"

[[deps.FFTW]]
deps = ["AbstractFFTs", "FFTW_jll", "LinearAlgebra", "MKL_jll", "Preferences", "Reexport"]
git-tree-sha1 = "797762812ed063b9b94f6cc7742bc8883bb5e69e"
uuid = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
version = "1.9.0"

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

[[deps.FastPower]]
git-tree-sha1 = "5f7afd4b1a3969dc34d692da2ed856047325b06e"
uuid = "a4df4552-cc26-4903-aec0-212e50a0e84b"
version = "1.1.3"

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
git-tree-sha1 = "b66970a70db13f45b7e57fbda1736e1cf72174ea"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.17.0"

    [deps.FileIO.extensions]
    HTTPExt = "HTTP"

    [deps.FileIO.weakdeps]
    HTTP = "cd3eb016-35fb-5094-929b-558a96fad6f3"

[[deps.FilePaths]]
deps = ["FilePathsBase", "MacroTools", "Reexport", "Requires"]
git-tree-sha1 = "919d9412dbf53a2e6fe74af62a73ceed0bce0629"
uuid = "8fc22ac5-c921-52a6-82fd-178b2807b824"
version = "0.8.3"

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
git-tree-sha1 = "6a70198746448456524cb442b8af316927ff3e1a"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "1.13.0"
weakdeps = ["PDMats", "SparseArrays", "Statistics"]

    [deps.FillArrays.extensions]
    FillArraysPDMatsExt = "PDMats"
    FillArraysSparseArraysExt = "SparseArrays"
    FillArraysStatisticsExt = "Statistics"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "05882d6995ae5c12bb5f36dd2ed3f61c98cbb172"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.5"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Zlib_jll"]
git-tree-sha1 = "301b5d5d731a0654825f1f2e906990f7141a106b"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.16.0+0"

[[deps.Format]]
git-tree-sha1 = "9c68794ef81b08086aeb32eeaf33531668d5f5fc"
uuid = "1fa38f19-a742-5d3f-a2b9-30dd87b9d5f8"
version = "1.3.7"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions"]
git-tree-sha1 = "910febccb28d493032495b7009dce7d7f7aee554"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "1.0.1"
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

[[deps.GenericLinearAlgebra]]
deps = ["LinearAlgebra", "Printf", "Random", "libblastrampoline_jll"]
git-tree-sha1 = "37cef077b50d28b2542c1adb4c5427871a759d12"
uuid = "14197337-ba66-59df-a3e3-ca00e7dcff7a"
version = "0.3.18"

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

[[deps.Giflib_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6570366d757b50fabae9f4315ad74d2e40c0560a"
uuid = "59f7168a-df46-5410-90c8-f2779963d0ec"
version = "5.2.3+0"

[[deps.Glib_jll]]
deps = ["Artifacts", "GettextRuntime_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE2_jll", "Zlib_jll"]
git-tree-sha1 = "35fbd0cefb04a516104b8e183ce0df11b70a3f1a"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.84.3+0"

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

[[deps.GridLayoutBase]]
deps = ["GeometryBasics", "InteractiveUtils", "Observables"]
git-tree-sha1 = "dc6bed05c15523624909b3953686c5f5ffa10adc"
uuid = "3955a311-db13-416c-9275-1d80ed98e5e9"
version = "0.11.1"

[[deps.Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll"]
git-tree-sha1 = "f923f9a774fcf3f5cb761bfa43aeadd689714813"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "8.5.1+0"

[[deps.Hwloc_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "92f65c4d78ce8cdbb6b68daf88889950b0a99d11"
uuid = "e33a78d0-f292-5ffc-b300-72abe9b543c8"
version = "2.12.1+0"

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
git-tree-sha1 = "7134810b1afce04bbc1045ca1985fbe81ce17653"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.5"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "b6d6bfdd7ce25b0f9b2f6b3dd56b2673a66c8770"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.5"

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
git-tree-sha1 = "0936ba688c6d201805a83da835b55c61a180db52"
uuid = "905a6f67-0a94-5f89-b386-d35d92009cd1"
version = "3.1.11+0"

[[deps.IndirectArrays]]
git-tree-sha1 = "012e604e1c7458645cb8b436f8fba789a51b257f"
uuid = "9b13fd28-a010-5f03-acff-a1bbcff69959"
version = "1.0.0"

[[deps.Inflate]]
git-tree-sha1 = "d1b1b796e47d94588b3757fe84fbf65a5ec4a80d"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.5"

[[deps.InlineStrings]]
git-tree-sha1 = "8594fac023c5ce1ef78260f24d1ad18b4327b420"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.4.4"

    [deps.InlineStrings.extensions]
    ArrowTypesExt = "ArrowTypes"
    ParsersExt = "Parsers"

    [deps.InlineStrings.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"
    Parsers = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"

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
deps = ["Adapt", "AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "Requires", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "88a101217d7cb38a7b481ccd50d21876e1d1b0e0"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.15.1"
weakdeps = ["Unitful"]

    [deps.Interpolations.extensions]
    InterpolationsUnitfulExt = "Unitful"

[[deps.IntervalArithmetic]]
deps = ["CRlibm", "MacroTools", "OpenBLASConsistentFPCSR_jll", "Random", "RoundingEmulator"]
git-tree-sha1 = "79342df41c3c24664e5bf29395cfdf2f2a599412"
uuid = "d1acc4aa-44c8-5952-acd4-ba5d80a2a253"
version = "0.22.36"

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
git-tree-sha1 = "5fbb102dcb8b1a858111ae81d56682376130517d"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.7.11"
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

[[deps.InvertedIndices]]
git-tree-sha1 = "6da3c4316095de0f5ee2ebd875df8721e7e0bdbe"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.1"

[[deps.IrrationalConstants]]
git-tree-sha1 = "e2222959fbc6c19554dc15174c81bf7bf3aa691c"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.4"

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
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.JSON3]]
deps = ["Dates", "Mmap", "Parsers", "PrecompileTools", "StructTypes", "UUIDs"]
git-tree-sha1 = "411eccfe8aba0814ffa0fdf4860913ed09c34975"
uuid = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
version = "1.14.3"

    [deps.JSON3.extensions]
    JSON3ArrowExt = ["ArrowTypes"]

    [deps.JSON3.weakdeps]
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
git-tree-sha1 = "eac1206917768cb54957c65a615460d87b455fc1"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.1.1+0"

[[deps.KernelDensity]]
deps = ["Distributions", "DocStringExtensions", "FFTW", "Interpolations", "StatsBase"]
git-tree-sha1 = "ba51324b894edaf1df3ab16e2cc6bc3280a2f1a7"
uuid = "5ab0869b-81aa-558d-bb23-cbf5423bbe9b"
version = "0.6.10"

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
deps = ["Format", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "OrderedCollections", "Requires"]
git-tree-sha1 = "4f34eaabe49ecb3fb0d58d6015e32fd31a733199"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.16.8"

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
git-tree-sha1 = "a31572773ac1b745e0343fe5e2c8ddda7a37e997"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.41.0+0"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "XZ_jll", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "4ab7581296671007fc33f07a721631b8855f4b1d"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.7.1+0"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "321ccef73a96ba828cd51f2ab5b9f917fa73945a"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.41.0+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.11.0"

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

[[deps.MCMCDiagnosticTools]]
deps = ["AbstractFFTs", "DataAPI", "DataStructures", "Distributions", "LinearAlgebra", "MLJModelInterface", "Random", "SpecialFunctions", "Statistics", "StatsBase", "StatsFuns", "Tables"]
git-tree-sha1 = "a586f05dd16a50c490ed95415b2a829b8cf5d57f"
uuid = "be115224-59cd-429b-ad48-344e309966f0"
version = "0.3.14"

[[deps.MIMEs]]
git-tree-sha1 = "c64d943587f7187e751162b3b84445bbbd79f691"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "1.1.0"

[[deps.MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "oneTBB_jll"]
git-tree-sha1 = "282cadc186e7b2ae0eeadbd7a4dffed4196ae2aa"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2025.2.0+0"

[[deps.MLJModelInterface]]
deps = ["InteractiveUtils", "REPL", "Random", "ScientificTypesBase", "StatisticalTraits"]
git-tree-sha1 = "ccaa3f7938890ee8042cc970ba275115428bd592"
uuid = "e80e1ace-859a-464e-9ed9-23947d8ae3ea"
version = "1.12.0"

[[deps.MPI]]
deps = ["Distributed", "DocStringExtensions", "Libdl", "MPICH_jll", "MPIPreferences", "MPItrampoline_jll", "MicrosoftMPI_jll", "OpenMPI_jll", "PkgVersion", "PrecompileTools", "Requires", "Serialization", "Sockets"]
git-tree-sha1 = "892676019c58f34e38743bc989b0eca5bce5edc5"
uuid = "da04e1cc-30fd-572f-bb4f-1f8673147195"
version = "0.20.22"

    [deps.MPI.extensions]
    AMDGPUExt = "AMDGPU"
    CUDAExt = "CUDA"

    [deps.MPI.weakdeps]
    AMDGPU = "21141c5a-9bdb-4563-92ae-f87d6854732e"
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"

[[deps.MPICH_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Hwloc_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "MPIPreferences", "TOML"]
git-tree-sha1 = "d72d0ecc3f76998aac04e446547259b9ae4c265f"
uuid = "7cb0a576-ebde-5e09-9194-50597f1243b4"
version = "4.3.1+0"

[[deps.MPIPreferences]]
deps = ["Libdl", "Preferences"]
git-tree-sha1 = "c105fe467859e7f6e9a852cb15cb4301126fac07"
uuid = "3da0fdf6-3ccc-4f1b-acd9-58baa6c99267"
version = "0.1.11"

[[deps.MPItrampoline_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "MPIPreferences", "TOML"]
git-tree-sha1 = "e214f2a20bdd64c04cd3e4ff62d3c9be7e969a59"
uuid = "f1f71cc9-e9ae-5b93-9b94-4fe0e1ad3748"
version = "5.5.4+0"

[[deps.MacroTools]]
git-tree-sha1 = "1e0228a030642014fe5cfe68c2c0a818f9e3f522"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.16"

[[deps.Makie]]
deps = ["Animations", "Base64", "CRC32c", "ColorBrewer", "ColorSchemes", "ColorTypes", "Colors", "ComputePipeline", "Contour", "Dates", "DelaunayTriangulation", "Distributions", "DocStringExtensions", "Downloads", "FFMPEG_jll", "FileIO", "FilePaths", "FixedPointNumbers", "Format", "FreeType", "FreeTypeAbstraction", "GeometryBasics", "GridLayoutBase", "ImageBase", "ImageIO", "InteractiveUtils", "Interpolations", "IntervalSets", "InverseFunctions", "Isoband", "KernelDensity", "LaTeXStrings", "LinearAlgebra", "MacroTools", "Markdown", "MathTeXEngine", "Observables", "OffsetArrays", "PNGFiles", "Packing", "Pkg", "PlotUtils", "PolygonOps", "PrecompileTools", "Printf", "REPL", "Random", "RelocatableFolders", "Scratch", "ShaderAbstractions", "Showoff", "SignedDistanceFields", "SparseArrays", "Statistics", "StatsBase", "StatsFuns", "StructArrays", "TriplotBase", "UnicodeFun", "Unitful"]
git-tree-sha1 = "96d73e05b6f3079df0963b66c2844d162263a896"
uuid = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
version = "0.24.4"

[[deps.ManualMemory]]
git-tree-sha1 = "bcaef4fc7a0cfe2cba636d84cda54b5e4e4ca3cd"
uuid = "d125e4d3-2237-4719-b19c-fa641b8a4667"
version = "0.1.8"

[[deps.MappedArrays]]
git-tree-sha1 = "2dab0221fe2b0f2cb6754eaa743cc266339f527e"
uuid = "dbb5928d-eab1-5f90-85c2-b9b0edb7c900"
version = "0.4.2"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.MathTeXEngine]]
deps = ["AbstractTrees", "Automa", "DataStructures", "FreeTypeAbstraction", "GeometryBasics", "LaTeXStrings", "REPL", "RelocatableFolders", "UnicodeFun"]
git-tree-sha1 = "6e64d2321257cc52f47e193407d0659ea1b2b431"
uuid = "0a4f8689-d25c-4efe-a92b-7142dfc1aa53"
version = "0.6.5"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.6+0"

[[deps.Measurements]]
deps = ["Calculus", "LinearAlgebra", "Printf"]
git-tree-sha1 = "030f041d5502dbfa41f26f542aaac32bcbe89a64"
uuid = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
version = "2.14.0"

    [deps.Measurements.extensions]
    MeasurementsBaseTypeExt = "BaseType"
    MeasurementsJunoExt = "Juno"
    MeasurementsMakieExt = "Makie"
    MeasurementsRecipesBaseExt = "RecipesBase"
    MeasurementsSpecialFunctionsExt = "SpecialFunctions"
    MeasurementsUnitfulExt = "Unitful"

    [deps.Measurements.weakdeps]
    BaseType = "7fbed51b-1ef5-4d67-9085-a4a9b26f478c"
    Juno = "e5e0dc1b-0480-54bc-9374-aad01c23163d"
    Makie = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
    RecipesBase = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
    SpecialFunctions = "276daf66-3868-5448-9aa4-cd146d93841b"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.Measures]]
git-tree-sha1 = "c13304c81eec1ed3af7fc20e75fb6b26092a1102"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.2"

[[deps.MicroMamba]]
deps = ["Pkg", "Scratch", "micromamba_jll"]
git-tree-sha1 = "011cab361eae7bcd7d278f0a7a00ff9c69000c51"
uuid = "0b3b1443-0f03-428d-bdfb-f27f9c1191ea"
version = "0.1.14"

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

[[deps.Mocking]]
deps = ["Compat", "ExprTools"]
git-tree-sha1 = "2c140d60d7cb82badf06d8783800d0bcd1a7daa2"
uuid = "78c3b35d-d492-501b-9361-3d52fe80e533"
version = "0.8.1"

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

[[deps.NamedTupleTools]]
git-tree-sha1 = "90914795fc59df44120fe3fff6742bb0d7adb1d0"
uuid = "d9ec5142-1e00-5aa0-9d6a-321866360f50"
version = "0.14.3"

[[deps.Netpbm]]
deps = ["FileIO", "ImageCore", "ImageMetadata"]
git-tree-sha1 = "d92b107dbb887293622df7697a2223f9f8176fcd"
uuid = "f09324ee-3d7c-5217-9330-fc30815ba969"
version = "1.1.1"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.Observables]]
git-tree-sha1 = "7438a59546cf62428fc9d1bc94729146d37a7225"
uuid = "510215fc-4207-5dde-b226-833fc4488ee2"
version = "0.5.5"

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
git-tree-sha1 = "567515ca155d0020a45b05175449b499c63e7015"
uuid = "6cdc7f73-28fd-5e50-80fb-958a8875b1af"
version = "0.3.29+0"

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
git-tree-sha1 = "8292dd5c8a38257111ada2174000a33745b06d4e"
uuid = "18a262bb-aa17-5467-a713-aee519bc75cb"
version = "3.2.4+0"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.5+0"

[[deps.OpenMPI_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Hwloc_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "MPIPreferences", "TOML", "Zlib_jll"]
git-tree-sha1 = "ec764453819f802fc1e144bfe750c454181bd66d"
uuid = "fe0851c0-eecd-5654-98d4-656369965a5c"
version = "5.0.8+0"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "87510f7292a2b21aeff97912b0898f9553cc5c2c"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.5.1+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1346c9208249809840c91b26703912dff463d335"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.6+0"

[[deps.Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c392fc5dd032381919e3b22dd32d6443760ce7ea"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.5.2+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "05868e21324cede2207c6f0f466b4bfef6d5e7ee"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.8.1"

[[deps.OrdinaryDiffEqCore]]
deps = ["ADTypes", "Accessors", "Adapt", "ArrayInterface", "DataStructures", "DiffEqBase", "DocStringExtensions", "EnumX", "FastBroadcast", "FastClosures", "FastPower", "FillArrays", "FunctionWrappersWrappers", "InteractiveUtils", "LinearAlgebra", "Logging", "MacroTools", "MuladdMacro", "Polyester", "PrecompileTools", "Preferences", "RecursiveArrayTools", "Reexport", "SciMLBase", "SciMLOperators", "SciMLStructures", "SimpleUnPack", "Static", "StaticArrayInterface", "StaticArraysCore", "SymbolicIndexingInterface", "TruncatedStacktraces"]
git-tree-sha1 = "1bd20b621e8dee5f2d170ae31631bf573ab77eec"
uuid = "bbf590c4-e513-4bbe-9b18-05decba2e5d8"
version = "1.26.2"

    [deps.OrdinaryDiffEqCore.extensions]
    OrdinaryDiffEqCoreEnzymeCoreExt = "EnzymeCore"
    OrdinaryDiffEqCoreMooncakeExt = "Mooncake"

    [deps.OrdinaryDiffEqCore.weakdeps]
    EnzymeCore = "f151be2c-9106-41f4-ab19-57ee4f262869"
    Mooncake = "da2b9cff-9c12-43a0-ae48-6db2b0edb7d6"

[[deps.OrdinaryDiffEqTsit5]]
deps = ["DiffEqBase", "FastBroadcast", "LinearAlgebra", "MuladdMacro", "OrdinaryDiffEqCore", "PrecompileTools", "Preferences", "RecursiveArrayTools", "Reexport", "Static", "TruncatedStacktraces"]
git-tree-sha1 = "d0b069075f4a5e54b29e412419e5a733a83e6240"
uuid = "b1df2697-797e-41e3-8120-5422d3b24e4a"
version = "1.2.0"

[[deps.PCRE2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "efcefdf7-47ab-520b-bdef-62a2eaa19f15"
version = "10.42.0+1"

[[deps.PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "f07c06228a1c670ae4c87d1276b92c7c597fdda0"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.35"

[[deps.PNGFiles]]
deps = ["Base64", "CEnum", "ImageCore", "IndirectArrays", "OffsetArrays", "libpng_jll"]
git-tree-sha1 = "cf181f0b1e6a18dfeb0ee8acc4a9d1672499626c"
uuid = "f57f5aa1-a3ce-4bc8-8ab9-96f992907883"
version = "0.4.4"

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

[[deps.PairPlots]]
deps = ["Contour", "Distributions", "KernelDensity", "LinearAlgebra", "MCMCDiagnosticTools", "Makie", "Measures", "Missings", "NamedTupleTools", "OrderedCollections", "PolygonOps", "PrecompileTools", "Printf", "Requires", "StaticArrays", "Statistics", "StatsBase", "TableOperations", "Tables"]
git-tree-sha1 = "8f0766f15134453e33e54db20c973f28a41600cd"
uuid = "43a3c2be-4208-490b-832a-a21dcd55d7da"
version = "3.0.2"

    [deps.PairPlots.extensions]
    MCMCChainsExt = "MCMCChains"
    PairPlotsDynamicQuantitiesExt = "DynamicQuantities"
    PairPlotsDynamicUnitfulExt = "Unitful"

    [deps.PairPlots.weakdeps]
    DynamicQuantities = "06fc5a27-2a28-4c7c-a15d-362465fb6821"
    MCMCChains = "c7f686f2-ff18-58e9-bc7b-31028e88f75d"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.Pango_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "FriBidi_jll", "Glib_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "275a9a6d85dc86c24d03d1837a0010226a96f540"
uuid = "36c8627f-9965-5494-a995-c6b170f724f3"
version = "1.56.3+0"

[[deps.Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "34c0e9ad262e5f7fc75b10a9952ca7692cfc5fbe"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.3"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "7d2f8f21da5db6a806faf7b9b292296da42b2810"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.3"

[[deps.Pidfile]]
deps = ["FileWatching", "Test"]
git-tree-sha1 = "2d8aaf8ee10df53d0dfb9b8ee44ae7c04ced2b03"
uuid = "fa939f87-e72e-5be4-a000-7fc836dbe307"
version = "1.3.0"

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
git-tree-sha1 = "3ca9a356cd2e113c420f2c13bea19f8d3fb1cb18"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.4.3"

[[deps.PlutoTeachingTools]]
deps = ["Downloads", "HypertextLiteral", "Latexify", "Markdown", "PlutoUI"]
git-tree-sha1 = "537c439831c0f8d37265efe850ee5c0d9c7efbe4"
uuid = "661c6b06-c737-4d37-b85c-46df65de6f69"
version = "0.4.1"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "Downloads", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "ec9e63bd098c50e4ad28e7cb95ca7a4860603298"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.68"

[[deps.Polyester]]
deps = ["ArrayInterface", "BitTwiddlingConvenienceFunctions", "CPUSummary", "IfElse", "ManualMemory", "PolyesterWeave", "Static", "StaticArrayInterface", "StrideArraysCore", "ThreadingUtilities"]
git-tree-sha1 = "6f7cd22a802094d239824c57d94c8e2d0f7cfc7d"
uuid = "f517fe37-dbe3-4b94-8317-1923a5111588"
version = "0.7.18"

[[deps.PolyesterWeave]]
deps = ["BitTwiddlingConvenienceFunctions", "CPUSummary", "IfElse", "Static", "ThreadingUtilities"]
git-tree-sha1 = "645bed98cd47f72f67316fd42fc47dee771aefcd"
uuid = "1d0040c9-8b98-4ee7-8388-3f51789ca0ad"
version = "0.2.2"

[[deps.PolygonOps]]
git-tree-sha1 = "77b3d3605fc1cd0b42d95eba87dfcd2bf67d5ff6"
uuid = "647866c9-e3ac-4575-94e7-e3d426903924"
version = "0.1.2"

[[deps.Polynomials]]
deps = ["LinearAlgebra", "OrderedCollections", "RecipesBase", "Requires", "Setfield", "SparseArrays"]
git-tree-sha1 = "972089912ba299fba87671b025cd0da74f5f54f7"
uuid = "f27b6e38-b328-58d1-80ce-0feddd5e7a45"
version = "4.1.0"

    [deps.Polynomials.extensions]
    PolynomialsChainRulesCoreExt = "ChainRulesCore"
    PolynomialsFFTWExt = "FFTW"
    PolynomialsMakieExt = "Makie"
    PolynomialsMutableArithmeticsExt = "MutableArithmetics"

    [deps.Polynomials.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    FFTW = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
    Makie = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
    MutableArithmetics = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "36d8b4b899628fb92c2749eb488d884a926614d3"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.3"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "5aa36f7049a63a1528fe8f7c3f2113413ffd4e1f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.1"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "9306f6085165d270f7e3db02af26a400d580f5c6"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.3"

[[deps.PrettyTables]]
deps = ["Crayons", "LaTeXStrings", "Markdown", "PrecompileTools", "Printf", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "1101cd475833706e4d0e7b122218257178f48f34"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "2.4.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"
version = "1.11.0"

[[deps.ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "13c5103482a8ed1536a54c08d0e742ae3dca2d42"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.10.4"

[[deps.PtrArrays]]
git-tree-sha1 = "1d36ef11a9aaf1e8b74dacc6a731dd1de8fd493d"
uuid = "43287f4e-b6f4-7ad1-bb20-aadabca52c3d"
version = "1.3.0"

[[deps.PythonCall]]
deps = ["CondaPkg", "Dates", "Libdl", "MacroTools", "Markdown", "Pkg", "Requires", "Serialization", "Tables", "UnsafePointers"]
git-tree-sha1 = "f03464b21983fb5af2f8cea99106b8d8f48ac69d"
uuid = "6099a3de-0909-46bc-b1f4-468b9a2dfc0d"
version = "0.9.26"

[[deps.QOI]]
deps = ["ColorTypes", "FileIO", "FixedPointNumbers"]
git-tree-sha1 = "8b3fc30bc0390abdce15f8822c889f669baed73d"
uuid = "4b34888f-f399-49d4-9bb3-47ed5cae4e65"
version = "1.0.1"

[[deps.QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "9da16da70037ba9d701192e27befedefb91ec284"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.11.2"

    [deps.QuadGK.extensions]
    QuadGKEnzymeExt = "Enzyme"

    [deps.QuadGK.weakdeps]
    Enzyme = "7da242da-08ed-463a-9acd-ee780be4f1d9"

[[deps.Quadmath]]
deps = ["Compat", "Printf", "Random", "Requires"]
git-tree-sha1 = "6bc924717c495f24de85867aa94da4de0e6cd1a1"
uuid = "be4d8f0f-7fa4-5f49-b795-2f01399ab2dd"
version = "0.5.13"

[[deps.RData]]
deps = ["CategoricalArrays", "CodecZlib", "DataFrames", "Dates", "FileIO", "Requires", "TimeZones", "Unicode"]
git-tree-sha1 = "19e47a495dfb7240eb44dc6971d660f7e4244a72"
uuid = "df47a6cb-8c03-5eed-afd8-b6050d6c41da"
version = "0.8.3"

[[deps.RDatasets]]
deps = ["CSV", "CodecZlib", "DataFrames", "FileIO", "Printf", "RData", "Reexport"]
git-tree-sha1 = "2720e6f6afb3e562ccb70a6b62f8f308ff810333"
uuid = "ce6b1742-4840-55fa-b093-852dadbb1d8b"
version = "0.7.7"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "StyledStrings", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"
version = "1.11.0"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
version = "1.11.0"

[[deps.RandomNumbers]]
deps = ["Random"]
git-tree-sha1 = "c6ec94d2aaba1ab2ff983052cf6a606ca5985902"
uuid = "e6cf234a-135c-5ec9-84dd-332b85af5143"
version = "1.6.0"

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
deps = ["Adapt", "ArrayInterface", "DocStringExtensions", "GPUArraysCore", "IteratorInterfaceExtensions", "LinearAlgebra", "RecipesBase", "StaticArraysCore", "Statistics", "SymbolicIndexingInterface", "Tables"]
git-tree-sha1 = "4dd1a95cc16d5abdccc4eac5faf6bc73904be1a2"
uuid = "731186ca-8d62-57ce-b412-fbd966d074cd"
version = "3.35.0"

    [deps.RecursiveArrayTools.extensions]
    RecursiveArrayToolsFastBroadcastExt = "FastBroadcast"
    RecursiveArrayToolsForwardDiffExt = "ForwardDiff"
    RecursiveArrayToolsKernelAbstractionsExt = "KernelAbstractions"
    RecursiveArrayToolsMeasurementsExt = "Measurements"
    RecursiveArrayToolsMonteCarloMeasurementsExt = "MonteCarloMeasurements"
    RecursiveArrayToolsReverseDiffExt = ["ReverseDiff", "Zygote"]
    RecursiveArrayToolsSparseArraysExt = ["SparseArrays"]
    RecursiveArrayToolsStructArraysExt = "StructArrays"
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
    StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
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
git-tree-sha1 = "852bd0f55565a9e973fcfee83a84413270224dc4"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.8.0"

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
git-tree-sha1 = "86a8a8b783481e1ea6b9c91dd949cb32191f8ab4"
uuid = "7e49a35a-f44a-4d26-94aa-eba1b4ca6b47"
version = "0.5.15"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SIMD]]
deps = ["PrecompileTools"]
git-tree-sha1 = "fea870727142270bdf7624ad675901a1ee3b4c87"
uuid = "fdea26ae-647d-5447-a871-4b548cad5224"
version = "3.7.1"

[[deps.SIMDTypes]]
git-tree-sha1 = "330289636fb8107c5f32088d2741e9fd7a061a5c"
uuid = "94e857df-77ce-4151-89e5-788b33177be4"
version = "0.1.0"

[[deps.SciMLBase]]
deps = ["ADTypes", "Accessors", "Adapt", "ArrayInterface", "CommonSolve", "ConstructionBase", "Distributed", "DocStringExtensions", "EnumX", "FunctionWrappersWrappers", "IteratorInterfaceExtensions", "LinearAlgebra", "Logging", "Markdown", "Moshi", "PrecompileTools", "Preferences", "Printf", "RecipesBase", "RecursiveArrayTools", "Reexport", "RuntimeGeneratedFunctions", "SciMLOperators", "SciMLStructures", "StaticArraysCore", "Statistics", "SymbolicIndexingInterface"]
git-tree-sha1 = "c9dc4c04bcb0146a35dd6af726073c5738b80e3b"
uuid = "0bca4576-84f4-4d90-8ffe-ffa030f20462"
version = "2.104.0"

    [deps.SciMLBase.extensions]
    SciMLBaseChainRulesCoreExt = "ChainRulesCore"
    SciMLBaseMLStyleExt = "MLStyle"
    SciMLBaseMakieExt = "Makie"
    SciMLBasePartialFunctionsExt = "PartialFunctions"
    SciMLBasePyCallExt = "PyCall"
    SciMLBasePythonCallExt = "PythonCall"
    SciMLBaseRCallExt = "RCall"
    SciMLBaseZygoteExt = ["Zygote", "ChainRulesCore"]

    [deps.SciMLBase.weakdeps]
    ChainRules = "082447d4-558c-5d27-93f4-14fc19e9eca2"
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    MLStyle = "d8e11817-5142-5d16-987a-aa16d5891078"
    Makie = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
    PartialFunctions = "570af359-4316-4cb7-8c74-252c00c2016b"
    PyCall = "438e738f-606a-5dbb-bf0a-cddfbfd45ab0"
    PythonCall = "6099a3de-0909-46bc-b1f4-468b9a2dfc0d"
    RCall = "6f49c342-dc21-5d91-9882-a32aef131414"
    Zygote = "e88e6eb3-aa80-5325-afca-941959d7151f"

[[deps.SciMLOperators]]
deps = ["Accessors", "ArrayInterface", "DocStringExtensions", "LinearAlgebra", "MacroTools"]
git-tree-sha1 = "3249fe77f322fe539e935ecb388c8290cd38a3fc"
uuid = "c0aeaf25-5076-4817-a8d5-81caf7dfa961"
version = "1.3.1"
weakdeps = ["SparseArrays", "StaticArraysCore"]

    [deps.SciMLOperators.extensions]
    SciMLOperatorsSparseArraysExt = "SparseArrays"
    SciMLOperatorsStaticArraysCoreExt = "StaticArraysCore"

[[deps.SciMLStructures]]
deps = ["ArrayInterface"]
git-tree-sha1 = "566c4ed301ccb2a44cbd5a27da5f885e0ed1d5df"
uuid = "53ae85a6-f571-4167-b2af-e1d143709226"
version = "1.7.0"

[[deps.ScientificTypesBase]]
git-tree-sha1 = "a8e18eb383b5ecf1b5e6fc237eb39255044fd92b"
uuid = "30f210dd-8aff-4c5f-94ba-8e64358c1161"
version = "3.0.0"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "9b81b8393e50b7d4e6d0a9f14e192294d3b7c109"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.3.0"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "712fb0231ee6f9120e005ccd56297abbc053e7e0"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.4.8"

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
deps = ["Random", "Statistics", "Test"]
git-tree-sha1 = "d263a08ec505853a5ff1c1ebde2070419e3f28e9"
uuid = "73760f76-fbc4-59ce-8f25-708e95d2df96"
version = "0.4.0"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "5d7e3f4e11935503d3ecaf7186eac40602e7d231"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.4"

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
git-tree-sha1 = "66e0a8e672a0bdfca2c3f5937efb8538b9ddc085"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.1"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.11.0"

[[deps.SpecialFunctions]]
deps = ["IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "41852b8679f78c8d8961eeadc8f62cef861a52e3"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.5.1"
weakdeps = ["ChainRulesCore"]

    [deps.SpecialFunctions.extensions]
    SpecialFunctionsChainRulesCoreExt = "ChainRulesCore"

[[deps.StableRNGs]]
deps = ["Random"]
git-tree-sha1 = "95af145932c2ed859b63329952ce8d633719f091"
uuid = "860ef19b-820b-49d6-a774-d7a799459cd3"
version = "1.0.3"

[[deps.StackViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "be1cf4eb0ac528d96f5115b4ed80c26a8d8ae621"
uuid = "cae243ae-269e-4f55-b966-ac2d0dc13c15"
version = "0.1.2"

[[deps.Static]]
deps = ["CommonWorldInvalidations", "IfElse", "PrecompileTools"]
git-tree-sha1 = "f737d444cb0ad07e61b3c1bef8eb91203c321eff"
uuid = "aedffcd0-7271-4cad-89d0-dc628f76c6d3"
version = "1.2.0"

[[deps.StaticArrayInterface]]
deps = ["ArrayInterface", "Compat", "IfElse", "LinearAlgebra", "PrecompileTools", "Static"]
git-tree-sha1 = "96381d50f1ce85f2663584c8e886a6ca97e60554"
uuid = "0d7ed370-da01-4f52-bd93-41d350b8b718"
version = "1.8.0"
weakdeps = ["OffsetArrays", "StaticArrays"]

    [deps.StaticArrayInterface.extensions]
    StaticArrayInterfaceOffsetArraysExt = "OffsetArrays"
    StaticArrayInterfaceStaticArraysExt = "StaticArrays"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "PrecompileTools", "Random", "StaticArraysCore"]
git-tree-sha1 = "cbea8a6bd7bed51b1619658dec70035e07b8502f"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.9.14"
weakdeps = ["ChainRulesCore", "Statistics"]

    [deps.StaticArrays.extensions]
    StaticArraysChainRulesCoreExt = "ChainRulesCore"
    StaticArraysStatisticsExt = "Statistics"

[[deps.StaticArraysCore]]
git-tree-sha1 = "192954ef1208c7019899fbf8049e717f92959682"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.3"

[[deps.StatisticalTraits]]
deps = ["ScientificTypesBase"]
git-tree-sha1 = "89f86d9376acd18a1a4fbef66a56335a3a7633b8"
uuid = "64bff920-2084-43da-a3e6-9bb72801c0c9"
version = "3.5.0"

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
git-tree-sha1 = "9d72a13a3f4dd3795a195ac5a44d7d6ff5f552ff"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.7.1"

[[deps.StatsBase]]
deps = ["AliasTables", "DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "b81c5035922cc89c2d9523afc6c54be512411466"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.34.5"

[[deps.StatsFuns]]
deps = ["HypergeometricFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "8e45cecc66f3b42633b8ce14d431e8e57a3e242e"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "1.5.0"
weakdeps = ["ChainRulesCore", "InverseFunctions"]

    [deps.StatsFuns.extensions]
    StatsFunsChainRulesCoreExt = "ChainRulesCore"
    StatsFunsInverseFunctionsExt = "InverseFunctions"

[[deps.StochasticRounding]]
deps = ["BFloat16s", "DoubleFloats", "Random", "RandomNumbers"]
git-tree-sha1 = "3150baa62c3159a1f7680f49bc7cfde7d811b804"
uuid = "3843c9a1-1f18-49ff-9d99-1b4c8a8e97ed"
version = "0.8.3"

[[deps.StrideArraysCore]]
deps = ["ArrayInterface", "CloseOpenIntervals", "IfElse", "LayoutPointers", "LinearAlgebra", "ManualMemory", "SIMDTypes", "Static", "StaticArrayInterface", "ThreadingUtilities"]
git-tree-sha1 = "f35f6ab602df8413a50c4a25ca14de821e8605fb"
uuid = "7792a7ef-975c-4747-a70f-980b88e8d1da"
version = "0.5.7"

[[deps.StringManipulation]]
deps = ["PrecompileTools"]
git-tree-sha1 = "725421ae8e530ec29bcbdddbe91ff8053421d023"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.4.1"

[[deps.StructArrays]]
deps = ["ConstructionBase", "DataAPI", "Tables"]
git-tree-sha1 = "8ad2e38cbb812e29348719cc63580ec1dfeb9de4"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.7.1"

    [deps.StructArrays.extensions]
    StructArraysAdaptExt = "Adapt"
    StructArraysGPUArraysCoreExt = ["GPUArraysCore", "KernelAbstractions"]
    StructArraysLinearAlgebraExt = "LinearAlgebra"
    StructArraysSparseArraysExt = "SparseArrays"
    StructArraysStaticArraysExt = "StaticArrays"

    [deps.StructArrays.weakdeps]
    Adapt = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
    KernelAbstractions = "63c18a36-062a-441e-b654-da1e3ab1ce7c"
    LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.StructTypes]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "159331b30e94d7b11379037feeb9b690950cace8"
uuid = "856f2bd8-1eba-4b0a-8007-ebc267875bd4"
version = "1.11.0"

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

[[deps.SymbolicIndexingInterface]]
deps = ["Accessors", "ArrayInterface", "PrettyTables", "RuntimeGeneratedFunctions", "StaticArraysCore"]
git-tree-sha1 = "59ca6eddaaa9849e7de9fd1153b6faf0b1db7b80"
uuid = "2efcf032-c050-4f8e-a9bb-153293bab1f5"
version = "0.3.42"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TZJData]]
deps = ["Artifacts"]
git-tree-sha1 = "72df96b3a595b7aab1e101eb07d2a435963a97e2"
uuid = "dc5dba14-91b3-4cab-a142-028a31da12f7"
version = "1.5.0+2025b"

[[deps.TableOperations]]
deps = ["SentinelArrays", "Tables", "Test"]
git-tree-sha1 = "e383c87cf2a1dc41fa30c093b2a19877c83e1bc1"
uuid = "ab02a1b2-a7df-11e8-156e-fb1833f50b87"
version = "1.2.0"

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

[[deps.ThreadingUtilities]]
deps = ["ManualMemory"]
git-tree-sha1 = "d969183d3d244b6c33796b5ed01ab97328f2db85"
uuid = "8290d209-cae3-49c0-8002-c8c24d57dab5"
version = "0.5.5"

[[deps.TiffImages]]
deps = ["ColorTypes", "DataStructures", "DocStringExtensions", "FileIO", "FixedPointNumbers", "IndirectArrays", "Inflate", "Mmap", "OffsetArrays", "PkgVersion", "PrecompileTools", "ProgressMeter", "SIMD", "UUIDs"]
git-tree-sha1 = "02aca429c9885d1109e58f400c333521c13d48a0"
uuid = "731e570b-9d59-4bfa-96dc-6df516fadf69"
version = "0.11.4"

[[deps.TimeZones]]
deps = ["Artifacts", "Dates", "Downloads", "InlineStrings", "Mocking", "Printf", "Scratch", "TZJData", "Unicode", "p7zip_jll"]
git-tree-sha1 = "1f9a3f379a2ce2a213a0f606895567a08a1a2d08"
uuid = "f269a46b-ccf7-5d73-abea-4c690281aa53"
version = "1.22.0"
weakdeps = ["RecipesBase"]

    [deps.TimeZones.extensions]
    TimeZonesRecipesBaseExt = "RecipesBase"

[[deps.TranscodingStreams]]
git-tree-sha1 = "0c45878dcfdcfa8480052b6ab162cdd138781742"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.11.3"

[[deps.Tricks]]
git-tree-sha1 = "6cae795a5a9313bbb4f60683f7263318fc7d1505"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.10"

[[deps.TriplotBase]]
git-tree-sha1 = "4d4ed7f294cda19382ff7de4c137d24d16adc89b"
uuid = "981d1d27-644d-49a2-9326-4793e63143c3"
version = "0.1.0"

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
git-tree-sha1 = "d2282232f8a4d71f79e85dc4dd45e5b12a6297fb"
uuid = "1986cc42-f94f-5a68-af5c-568840ba703d"
version = "1.23.1"
weakdeps = ["ConstructionBase", "ForwardDiff", "InverseFunctions", "Printf"]

    [deps.Unitful.extensions]
    ConstructionBaseUnitfulExt = "ConstructionBase"
    ForwardDiffExt = "ForwardDiff"
    InverseFunctionsUnitfulExt = "InverseFunctions"
    PrintfExt = "Printf"

[[deps.UnsafePointers]]
git-tree-sha1 = "c81331b3b2e60a982be57c046ec91f599ede674a"
uuid = "e17b2a0c-0bdf-430a-bd0c-3a23cae4ff39"
version = "1.0.0"

[[deps.WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "b1be2855ed9ed8eac54e5caff2afcdb442d52c23"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.2"

[[deps.WebP]]
deps = ["CEnum", "ColorTypes", "FileIO", "FixedPointNumbers", "ImageCore", "libwebp_jll"]
git-tree-sha1 = "aa1ca3c47f119fbdae8770c29820e5e6119b83f2"
uuid = "e3aaa7dc-3e4b-44e0-be63-ffb868ccd7c1"
version = "0.1.3"

[[deps.WoodburyMatrices]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "c1a7aa6219628fcd757dede0ca95e245c5cd9511"
uuid = "efce3f68-66dc-5838-9240-27a6d6f5f9b6"
version = "1.0.0"

[[deps.WorkerUtilities]]
git-tree-sha1 = "cd1659ba0d57b71a464a29e64dbc67cfe83d54e7"
uuid = "76eceee3-57b5-4d4a-8e66-0e911cebbf60"
version = "1.6.1"

[[deps.XZ_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "fee71455b0aaa3440dfdd54a9a36ccef829be7d4"
uuid = "ffd25f8a-64ca-5728-b0f7-c24cf3aae800"
version = "5.8.1+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "b5899b25d17bf1889d25906fb9deed5da0c15b3b"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.8.12+0"

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
git-tree-sha1 = "a4c0ee07ad36bf8bbce1c3bb52d21fb1e0b987fb"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.7+0"

[[deps.Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "7ed9347888fac59a618302ee38216dd0379c480d"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.12+0"

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

[[deps.libaom_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "4bba74fa59ab0755167ad24f98800fe5d727175b"
uuid = "a4ae2306-e953-59d6-aa16-d00cac43593b"
version = "3.12.1+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "125eedcb0a4a0bba65b657251ce1d27c8714e9d6"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.17.4+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.11.0+0"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "646634dd19587a56ee2f1199563ec056c5f228df"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.4+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "07b6a107d926093898e82b3b1db657ebe33134ec"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.50+0"

[[deps.libsixel_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "libpng_jll"]
git-tree-sha1 = "c1733e347283df07689d71d61e14be986e49e47a"
uuid = "075b6546-f08a-558a-be8f-8157d0f608a5"
version = "1.10.5+0"

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

[[deps.micromamba_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl"]
git-tree-sha1 = "b4a5a3943078f9fd11ae0b5ab1bdbf7718617945"
uuid = "f8abcde7-e9b7-5caa-b8af-a437887ae8e4"
version = "1.5.8+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.59.0+0"

[[deps.oneTBB_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "d5a767a3bb77135a99e433afe0eb14cd7f6914c3"
uuid = "1317d2d5-d96f-522e-a858-c73665f53c3e"
version = "2022.0.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"

[[deps.pixi_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl"]
git-tree-sha1 = "f349584316617063160a947a82638f7611a8ef0f"
uuid = "4d7b5844-a134-5dcd-ac86-c8f19cd51bed"
version = "0.41.3+0"

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
# ╟─83fd4129-f9bf-47af-a9ea-505511909ebe
# ╟─2c753716-0af8-4e9a-ad79-e06eb35db64f
# ╟─63ba95f0-0a04-11ee-30b5-65d2b018e857
# ╟─38bd2812-84ed-4c07-a3c1-a647803b0541
# ╟─6fc6fe75-b249-48cc-9e85-6c942cb56b86
# ╟─26178e23-33e5-4294-bb03-c54b29fa6dd1
# ╟─1c983ad9-bd78-422c-a703-97f0a3d08b91
# ╟─573ac61e-7c9f-41cc-baa6-7c4216432f5e
# ╟─787967f5-78f0-41d3-b786-078dfe3c5a8d
# ╟─de2c0e2c-d462-4ba4-ade3-451e7c1c8783
# ╟─2e9c1107-4378-4afb-b2e7-3c86f72473fa
# ╟─5ddcd487-5751-45ad-94f5-801318818207
# ╟─b80a8dd9-f3fd-4ff4-8190-3132e07762fc
# ╟─03ee88c3-7ca8-4614-9c6d-bd8822d41482
# ╟─faee4e9d-4e85-452b-87d1-4d85c96c677f
# ╠═ba43faa3-6752-49ac-87e3-8dbd896ad38a
# ╠═10eb2910-38b3-4102-8e8d-8ef8ec1e31d0
# ╟─6e00db9e-2879-4cae-9342-9dfec7509b81
# ╟─ad3a219b-ce0d-466f-b5c2-20cb882742d5
# ╟─a6196d15-a9f5-4e1b-9988-85c827d2bd27
# ╟─a2c827ec-c813-421a-83c9-e593bfdacfb7
# ╟─d9603b23-dff0-41e9-9291-70ebeaf8e7f1
# ╠═e879dcdb-c8aa-41f9-86ec-4588199ab72c
# ╟─8096e64f-15d6-4f55-8b08-6f4e130098ee
# ╟─3d184ac4-83ca-42ec-96b5-a12a59a0b4a0
# ╠═d37fcb33-5d29-401e-ada2-e4bc892cf573
# ╟─ed67a442-9891-4018-adc4-eef06c3efba7
# ╠═55c3f97d-509b-407d-b26c-9c6ac5f96936
# ╠═2573aee2-3cef-430f-a4eb-0e5bf29e2c21
# ╟─6c5188ae-10b0-4124-b68b-9d86acbf35de
# ╟─299f10aa-0ba7-4e67-a4f5-b2a885b379b3
# ╟─d4e70769-687f-46ab-9fbf-a959c2b12f9c
# ╟─d022561a-780b-4964-86e4-db47a408ed54
# ╟─54793dd0-52ed-4c07-a75d-cf9132c00647
# ╟─23a741a2-63e7-4eb4-aa2c-55fa888fd27d
# ╟─b1dcb967-cfd4-4961-9c70-d9e027be5eee
# ╟─2497e952-8220-46e5-a1c5-4c24631bc026
# ╟─8b6e60f0-a09b-41c9-a8bb-90c5b9086870
# ╟─ef7e56fe-7950-4346-9992-b67b2ddbaf78
# ╠═ded87217-cdc0-48de-9bbd-d5ac81f2f873
# ╠═1a7f20f9-a69c-49a2-a012-ed59657cc29f
# ╠═02e4483d-4e68-4a88-9247-f56e3902ed9b
# ╠═1f6fb5c4-d80a-4c46-83cd-7323d9a92e4f
# ╠═db3b56fc-000b-4b36-8e2e-812a81d1d902
# ╠═03ee0f1f-ca85-4690-83c1-22dcb3519f09
# ╠═e492bead-3364-4f53-82d1-de15bc50d411
# ╠═b07c4d06-8b81-40c3-ad25-0edd4cced919
# ╟─dd245fa6-91db-4cf4-82df-ee5869dc26be
# ╟─456e3273-7bcf-4c98-9a31-732ad5d312dd
# ╠═8f2437a9-45cf-4f8b-9808-11126097928d
# ╠═7278d4e8-322e-43d6-ab8d-b306c661fbc6
# ╠═686ff2ce-1f6d-435a-b93b-0d7c9ba6f680
# ╠═ec185c9f-7909-47d8-8cc6-05b252d72a5d
# ╠═5fc10869-ac5e-4440-ac36-eed90bffef8c
# ╠═a9825a63-1915-45c7-afd8-cac52cf7330c
# ╟─c9418101-649a-4c12-812a-c9cf5cd10c6c
# ╟─f09b6ee6-eea3-480f-b7b8-395b1575fdbe
# ╟─d928bb49-1cd2-444a-a8bc-1076ff4647fd
# ╟─c379062d-8b73-4b2a-a1ea-3ed2175ab7d8
# ╠═639f9f11-aa65-473b-b24d-44f60b913d83
# ╠═e42751a8-be45-418e-854d-6802ae47d8cd
# ╠═42f1ca4e-2a03-47a7-be15-20a67c25f020
# ╠═9c5fb5b0-76b6-4ff8-b4ba-f6a66754241f
# ╟─04c84b54-ad4e-4dea-b858-4ec17c25ab0e
# ╟─3630cd0e-2fb7-4de8-aebf-559933164a61
# ╠═e036e0b1-60f5-4670-9956-15e74d010ee9
# ╟─0f4a5c91-93cb-4677-afaa-2de023353b23
# ╠═93da471a-b064-4349-8d69-851f8b5e53ad
# ╟─2f8da3b2-b91e-439c-873f-171e50585d29
# ╟─c739f61d-7104-4ae4-9934-fc98657fc2fc
# ╠═60264a97-d85f-44ef-9012-cc2c3e8b4e03
# ╠═52047e5f-8e1f-4587-a24b-7aab97dd4b6d
# ╠═fa98c58b-e61b-4762-a89f-58cf6b5a50d0
# ╟─20422ed4-459b-4486-87fd-afc27d00fc07
# ╟─1914c723-d9cd-4269-9a3d-ce617c854ce4
# ╟─9532853d-67b2-4980-a7ea-3fc872694d92
# ╟─fe95495e-674f-4d0a-a330-8ee9b0d91b6a
# ╟─f8177941-5884-4233-985d-e7142e6c064b
# ╟─148b545d-4d38-432e-885f-f6f712c3f12f
# ╟─9358f02a-273d-4747-9dc8-34994e087375
# ╟─f1d654bb-a970-440d-8591-8363618fb9f7
# ╟─ff999e4d-9581-44f7-9ef3-47c496fec310
# ╟─cf29f290-477e-4ac4-99dc-d4705d49ad0e
# ╟─d5e1d232-4a88-45f1-ace5-0f2c1ba47423
# ╟─5a3c565c-2a5f-436c-90ba-92ccbb39509d
# ╟─7d5f4c81-6913-4bee-a8e0-e5fe01e436db
# ╟─57e85657-b6de-4d47-94d8-02b54361293d
# ╟─4be44ed7-b08e-4c6d-91ef-48e9a157b072
# ╟─08a09de0-6950-4a8f-8068-9143857a3bd6
# ╠═0e88ed74-261d-4aad-82dc-ed8076684406
# ╠═9b48b14c-2222-4275-b63c-0d3206bb13ad
# ╠═dac9fce8-80b2-4d43-a6ac-c0c13612987d
# ╠═bbdd1803-648a-4fa9-a392-07dd354ace85
# ╠═41830083-98a4-46b2-9714-afd310a9bf54
# ╠═31c8a6e2-a609-4522-912c-c9c7f709f8ab
# ╠═da264f24-d747-4c0d-a431-14c70955ff4d
# ╠═42f4e4dd-a760-4920-98db-103185337f47
# ╟─f4007ce0-f608-4288-bf8c-9da751f47e89
# ╟─c0ce6535-542e-4b7f-95e8-880109981aa6
# ╟─c79b4ac1-2ddd-49ee-a32c-66bee0fd9d21
# ╟─2b833425-088e-4319-844a-785faf316756
# ╠═26352f5f-fb5d-4810-b990-75390e560e67
# ╠═c46665fe-b0cc-40b1-af74-b3fd7ad776ea
# ╠═3720089a-bba8-47aa-a259-02f00e830fcd
# ╠═91cda445-5025-433d-b2f6-09061853025b
# ╠═bf7cd2b5-e5ff-4f24-b507-286ae8c2ab12
# ╟─8f5dcc84-3fcc-4da6-81a7-6aa28ccc18a5
# ╠═ee513355-3149-4235-bdfd-79b80d317103
# ╠═76440f57-0381-423c-aa50-1fa830876b20
# ╠═fd39b86f-3454-476a-88a5-a8d8abf99266
# ╠═fcd917f9-f93a-4726-999e-59bf92e3aeea
# ╟─6e233a0e-7c78-4b65-83da-04a31be93933
# ╠═60714855-9f57-410d-84cf-31d3273d441e
# ╠═cfda8bda-cfc9-4fa8-9790-d3206bfc3e19
# ╠═17ad78e6-43ca-44ea-bcae-15e52bde7851
# ╠═0e254ca8-b0d8-4d64-96ae-e54501f9b744
# ╠═1bac2902-10ef-46cc-8f75-f5326bbdc64b
# ╠═00f773b8-c632-436d-af00-b599e68fd9e1
# ╟─02fb1cf1-cacb-4676-a1a1-4c43fdde2bb4
# ╟─2b10fe3c-f116-4cf1-ad32-48072f1353a3
# ╟─2ce2e87f-56a1-4ae7-a771-7bf3fc2de3cb
# ╟─cc4b2a33-6f33-460b-8ac2-1d7a53f879bc
# ╟─7a8696cd-a587-40c3-827b-ede47869feec
# ╟─4c128164-c772-4551-a108-c3c30500c571
# ╟─74655914-6c3e-4c19-bf85-fa0a4035b1c3
# ╟─345e9e3c-ce8c-4758-a5b7-cb027e4ef678
# ╟─70ba8bc7-8cdc-49ae-bfa2-2e96f693c728
# ╟─d53d1ed1-c0ab-4f3e-bac7-8db42371f596
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
