### A Pluto.jl notebook ###
# v1.0.3

#> [frontmatter]
#> title = "Performance Engineering in Julia"
#> date = "2026-09-11"
#> license = "MIT"
#> description = "Guest lecture, UIUC CS 598 APE (online)"
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

# ╔═╡ 6aef4225-de33-4369-87f3-70e33521e2b5
begin
	using PlutoUI, PlutoTeachingTools
	using PlutoUI: Slider
end

# ╔═╡ c6208080-8e90-4e6c-be0e-a1a5eb305c87
begin
	using CairoMakie
	set_theme!(theme_latexfonts();
			   fontsize = 16,
			   Lines = (linewidth = 2,),
			   markersize = 16)
end

# ╔═╡ 675443bb-7cc7-4148-8bd0-3978595e038d
using BenchmarkTools

# ╔═╡ fade6b6e-bb15-4734-9435-af6eb5fb0fbf
begin
	using LLVM
	using LLVM.Interop
	using Unitful
end

# ╔═╡ f90c725d-a183-4af1-91d3-548ab2dd1072
using About

# ╔═╡ b3fdd7a2-4026-4560-bbbe-61cb084ba7ad
using Profile

# ╔═╡ 4c9541d3-1c44-4605-9351-622a467b82f4
using ProfileCanvas

# ╔═╡ 3a9632df-7e48-4064-af6d-1946f962ec8b
using ThreadPinning

# ╔═╡ a7c57f4e-ff4f-4179-93df-a5b602290ab0
using PProf

# ╔═╡ a91206f9-2f69-40dc-9f3d-f099ee2a4826
using TimerOutputs

# ╔═╡ cc9facb8-d67e-4719-aea9-5f417d011b20
using Base.Threads: @threads

# ╔═╡ 350f9f9b-31e3-4ce7-a933-363e5a207c18
ChooseDisplayMode()

# ╔═╡ 793e5df7-19da-42fd-994a-87e1d80b5cd4
html"""
<h1>Performance engineering and Julia</h1>

<div style="text-align: center;">
Sep 11th 2026 <br>
CS 598 Fall 2026
<br><br>
Valentin Churavy
<br><br>
High-Performance Computing, Universität des Saarlandes
<br><br>
@vchuravy
</div>

 <table>
        <tr>

<td><img src="https://upload.wikimedia.org/wikipedia/de/b/bc/Logo-Universit%C3%A4t_des_Saarlandes.svg" width=200px></td>
        </tr>
</table>
"""

# ╔═╡ f5aedf6b-dead-4cbd-add4-992315566932
md"""
## What's Julia? 🟢 🟣 🔴

Julia is a modern, dynamic, general-purpose, compiled programming language.
It's interactive ("like Python"), can be used in a REPL or notebooks, like Jupyter (it's the "Ju") or Pluto (this one🎈).
Julia has a runtime which includes a just-in-time (JIT) compiler and a garbage collector (GC), for automatic memory management.

Julia is mainly used for technical computing, and addresses a gap in the programming language landscape for numerical computing.


Main paradigm of Julia is multiple dispatch, what functions do depend on type and number of _all_ arguments.
"""

# ╔═╡ d6e64482-ff4f-4196-9b56-b3939dc93685
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

# ╔═╡ 08e536bc-a1ed-4ba1-9664-97a0ac21b1fc
md"""
## Mixing high-level and low-level code for scientific programming
"""

# ╔═╡ 7dc5d5bd-8813-4803-82e0-de4b390f7be1
TwoColumn(
md"""
**High-Level**
```julia
A = rand(64, 64)
B = Diagonal(ones(64))
C = similar(A)
C .= A .+ B

# Or
C = A .+ B
```
""",
md"""
**Low-Level**
```julia
function matadd!(C, A, B)
  size(C) == size(A) == size(B) || 
	throw(DimensionMismatch())
  m,n = size(A)
  @inbounds for j = 1:n
    @simd for i = 1:m
       C[i,j] = A[i,j] + B[i,j]
    end
  end
  return C
end
```
""")

# ╔═╡ 24a58157-e875-4b5b-854a-bec460593be9
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

# ╔═╡ 29003031-0935-4b81-8d61-22e70f0eacf8
md"""
# Performance Engineering in Julia
"""

# ╔═╡ 5ba4c311-f5f3-4941-b93f-4d44353c052a
md"""
### Goals:

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

# ╔═╡ f294d44f-1d17-48c4-8f1e-7df7c5ecedcd
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

# ╔═╡ bd98b86c-3385-4be7-ab47-e4715d04c8d0
md"""
# Benchmarking
"""

# ╔═╡ 48d24767-564c-41e0-9dfc-3a26a7625bed
md"""
!!! note
    1. Premature optimization is the root of all evil
    2. If you don't measure you won't improve
"""

# ╔═╡ 9f06beb2-a130-4d51-8064-77d1ee1067c8
md"""
### BenchmarkTools.jl

Solid package that tries to eliminate common pitfalls in performance measurment.

- `@benchmark` macro that will repeatedly evaluate your code to gain enough samples
- Caveat: You probably want to escape $ your input data
"""

# ╔═╡ 66a66b0d-b915-4eeb-b813-14d45893590d
md"""
N=$(@bind N Slider(1:8, show_value=true))
"""

# ╔═╡ 05d7c70d-cbdc-4981-9a0c-7263f85bb9aa
data = rand(10^N);

# ╔═╡ 0c23b4ce-e886-46b6-9a26-be21e53ba181
function sum(X)
    acc = 0
    for x in X
        acc += x
    end
    acc
end

# ╔═╡ 6edcae4d-c362-489b-8d51-315fe84c69b6
@belapsed sum(data) samples=10 evals=3

# ╔═╡ ff3dfeca-2e26-4e45-93aa-74cd09e5a30c
@benchmark sum(data) samples=10 evals=3

# ╔═╡ f67151f7-aa08-4179-ab2d-1a95090d45a0
md"""
!!! note
    One important thing to know, that Julia performs type-inference based on the argument types, and **quality** of type-inference determines performance characteristics.
"""

# ╔═╡ b08f34a3-fe13-4d3d-9efe-8e18ad1deea7
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

# ╔═╡ a577a567-3d13-42fa-b00a-e2856744e5c4
with_terminal() do
	@code_warntype sum(data)
end

# ╔═╡ a4511dbe-5695-4b8c-b711-2138d052cf31
md"""
### Caveats of micro-benchmarking

BenchmarkTools tries to approximate a function execution a top-level.
It thus measures the cost of accessing global variables.

Use the interpolation syntax `$` to avoid that cost for very cheap functions.
"""

# ╔═╡ 3a02de5a-0f33-4d2b-931c-9841930a359e
begin
	a = 3.0
	b = 4.0
end

# ╔═╡ 4cc73931-209f-4584-956c-51e72e0944d2
@benchmark sin(a) + b samples=10 evals=3

# ╔═╡ c7b06dac-b648-405d-b694-0477cef516d1
@benchmark sin($a) + b samples=10 evals=3

# ╔═╡ e233786d-46f6-4b6c-8b9e-1482ebf78d7e
@benchmark sin($a) + $b samples=10 evals=3

# ╔═╡ b97e53d9-245a-4133-bbb0-3fd44032b4ed
md"""
!!! warning
	Did we get to fast?
"""

# ╔═╡ a789728d-7844-4968-9619-057db332df4e
code_typed() do
	sin(3.0) + 4.0
end |> only

# ╔═╡ 60aebab7-25a3-40f9-9660-70b29b6083df
md"""
!!! note
    Julia can constant-fold expressions.
"""

# ╔═╡ 9466dca4-d3c6-45dc-8820-9b1c7caad386
@benchmark sin($Ref(a)[]) + $Ref(b)[] samples=10 evals=3

# ╔═╡ f6b2444e-3663-41c8-887b-f8ad6d371bcb
md"""
!!! warning
	Be careful with benchmarks whose time doesn't change with an increase in complexity! Likely that the compiler got clever and turned it into a constant time expression or constant folded it.
"""

# ╔═╡ 7e556c79-262e-4936-8fcb-4d74211d2d81
function count(N)
    acc = 0
    for i in 1:N
        acc += 1
    end
    return acc
end

# ╔═╡ 664736c8-8ec2-42d7-bb07-2e57270ec089
@benchmark count(10) samples=10 evals=3

# ╔═╡ 7da88cb8-6999-4571-8076-6df6fbb2a801
@benchmark count(1_000_000) samples=10 evals=3

# ╔═╡ c9343e98-cdeb-4ca8-83c6-32d7fb5d6330
md"""
!!! note
    We will revisit this example in a second. Think about why this benchmark is independent of `N`.
"""

# ╔═╡ 4497f1a2-d55a-40c4-abd4-6cfe6d6db2e2
md"""
!!! warning
    How would you benchmark `sort!`?
"""

# ╔═╡ 8c63e0ac-7aff-40d8-adb5-a218680d190b
let
	v = rand(Int, 1024)
	@benchmark sort!($v)
end

# ╔═╡ 46d0c3fe-8367-4fef-87e8-f4aa91ef95e3
md"""
`sort!` is mutating its input. Therefore we need to set `evals=1` and provide a `setup` to re-initialize the data everytime
"""

# ╔═╡ 19613c14-acdb-4f12-a2c5-5431e167ccae
@benchmark sort!(v) setup=(v = rand(Int, 1024)) evals=1

# ╔═╡ 42a36172-362c-4a62-82da-346efcb47a74
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
    - CPU are "learning"/"predictive" systems. See https://discourse.julialang.org/t/psa-microbenchmarks-remember-branch-history/17436
"""

# ╔═╡ 0c369f82-4269-46a4-9fae-f09a46849251
md"""
# Going fast nowhere
"""

# ╔═╡ 6e1d446b-f3b2-4bd8-9ee4-b7aae6156d08
md"""
## Figuring out what is happening
The stages of the compiler

- `@code_lowered`
- `@code_typed` & `@code_warntype`
- `@code_llvm`
- `@code_native`

Where is a function defined `@which` & `@edit`
"""

# ╔═╡ 683e739b-1c6e-40b8-8fe6-d259687949e8
@code_lowered sum(data)

# ╔═╡ 72b67bec-a6e3-48c5-9510-dfa2e0b02fe9
@code_typed optimize=false sum(data)

# ╔═╡ a84d7b08-103d-4fe3-b265-9ca854f5f5a7
md"""
## A simple example: counting
"""

# ╔═╡ 25e35d99-a2cd-4f87-a391-e3ccf124953f
md"""
```julia
function count(N)
    acc = 0
    for i in 1:N
        acc += 1
    end
    return acc
end
```
"""

# ╔═╡ 44ab086e-0013-42a6-91d2-d5cacbe260e3
K = 100_000_000

# ╔═╡ 2d8b9925-8095-49e3-89ca-2deb7c247a20
result = @benchmark count($(Ref(K))[])

# ╔═╡ 6bbe5b23-1fb5-4424-81ae-b465c90f4c69
begin
	t = time(minimum(result)) * u"ns" # in ns
	pFreq = round(typeof(1u"PHz"), K/t)
end;

# ╔═╡ 72b24d09-5fe5-43bf-84fa-ac38b22de458
md"""

So we are doing **$(K/1_000_000)** million additions in **$t**...

That would mean our processor operates at **$pFreq**

We wish...

Let's do a basic check, 10x bigger input.
"""

# ╔═╡ 4e2edf55-ee91-4785-b2c5-40cc17678de8
@benchmark count($(Ref(10*K))[])

# ╔═╡ 45bf4e0f-b8ea-44bd-843c-11618ab3f47a
md"""
Let's explore what code we are **actually** running.

Using Julia's reflection macros we can see all of the stages of code-generation.
"""

# ╔═╡ f3912092-f7dd-4102-9a36-6b55d98d7dbc
@code_lowered count(K)

# ╔═╡ 146ec37c-3b4d-478a-909e-4a201211623e
@code_typed optimize=true count(K)

# ╔═╡ 405edc58-cc41-4e0b-b0fd-069ed69c0666
with_terminal() do
	@code_llvm optimize=false debuginfo=:none count(K)
end

# ╔═╡ 50bab76a-275c-4630-a704-8136ddd0eb6e
with_terminal() do
	@code_llvm optimize=true debuginfo=:none count(K)
end

# ╔═╡ f0651468-5071-4f1a-9a03-dea756711e05
with_terminal() do
	@code_native count(K)
end

# ╔═╡ 80caaff4-0db2-4101-ba3f-8130065fe67e
md"""
!!! note "Conclusion"
	LLVM realised that our loop:
	```julia
	for i in 1:N
	  acc += 1
	end
	```
	
	Just ended up being $acc = 1 * N$
"""

# ╔═╡ d8c765b0-06e8-4cad-a0f5-caa13b8a8943
md"""
## Can we actually measure the speed of our original code?
"""

# ╔═╡ 407a3519-5a71-4c10-a115-d3d7d79a13f3
"""
    clobber()

Force the compiler to flush pending writes to global memory.
Acts as an effective read/write barrier.
"""
@inline clobber() = @asmcall("", "~{memory}", true) 

# ╔═╡ 3471f218-d38c-47e1-b150-010bb589cecc
"""
    escape(val)

The `escape` function can be used to prevent a value or
expression from being optimized away by the compiler. This function is
intended to add little to no overhead.
See: https://youtu.be/nXaxk27zwlk?t=2441
"""
@inline escape(val::T) where T = @asmcall("", "X,~{memory}", true, Nothing, Tuple{T}, val)

# ╔═╡ e74fcbaf-ee04-4a62-bb75-d0d60cff9008
function k(::Type{T}, N) where T
    acc = zero(T)
    for i in 1:N
        acc += one(T)
        clobber()
    end
    return acc
end

# ╔═╡ e02f6740-237a-4ebd-91aa-40e65615c9f7
with_terminal() do
	@code_llvm debuginfo=:none k(Int64, 10)
end

# ╔═╡ 97526d18-3dd6-43a1-9a1c-7501a07a44cc
function m(::Type{T}, N) where T
    acc = zero(T)
    for i in 1:N
        acc += one(T)
        escape(acc)
    end
    return acc
end

# ╔═╡ 5f3d5027-3bdc-401a-93c7-89f88d22cb4a
with_terminal() do
	@code_llvm debuginfo=:none m(Int64, 10)
end

# ╔═╡ 9a3ad117-5fd5-4601-bc54-6a2261150511
result2 = @benchmark m(Int64, $K)

# ╔═╡ e9aa9ce3-d63e-4cde-89ad-ff8e2e5876de
@benchmark m(Int64, $(K*10))

# ╔═╡ 0bf14539-ae70-4410-bcaf-e9bb4a635149
begin
	t2 = time(minimum(result2)) * u"ns" # in ns
	pFreq2 = round(typeof(1u"MHz"), K/t2)
end;

# ╔═╡ d2ca125b-6a89-4df3-8985-a0e17c1dbc32
md"""
Frequency estimation: $pFreq2 ~ $(round(typeof(1u"GHz"), pFreq2))

Note: Benchmarking is hard, careful evalutaion of what you are trying to benchmark.

- If we were just interesting in how fast f(N) was we would have been fine with our first measurement
- But we were interested in the speed of addition as a proxy of perfromance
- Integer math on a computer is associative, Floating-Point math is not.
"""

# ╔═╡ ca0880f4-f26b-41b7-b722-b8d6c5e23acd
md"""
### Floating-point arithmetic
"""

# ╔═╡ 62133544-67cd-47a1-9a55-68dfa8441b87
function h(N)
    acc = 0.0
    for i in 1:N
        acc += 1.0
    end
    acc
end

# ╔═╡ 58f17eb8-04e7-43ad-af17-9e2c06143f15
@benchmark h(10*$K)

# ╔═╡ e99f8bc7-81a2-4583-a23a-c7365eaaf45d
function l(N)
    acc = 0.0
    @simd for i in 1:N
        acc += 1.0
    end
    acc
end

# ╔═╡ 86dd48ac-944f-4e47-bd78-47ccbed5ef45
@benchmark l($K)

# ╔═╡ 80388821-8451-486c-8c32-e5c5174a0536
md"""
## Performance annotiations in Julia


- https://docs.julialang.org/en/v1/manual/performance-tips/
- Julia does bounds checking by default ones(10)[11] is an error
- `@inbounds` Turns of bounds-checking locally
- `@fastmath` Turns of strict IEEE749 locally -- be very careful this might **not do** what you want
- `@simd` and `@simd ivdep` stronger gurantuees to encourage LLVM to use SIMD operations
"""

# ╔═╡ a28e235d-1023-4b69-9f68-e9db9b793c0f
with_terminal() do
	@code_llvm debuginfo=:none l(10)
end

# ╔═╡ 3e06cbf8-2d5c-4168-a62f-e45fba42d79c
md"""
## Memory layout of Objects
"""

# ╔═╡ c6d4aa26-3ef5-4015-ad66-e309a450a862
md"""
Julia has two types of struct types.

1. Immutable
2. Mutable

**Immutable** datatypes have fields that can't be mutated and they do not have *object-identity*. Think numbers, and similar objects.

**Mutable** datatypes can be updated in place and they posses object-identity.
"""

# ╔═╡ 85c37cc7-26f0-47a7-b60e-e0e5bec201f1
struct MyImmutable
	a::Float64
end

# ╔═╡ d3e81cdf-5bc1-44a3-a7d5-9073d9a158ce
mutable struct MyMutable
	a::Float64
end

# ╔═╡ cef56b1e-96bc-46c0-bc96-e064b43100b4
let
	x = MyImmutable(1.0)
	y = MyImmutable(1.0)

	x === y
end

# ╔═╡ adeacaf2-15d5-4e26-87ad-a63c6a1252d3
let
	x = MyMutable(1.0)
	y = MyMutable(1.0)

	x === y
end

# ╔═╡ 92eaad3a-31bf-4db4-b70c-ed03b3d69c9b
with_terminal() do
	about(Float64(ℯ))
end

# ╔═╡ 02cfc5c1-ac2a-46cc-845a-9ed1d56251ea
with_terminal() do
	about(1.0 + 0.0im)
end

# ╔═╡ f244f4fb-29c4-4046-957c-561360454137
with_terminal() do
	about(MyImmutable(1.0))
end

# ╔═╡ 5becd38b-9d23-482c-865d-d3a9a35b241e
with_terminal() do
	about(MyMutable(1.0))
end

# ╔═╡ 4307cf31-cdb1-4295-ad4f-a306ab2ec526
begin
	x1 = fill(MyImmutable(0.0), 10)
	x1[1] = MyImmutable(1.0)
	x1
end

# ╔═╡ ce42658d-4714-4c10-bfba-3722f8b8b7d9
begin
	x2 = fill(MyMutable(0.0), 10)
	x2[1].a = 1.0
	x2
end

# ╔═╡ 41ff1baa-8e2b-4ca0-8a14-8dea227c6f60
md"""
!!! warning
	`fill` with a mutable object will lead to aliasing.
"""

# ╔═╡ 0fd9b537-efb7-4933-8969-7fb2511a8cbd
begin
	x3 = [MyMutable(0.0) for _ in 1:10]
	x3[1].a = 1.0
	x3
end

# ╔═╡ a7cfc945-4260-4cfe-ad61-0124b1ce4b0b
with_terminal() do
	about([1.0, 2.0])
end

# ╔═╡ a7f06489-85dd-4485-8d67-519b579bb32b
with_terminal() do
	about([1.0+0.0im, 2.0-1.0im])
end

# ╔═╡ 98c27c6f-a1d1-4be2-bc98-f6a81ac48876
with_terminal() do
	about([MyMutable(0.0), MyMutable(1.0)])
end

# ╔═╡ 57f2cab6-b1e9-4f8f-9f9e-afee18eead4b
md"""
!!! info
    Mutable objects are stored in fields and arrays as references (pointers). 
    Immutable objects may be stored **inline**. 
"""

# ╔═╡ 19b3c6d0-eff5-4344-b7f5-63e5695c1b7b
md"""
!!! warning "From the micro to the macro"
    So far we have been focusing on micro-benchmark and extracting the maximum out of small functions. While that is important you should always ask yourself first, where am I spending my time.
"""

# ╔═╡ 1c5089a9-3794-42ec-9d1d-b935ce525a95
md"""
## Where does time go?
"""

# ╔═╡ b80c3dd2-3e99-4df9-8562-532a0cd06f06
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

# ╔═╡ bbdc81ef-b7f1-41d3-8c2e-ce9b3fe87d17
md"""
# Profiling
"""

# ╔═╡ 3ba72203-3f08-4a0e-9de1-dd57e4f07484
md"""
Most profilers we will use are **stochastic** profilers. They sample the running program at a fixed interval. Julia uses a default of `0.001s` and it also uses a fixed size buffer. See `Profile.init`.

!!! note
    Sampling artifacts can occur when profiling multi-threaded applications. During a sample the thread we are sampling from is paused. If the thread is in a critical section this may introduce artifacts. 
"""

# ╔═╡ d089e5aa-d559-4491-aef4-3f9ee504862d
md"""
The Julia profiler focuses on the execution of Julia code. This leads to two limitations:

1. By default it does not show time spent in C functions
2. It does not measure time spent on "external" threads
  - BLAS threads
  - GC worker threads
"""

# ╔═╡ daa91aff-fabd-4562-ac41-5b9a179343c1
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

# ╔═╡ 36701e85-124a-4417-9a97-429cd24663f7
@profview profile_test(1);  # run once to trigger compilation (ignore this one)

# ╔═╡ 93249320-2c2a-40d0-b108-8ca35ab424f4
@profview profile_test(10)

# ╔═╡ 5d40a8fd-dc62-4fac-a76e-49a44aabdec3
md"""
!!! note
    The profiler shows all Julia worker-threads. The time spent in `task_done_hook` is a worker thread idiling.
"""

# ╔═╡ 24127ab1-0561-4748-bc55-275b60237e33
function pfib(n::Int)
    if n <= 1
        return n
    end
    t = Threads.@spawn pfib(n-2)
    return pfib(n-1) + fetch(t)::Int
end

# ╔═╡ 10348401-8c0e-4d66-bc8d-51e519f76aa2
function profile_pfib(n, k)
    for i = 1:n
        pfib(k)
    end
end

# ╔═╡ fd79e187-bf0d-4047-aa54-1b76184bbf28
@profview profile_pfib(1, 4);

# ╔═╡ 40fdd39b-9e4b-46a0-88fb-5a42a2aae4cf
@profview profile_pfib(10, 16)

# ╔═╡ 3f3aef8c-d7da-4431-a755-378153dad294
md"""
To gain insight into runtime behavior we can turn on C-frames
"""

# ╔═╡ 86916ce5-0a22-46d4-aba2-ddcbbd1d87f3
@profview profile_pfib(10, 16) C=true

# ╔═╡ c8ed69f5-2d35-4b82-8f69-9ca69fe21f3f
md"""
Runtime functions you might see:

- `jl_gc_*_alloc`: Memory allocations
- `jl_gc_collect`: Garbage collection
- `jl_safepoint_wait_gc`: Garbage collection waiting for all threads to reach it.
"""

# ╔═╡ 5979387a-38d5-4b8c-908c-219325a617d6
md"""
### Allocation profiler

The allocation profiler will collect backtraces at allocation sites with a default `sample_rate=0.0001` (So about 1/10_000 allocations).

[PProf.jl](https://github.com/JuliaPerf/PProf.jl) also has a callgraph view instead of just the "icicle" view.
"""

# ╔═╡ 7e6a9b3a-7ca0-4805-8abc-0f38b05c5718
@profview_allocs profile_test(10)

# ╔═╡ da0b4696-df79-42b6-a516-10186483ddc4
@profview_allocs profile_test(10) sample_rate=1.0

# ╔═╡ 45dd1a2e-252a-400d-926a-5c2994d6d2fe
md"""
### Native profilers
"""

# ╔═╡ acecd1a1-4a70-4355-a87e-aed1d4c63dc6
md"""
System profilers allow you to gain even more insight into how your program is performing, but come with usability down-sides.
"""

# ╔═╡ dd99c12d-7354-4b55-9764-1a5495edea7e
md"""
- [VTune](https://github.com/JuliaPerf/IntelITT.jl?tab=readme-ov-file#running-julia-under-vtune)
- [Perf](https://docs.julialang.org/en/v1/manual/profile/#External-Profiling)
- [NSight Systems](https://cuda.juliagpu.org/stable/development/profiling/#External-profilers)
  - `CUDA.jl` has it's own inbuilt `@profile`
"""

# ╔═╡ 6ee0e4d0-fc6d-43ca-9395-b9e3b341b34b
md"""
## Aside: ThreadPinning.jl
"""

# ╔═╡ 661f8bdd-463d-49a6-8c97-cbc5da8bf143
md"""
For reproducible benchmarks on multi-core systems it is helpful to pin threads to specific cores.
[ThreadPinning.jl](https://github.com/carstenbauer/ThreadPinning.jl) provides a simple interface for this.
"""

# ╔═╡ 44eea298-437c-4b67-a6ae-135279e91575
begin
	ThreadPinning.pinthreads(:random)
	nothing
end

# ╔═╡ c65bcaaf-82cb-418a-845e-94a9eaaab64e
with_terminal() do
	ThreadPinning.threadinfo()
end

# ╔═╡ 6b7401c0-f198-4073-accb-d7a627f2d01b
md"""
### PProf
"""

# ╔═╡ c31b20f6-7fc2-4f9e-b52b-7dab1723a045
md"""
[PProf.jl](https://github.com/JuliaPerf/PProf.jl) exports profiles in the pprof format and starts a local web server for interactive exploration. It supports both flame graph and call graph views.
"""

# ╔═╡ 6d452eb2-fc1a-410e-be34-c54526e14a0f
@pprof profile_test(10)

# ╔═╡ 6dadd682-8980-47c5-aedd-aa3e57122697
# Re-generate the pprof profile data for the running server (interactive use only)
try PProf.refresh() catch end

# ╔═╡ 4e8bcfd8-11d3-451c-882d-4ef0aceca30b
md"""
!!! note "Sharing profiles"
    - [flamegraph.com](https://flamegraph.com)
    - [pprof.me](https://pprof.me)
"""

# ╔═╡ 0737ac5f-c947-44e4-b2f0-009529965f48
md"""
## How do Profilers work?

```
while profiling
    sleep(t) # wait for sampling interval
    pause_threads()
    for t in threads()
       collect_stacktrace(t)
       # process
    end
end
```
"""

# ╔═╡ af00dd69-1637-4aaa-b818-1ec653dee5e3
md"""
### Stackframe
"""

# ╔═╡ 9de7f5d6-697b-44bd-9c7e-775a80a97d74
Base.stacktrace() # lot's of extra noise from Pluto

# ╔═╡ ef27fdfc-9d17-4ed8-aed8-1fcd9f586518
md"""
!!! warn "Count vs time"
	Profilers count the number of time a call-frame was seen in a stackframe. The flamegraphs we saw above are count based. If you know the **sampling frequency** you can convert it to "time", but it is always a hazardous procedure since the cost of taking a sample can be hight. 

    Profiling will slow down your code.

"""

# ╔═╡ b63778a0-a167-4949-87fa-0cda95192726
TwoColumn(
md"""
**Internal Profiler**
- Can use language specific stacktrace collection
  - Often more information
- May rely on runtime scheduling
- May have higher overheads
""",
md"""
**External Profiler**
- Relies on OS-level stacktrace collection (unwinding)
  - JIT compilers are hard (where does the debuginfo live)
  - Less information (in Julia simple names instead of detailed methods)
- Lower-overhead
- Deeper integration (CPU architecture analysis)
""")

# ╔═╡ 872cdcd1-78f9-475b-9e4c-3bbe446b1d87
md"""
### Instrumentation

It can be hard to correlate profiles with our programs, instrumentation makes it easier to define semantically important portions.

- [TimerOutputs](https://github.com/KristofferC/TimerOutputs.jl)
- [NVTX](https://github.com/JuliaGPU/NVTX.jl)
- [Tracy](https://github.com/topolarity/Tracy.jl)
- [IntelITT.jl](https://github.com/JuliaPerf/IntelITT.j)

"""

# ╔═╡ e7309389-4fb5-4633-8705-b3889b7dca72
const to = TimerOutput();

# ╔═╡ 3df69046-2804-4cb8-8e91-b4433a66cb72
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

# ╔═╡ 76265fcf-5428-464b-bf6f-dec689d091d6
let
	TimerOutputs.reset_timer!(to)
	for i in 1:10
		A = fill(1, 500_000)
		prefix_threads!(+, A)
	end
	to
end

# ╔═╡ f68c8205-9d70-449e-979c-6e3898ed9b67
md"""
!!! note
    Instrumentation together with a sampling profiler can be very powerful, since it allows you to focus on regions of interest.
"""

# ╔═╡ f2d1282f-037d-4f60-b9fe-921839959e52
md"""
```julia
using IntelITT

# warm-up, compile code, etc

IntelITT.resume()

IntelITT.@task "my task" begin
    # do interesting things here
end

IntelITT.pause()
```
"""

# ╔═╡ 2242d55d-49f9-4e68-bfee-f3b92e2cc4c1
md"""
## Continous profiling

The holy grail, needs to have low-overhead / low-performance impact, but provides deep insight into long-running applications like web-servers.

!!! note
    Traditional profilers struggle when profiling sessions become very long.
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
About = "69d22d85-9f48-4c46-bbbe-7ad8341ff72a"
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
LLVM = "929cbde3-209d-540e-8aea-75f648917ca0"
PProf = "e4faabce-9ead-11e9-39d9-4379958e3056"
PlutoTeachingTools = "661c6b06-c737-4d37-b85c-46df65de6f69"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Profile = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"
ProfileCanvas = "efd6af41-a80b-495e-886c-e51b0c7d77a3"
ThreadPinning = "811555cd-349b-4f26-b7bc-1f208b848042"
TimerOutputs = "a759f4b9-e2f1-59dc-863e-4aeb61b1ea8f"
Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[compat]
About = "~1.0.4"
BenchmarkTools = "~1.8.0"
CairoMakie = "~0.15.14"
LLVM = "~9.13.1"
PProf = "~3.2.0"
PlutoTeachingTools = "~0.4.7"
PlutoUI = "~0.7.83"
ProfileCanvas = "~0.1.7"
ThreadPinning = "~1.1.1"
TimerOutputs = "~1.2.1"
Unitful = "~1.29.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.12.7"
manifest_format = "2.0"
project_hash = "e6d557162fcdca2e689bacb3d9975ad89c225397"

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
git-tree-sha1 = "e71ee7b4aa06b045259a7d6101e1cb45ad140bce"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.4.1"

[[deps.AbstractTrees]]
git-tree-sha1 = "2d9c9a55f9c93e8887ad391fbae72f8ef55e1177"
uuid = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
version = "0.4.5"

[[deps.Accessors]]
deps = ["CompositionsBase", "ConstructionBase", "Dates", "InverseFunctions", "MacroTools"]
git-tree-sha1 = "7063ad1083578215c7c4bf410368150abe8d5524"
uuid = "7d9f7c33-5ae7-4f3b-8dc6-eff91059b697"
version = "0.1.45"

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
deps = ["LinearAlgebra"]
git-tree-sha1 = "daa72978cd7a624246e894a4f4f067706d4e17e2"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "4.7.0"
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

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.Automa]]
deps = ["PrecompileTools", "TranscodingStreams"]
git-tree-sha1 = "94eab0b3ccdcac361188cc661daf69d4433c1818"
uuid = "67c07d97-cdcb-5c2c-af73-a7f9c32a568b"
version = "1.2.0"

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
git-tree-sha1 = "8c290a1b223deaeea9aea44b235d24546da8eb98"
uuid = "18cc8868-cbac-4acf-b575-c8ff214dc66f"
version = "1.4.0"

[[deps.BenchmarkTools]]
deps = ["Compat", "JSON", "Logging", "PrecompileTools", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "9670d3febc2b6da60a0ae57846ba74670290653f"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.8.0"

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
git-tree-sha1 = "3495bfc164949714579501b825b8e5e2cce7c56f"
uuid = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
version = "0.15.14"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "Libdl", "Pixman_jll", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "1fa950ebc3e37eccd51c6a8fe1f92f7d86263522"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.18.7+0"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra"]
git-tree-sha1 = "12177ad6b3cad7fd50c8b3825ce24a99ad61c18f"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.26.1"
weakdeps = ["SparseArrays"]

    [deps.ChainRulesCore.extensions]
    ChainRulesCoreSparseArraysExt = "SparseArrays"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "970758a3d591a2a5c2a907c53f2e2f8c1b1d3537"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.9"

[[deps.CodecZstd]]
deps = ["TranscodingStreams", "Zstd_jll"]
git-tree-sha1 = "da54a6cd93c54950c15adf1d336cfd7d71f51a56"
uuid = "6b39b394-51ab-5f42-8807-6242bab2b4c2"
version = "0.8.7"

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
deps = ["PrecompileTools"]
git-tree-sha1 = "6c389fa857f6ca5a95474b52a52023fd77f24cb7"
uuid = "38540f10-b2f7-11e9-35d8-d573e4eb0ff2"
version = "0.2.14"

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
version = "1.3.1+2"

[[deps.CompositionsBase]]
git-tree-sha1 = "802bb88cd69dfd1509f6670416bd4434015693ad"
uuid = "a33af91c-f02d-484b-be07-31d278c5ca2b"
version = "0.1.2"
weakdeps = ["InverseFunctions"]

    [deps.CompositionsBase.extensions]
    CompositionsBaseInverseFunctionsExt = "InverseFunctions"

[[deps.ComputePipeline]]
deps = ["Observables", "Preferences"]
git-tree-sha1 = "7bc84b769c1d384315e7b5c4ac03a6c303e6cf35"
uuid = "95dc2771-c249-4cd0-9c9f-1f3b4330693c"
version = "0.1.8"

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

[[deps.CoreMath]]
deps = ["CoreMath_jll"]
git-tree-sha1 = "8c0480f92b1b1796239156a1b9b1bfb1b39499b4"
uuid = "b7a15901-be09-4a0e-87d2-2e66b0e09b5a"
version = "0.1.0"

[[deps.CoreMath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "a692a4c1dc59a4b8bc0b6403876eb3250fde2bc3"
uuid = "a38c48d9-6df1-5ac9-9223-b6ada3b5572b"
version = "0.1.0+0"

[[deps.Crayons]]
git-tree-sha1 = "54b76cbb40d9a0f5368c880725b2f141da77c94f"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.2.0"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataStructures]]
deps = ["OrderedCollections"]
git-tree-sha1 = "b0bc6d2cad1fed8b7fd59a1551a991cb3d2809e6"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.19.6"

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
git-tree-sha1 = "4ac548adcad90c1d5d677af13568a748af4c952b"
uuid = "927a84f5-c5f4-47a5-9785-b46e178433df"
version = "1.6.7"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
git-tree-sha1 = "9e2f36d3c96a820c678f2f1f1782582fcf685bae"
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"
version = "1.9.1"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"
version = "1.11.0"

[[deps.Distributions]]
deps = ["AliasTables", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "Roots", "SpecialFunctions", "Statistics", "StatsAPI", "StatsBase", "StatsFuns"]
git-tree-sha1 = "a958ab3a40c755563f5e1405c0846cb0446bf19d"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.131"

    [deps.Distributions.extensions]
    DistributionsChainRulesCoreExt = "ChainRulesCore"
    DistributionsDensityInterfaceExt = "DensityInterface"
    DistributionsSparseConnectivityTracerExt = "SparseConnectivityTracer"
    DistributionsTestExt = "Test"

    [deps.Distributions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    DensityInterface = "b429d917-457f-4dbc-8f4c-0cc954292b1d"
    SparseConnectivityTracer = "9f842d2f-2579-4b1d-911e-f412cf18a3f5"
    Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.DocStringExtensions]]
git-tree-sha1 = "7442a5dfe1ebb773c29cc2962a8980f47221d76c"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.5"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.7.0"

[[deps.EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e3290f2d49e661fbd94046d7e3726ffcb2d41053"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.4+0"

[[deps.EnumX]]
git-tree-sha1 = "c49898e8438c828577f04b92fc9368c388ac783c"
uuid = "4e289a0a-7415-4d19-859d-a7e5c4648b56"
version = "1.0.7"

[[deps.ExactPredicates]]
deps = ["IntervalArithmetic", "Random", "StaticArrays"]
git-tree-sha1 = "83231673ea4d3d6008ac74dc5079e77ab2209d8f"
uuid = "429591f6-91af-11e9-00e2-59fbe8cec110"
version = "2.2.9"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "2bfb1e047e2ad0a5ca94365340bde8005d637568"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.8.4+0"

[[deps.ExprTools]]
git-tree-sha1 = "d2e49e7efd29719d6f28b891b0e0e159daa9d2b4"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.11"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "PCRE2_jll", "Zlib_jll", "libaom_jll", "libass_jll", "libfdk_aac_jll", "libva_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "7a58e45171b63ed4782f2d36fdee8713a469e6e0"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "8.1.2+0"

[[deps.FFTA]]
deps = ["AbstractFFTs", "DocStringExtensions", "LinearAlgebra", "MuladdMacro", "Primes", "Random", "Reexport"]
git-tree-sha1 = "65e55303b72f4a567a51b174dd2c47496efeb95a"
uuid = "b86e33f2-c0db-4aa1-a6e0-ab43e668529e"
version = "0.3.1"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "6621fef488e496356c9c9625d0562c12a6070819"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.20.0"

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
git-tree-sha1 = "5bad39456d9f0166184fce2248783dd9862645c1"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "1.17.0"
weakdeps = ["PDMats", "SparseArrays", "StaticArrays", "Statistics"]

    [deps.FillArrays.extensions]
    FillArraysPDMatsExt = "PDMats"
    FillArraysSparseArraysExt = "SparseArrays"
    FillArraysStaticArraysExt = "StaticArrays"
    FillArraysStatisticsExt = "Statistics"

[[deps.FixedPointNumbers]]
deps = ["Random", "Statistics"]
git-tree-sha1 = "59af96b98217c6ef4ae0dfe065ac7c20831d1a84"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.6"

[[deps.FlameGraphs]]
deps = ["AbstractTrees", "Colors", "FileIO", "FixedPointNumbers", "IndirectArrays", "LeftChildRightSiblingTrees", "Profile"]
git-tree-sha1 = "1f955e6e2c9fe7f56a0fdd169453f7a65b3e69f5"
uuid = "08572546-2f56-4bcf-ba4e-bab62c3a3f89"
version = "1.2.0"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Zlib_jll"]
git-tree-sha1 = "f85dac9a96a01087df6e3a749840015a0ca3817d"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.17.1+0"

[[deps.Format]]
git-tree-sha1 = "9c68794ef81b08086aeb32eeaf33531668d5f5fc"
uuid = "1fa38f19-a742-5d3f-a2b9-30dd87b9d5f8"
version = "1.3.7"

[[deps.FreeType]]
deps = ["CEnum", "FreeType2_jll"]
git-tree-sha1 = "907369da0f8e80728ab49c1c7e09327bf0d6d999"
uuid = "b38be410-82b0-50bf-ab77-7b57e271db43"
version = "4.1.1"

[[deps.FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "70329abc09b886fd2c5d94ad2d9527639c421e3e"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.14.3+1"

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

[[deps.Gamma]]
deps = ["LogExpFunctions"]
git-tree-sha1 = "becc397f7cfb06e343496ae6ffb04818a851da51"
uuid = "a0844989-3bd2-4988-8bea-c9407ab0941b"
version = "1.2.0"

[[deps.GeometryBasics]]
deps = ["EarCut_jll", "LinearAlgebra", "PrecompileTools", "Random", "StaticArrays"]
git-tree-sha1 = "592cfb5ed8b02804f6a9c04091571c393081f73a"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.5.12"

    [deps.GeometryBasics.extensions]
    ExtentsExt = "Extents"
    GeometryBasicsGeoInterfaceExt = "GeoInterface"
    IntervalSetsExt = "IntervalSets"

    [deps.GeometryBasics.weakdeps]
    Extents = "411431e0-e8b7-467b-b5e0-f676ba4f2910"
    GeoInterface = "cf35fbd7-0cd7-5166-be24-54bfbe79505f"
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"

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
git-tree-sha1 = "090526e65de8f69648ac156daae153de8b56df62"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.88.3+0"

[[deps.Graphics]]
deps = ["Colors", "LinearAlgebra", "NaNMath"]
git-tree-sha1 = "a641238db938fff9b2f60d08ed9030387daf428c"
uuid = "a2bd30eb-e257-5431-a919-1863eab51364"
version = "1.1.3"

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "69ffb934a5c5b7e086a0b4fee3427db2556fba6e"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.16+0"

[[deps.Graphviz_jll]]
deps = ["Artifacts", "Cairo_jll", "Expat_jll", "JLLWrappers", "Libdl", "Pango_jll", "Zlib_jll"]
git-tree-sha1 = "c2b4dd5cf7f6a5c2f9144a8a9f115800eba1c9cf"
uuid = "3c863552-8265-54e4-a6dc-903eb78fde85"
version = "15.1.0+0"

[[deps.GridLayoutBase]]
deps = ["GeometryBasics", "InteractiveUtils", "Observables"]
git-tree-sha1 = "ef70da5e123a06a29e2d6ddff0f09985bc226491"
uuid = "3955a311-db13-416c-9275-1d80ed98e5e9"
version = "0.11.3"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll"]
git-tree-sha1 = "9d9531a9cb63a9edc33836414e82a07e81710de2"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "100.14004.0+0"

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
git-tree-sha1 = "c35847ca5b4997fc8418836354a56c459bcf48d8"
uuid = "e33a78d0-f292-5ffc-b300-72abe9b543c8"
version = "2.14.0+0"

[[deps.HypergeometricFunctions]]
deps = ["Gamma", "LinearAlgebra"]
git-tree-sha1 = "31bb6c92405c084617facc1d7ed9eb6c402d061e"
uuid = "34004b35-14d8-5ef3-9330-4cdb6864b03a"
version = "0.3.30"

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
git-tree-sha1 = "f0f005f997dfb8c5fe23920d99458a9619873893"
uuid = "82e4d734-157c-48bb-816b-45c225c6df19"
version = "0.6.10"

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
git-tree-sha1 = "c72458f1962faeb003bf23cbdb75164fe6280906"
uuid = "18e54dd8-cb9d-406c-a71d-865a43cbb235"
version = "0.1.4"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

[[deps.Interpolations]]
deps = ["Adapt", "AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "48922d06068130f87e43edef52382e6a94305ae6"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.16.3"

    [deps.Interpolations.extensions]
    InterpolationsForwardDiffExt = "ForwardDiff"
    InterpolationsUnitfulExt = "Unitful"

    [deps.Interpolations.weakdeps]
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.IntervalArithmetic]]
deps = ["CRlibm", "CoreMath", "MacroTools", "OpenBLASConsistentFPCSR_jll", "Printf", "Random", "RoundingEmulator"]
git-tree-sha1 = "1c531bf0f8a5c60a340926e058fd3f209b5eef5d"
uuid = "d1acc4aa-44c8-5952-acd4-ba5d80a2a253"
version = "1.0.12"

    [deps.IntervalArithmetic.extensions]
    IntervalArithmeticArblibExt = "Arblib"
    IntervalArithmeticDiffRulesExt = "DiffRules"
    IntervalArithmeticForwardDiffExt = "ForwardDiff"
    IntervalArithmeticIntervalSetsExt = "IntervalSets"
    IntervalArithmeticIrrationalConstantsExt = "IrrationalConstants"
    IntervalArithmeticLinearAlgebraExt = "LinearAlgebra"
    IntervalArithmeticMakieExt = "Makie"
    IntervalArithmeticRecipesBaseExt = "RecipesBase"
    IntervalArithmeticSparseArraysExt = "SparseArrays"

    [deps.IntervalArithmetic.weakdeps]
    Arblib = "fb37089c-8514-4489-9461-98f9c8763369"
    DiffRules = "b552c78f-8df3-52c6-915a-8e097449b14b"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    IrrationalConstants = "92d709cd-6900-40b7-9082-c6be49f344b6"
    LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
    Makie = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
    RecipesBase = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.IntervalSets]]
git-tree-sha1 = "79d6bd28c8d9bccc2229784f1bd637689b256377"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.7.14"

    [deps.IntervalSets.extensions]
    IntervalSetsRandomExt = "Random"
    IntervalSetsRecipesBaseExt = "RecipesBase"
    IntervalSetsStatisticsExt = "Statistics"

    [deps.IntervalSets.weakdeps]
    Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
    RecipesBase = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
    Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

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
git-tree-sha1 = "7204148362dafe5fe6a273f855b8ccbe4df8173e"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.8.0"

[[deps.JSON]]
deps = ["Dates", "Logging", "Parsers", "PrecompileTools", "StructUtils", "UUIDs", "Unicode"]
git-tree-sha1 = "88352712893ec50bee3680605891eaf0e9ed6368"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "1.8.0"

    [deps.JSON.extensions]
    JSONArrowExt = ["ArrowTypes"]

    [deps.JSON.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"

[[deps.JpegTurbo]]
deps = ["CEnum", "FileIO", "ImageCore", "JpegTurbo_jll", "TOML"]
git-tree-sha1 = "9496de8fb52c224a2e3f9ff403947674517317d9"
uuid = "b835a17e-a41a-41e7-81f0-2f016b05efe0"
version = "0.1.6"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "037babc10853eeb8e585418922246cb97b8e5b74"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.2.0+1"

[[deps.JuliaSyntaxHighlighting]]
deps = ["StyledStrings"]
uuid = "ac6e5ff7-fb65-4e79-a425-ec3bc9c03011"
version = "1.12.0"

[[deps.KernelDensity]]
deps = ["Distributions", "DocStringExtensions", "FFTA", "Interpolations", "StatsBase"]
git-tree-sha1 = "9eda8292dd3268b3b7ec9df21bbfac24e177ec52"
uuid = "5ab0869b-81aa-558d-bb23-cbf5423bbe9b"
version = "0.6.12"

[[deps.LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "059aabebaa7c82ccb853dd4a0ee9d17796f7e1bc"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.3+0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "39bca05343661c347aae0bca57a5994a0bf4f08d"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "4.2.0+0"

[[deps.LLVM]]
deps = ["CEnum", "LLVMExtra_jll", "Libdl", "PrecompileTools", "Preferences", "Printf", "Unicode"]
git-tree-sha1 = "d4bfee24427f4f441bd9212a107e375c39663aab"
uuid = "929cbde3-209d-540e-8aea-75f648917ca0"
version = "9.13.1"

    [deps.LLVM.extensions]
    BFloat16sExt = "BFloat16s"

    [deps.LLVM.weakdeps]
    BFloat16s = "ab4f0b2a-ad5b-11e8-123f-65d77653426b"

[[deps.LLVMExtra_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl", "TOML"]
git-tree-sha1 = "d77aea19c9a71059a021acd99b0a4343e9661d94"
uuid = "dad2f222-ce93-54a1-a47d-0025e8a3acab"
version = "0.0.47+0"

[[deps.LLVMOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e5b100780d4d30d63b4618d7930d48af409c1772"
uuid = "1d63c593-3942-5779-bab2-d838dc0a180e"
version = "23.1.1+0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "f88f3ccef05a6a72a0cf0ed417c8fd68530f4ab2"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.4.1"

[[deps.Latexify]]
deps = ["Format", "Ghostscript_jll", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "OrderedCollections", "Requires"]
git-tree-sha1 = "df7566479bd64f20bd16b09960145e70160ffb3b"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.16.12"

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
git-tree-sha1 = "d4816abce26971e3237b46a47b99991f306e4832"
uuid = "1d6d02ad-be62-4b6b-8a6d-2f90e265016e"
version = "0.3.0"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "OpenSSL_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.15.0+0"

[[deps.LibGit2]]
deps = ["LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"
version = "1.11.0"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "OpenSSL_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.9.0+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "OpenSSL_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.3+1"

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
git-tree-sha1 = "cc3ad4faf30015a3e8094c9b5b7f19e85bdf2386"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.42.0+0"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "XZ_jll", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "aebd334d06cee9f24cea70bd19a39749daf73881"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.7.3+0"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "d620582b1f0cbe2c72dd1d5bd195a9ce73370ab1"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.42.0+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.12.0"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "bba2d9aa057d8f126415de240573e86a8f39d2a1"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "1.0.1"

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

[[deps.MIMEs]]
git-tree-sha1 = "c64d943587f7187e751162b3b84445bbbd79f691"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "1.1.0"

[[deps.MacroTools]]
git-tree-sha1 = "1e0228a030642014fe5cfe68c2c0a818f9e3f522"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.16"

[[deps.Makie]]
deps = ["Animations", "Base64", "CRC32c", "ColorBrewer", "ColorSchemes", "ColorTypes", "Colors", "ComputePipeline", "Contour", "Dates", "DelaunayTriangulation", "Distributions", "DocStringExtensions", "Downloads", "FFMPEG_jll", "FileIO", "FilePaths", "FixedPointNumbers", "Format", "FreeType", "FreeTypeAbstraction", "GeometryBasics", "GridLayoutBase", "ImageBase", "ImageIO", "InteractiveUtils", "Interpolations", "IntervalSets", "InverseFunctions", "Isoband", "KernelDensity", "LaTeXStrings", "LinearAlgebra", "MacroTools", "Markdown", "MathTeXEngine", "Observables", "OffsetArrays", "PNGFiles", "Packing", "Pkg", "PlotUtils", "PolygonOps", "PrecompileTools", "Printf", "REPL", "Random", "RelocatableFolders", "Scratch", "ShaderAbstractions", "SignedDistanceFields", "SparseArrays", "Statistics", "StatsBase", "StatsFuns", "StructArrays", "TriplotBase", "UnicodeFun", "Unitful"]
git-tree-sha1 = "37b10d17f74f54dc5fa7d3c6c20fd75613c71d80"
uuid = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
version = "0.24.14"

    [deps.Makie.extensions]
    MakieDynamicQuantitiesExt = "DynamicQuantities"

    [deps.Makie.weakdeps]
    DynamicQuantities = "06fc5a27-2a28-4c7c-a15d-362465fb6821"

[[deps.MappedArrays]]
git-tree-sha1 = "0ee4497a4e80dbd29c058fcee6493f5219556f40"
uuid = "dbb5928d-eab1-5f90-85c2-b9b0edb7c900"
version = "0.4.3"

[[deps.Markdown]]
deps = ["Base64", "JuliaSyntaxHighlighting", "StyledStrings"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.MathTeXEngine]]
deps = ["AbstractTrees", "Automa", "DataStructures", "FreeTypeAbstraction", "GeometryBasics", "LaTeXStrings", "REPL", "RelocatableFolders", "UnicodeFun"]
git-tree-sha1 = "aa1078778be5a8e5259ff04fbc3d258b3e78d464"
uuid = "0a4f8689-d25c-4efe-a92b-7142dfc1aa53"
version = "0.6.9"

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

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2025.11.4"

[[deps.MuladdMacro]]
deps = ["PrecompileTools"]
git-tree-sha1 = "283bf85d4a767481dd924dff0eee1735e95f449e"
uuid = "46d2c3a1-f734-5fdb-9937-b9b9aeba4221"
version = "0.2.7"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "dbd2e8cd2c1c27f0b584f6661b4309609c5a685e"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.1.4"

[[deps.Netpbm]]
deps = ["FileIO", "ImageCore", "ImageMetadata"]
git-tree-sha1 = "d92b107dbb887293622df7697a2223f9f8176fcd"
uuid = "f09324ee-3d7c-5217-9330-fc30815ba969"
version = "1.1.1"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.3.0"

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
git-tree-sha1 = "38a93f17e431141c6470bb67a88952a7c4f0e928"
uuid = "6cdc7f73-28fd-5e50-80fb-958a8875b1af"
version = "0.3.34+0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.29+0"

[[deps.OpenEXR]]
deps = ["Colors", "FileIO", "OpenEXR_jll"]
git-tree-sha1 = "97db9e07fe2091882c765380ef58ec553074e9c7"
uuid = "52e1d378-f018-4a11-a4be-720524705ac7"
version = "0.3.3"

[[deps.OpenEXR_jll]]
deps = ["Artifacts", "Imath_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "1bcebd887dd33f1108210b3954049b1bb8af0e7a"
uuid = "18a262bb-aa17-5467-a713-aee519bc75cb"
version = "3.4.15+0"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.7+0"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.5.6+0"

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
git-tree-sha1 = "94ba93778373a53bfd5a0caaf7d809c445292ff4"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.8.2"

[[deps.PCRE2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "efcefdf7-47ab-520b-bdef-62a2eaa19f15"
version = "10.44.0+1"

[[deps.PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "123266c25174ef6c8d4718920abc206452cf8de6"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.41"
weakdeps = ["StatsBase"]

    [deps.PDMats.extensions]
    StatsBaseExt = "StatsBase"

[[deps.PNGFiles]]
deps = ["Base64", "CEnum", "ImageCore", "IndirectArrays", "OffsetArrays", "libpng_jll"]
git-tree-sha1 = "32b657a0d57c310a1a172bfc8c8cf68c5e674323"
uuid = "f57f5aa1-a3ce-4bc8-8ab9-96f992907883"
version = "0.4.5"

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
git-tree-sha1 = "1912a9f1b9ca55005b03ba075f8e19993583e237"
uuid = "36c8627f-9965-5494-a995-c6b170f724f3"
version = "1.58.2+0"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools"]
git-tree-sha1 = "663e8b48b789916221e0765393b289ca6c88f24e"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "3.0.0"

[[deps.Pixman_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "LLVMOpenMP_jll", "Libdl"]
git-tree-sha1 = "e4a6721aa89e62e5d4217c0b21bd714263779dda"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.46.4+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "Random", "SHA", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.12.1"
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
git-tree-sha1 = "e189d0623e7ce9c37389bac17e80aac3b0302e75"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.83"

[[deps.PolygonOps]]
git-tree-sha1 = "77b3d3605fc1cd0b42d95eba87dfcd2bf67d5ff6"
uuid = "647866c9-e3ac-4575-94e7-e3d426903924"
version = "0.1.2"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "edbeefc7a4889f528644251bdb5fc9ab5348bc2c"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.3.4"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "8b770b60760d4451834fe79dd483e318eee709c4"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.5.2"

[[deps.PrettyTables]]
deps = ["Crayons", "LaTeXStrings", "Markdown", "PrecompileTools", "Printf", "REPL", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "1b8aa19f229b1cea7fc93874a52e49db6a854450"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "3.4.8"

    [deps.PrettyTables.extensions]
    PrettyTablesExcelExt = "XLSX"
    PrettyTablesTypstryExt = "Typstry"

    [deps.PrettyTables.weakdeps]
    Typstry = "f0ed7684-a786-439e-b1e3-3b82803b501e"
    XLSX = "fdbf4ff8-1666-58a4-91e7-1b58723a45e0"

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
deps = ["StyledStrings"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"
version = "1.11.0"

[[deps.ProfileCanvas]]
deps = ["Base64", "JSON", "Pkg", "Profile", "REPL"]
git-tree-sha1 = "990016fb1508b0726a70039f39569720d054c78d"
uuid = "efd6af41-a80b-495e-886c-e51b0c7d77a3"
version = "0.1.7"

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
git-tree-sha1 = "5e8e8b0ab68215d7a2b14b9921a946fee794749e"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.11.3"

    [deps.QuadGK.extensions]
    QuadGKEnzymeExt = "Enzyme"

    [deps.QuadGK.weakdeps]
    Enzyme = "7da242da-08ed-463a-9acd-ee780be4f1d9"

[[deps.REPL]]
deps = ["InteractiveUtils", "JuliaSyntaxHighlighting", "Markdown", "Sockets", "StyledStrings", "Unicode"]
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
git-tree-sha1 = "6d40b2fe70437b01397d2a4d5b020008da4e7019"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.5.2+0"

[[deps.Roots]]
deps = ["Accessors", "CommonSolve", "Printf"]
git-tree-sha1 = "4db094d5e079abbda658acfe1c4d098430417717"
uuid = "f2b01f46-fcfa-551c-844a-d8ac1e96c665"
version = "3.0.8"

    [deps.Roots.extensions]
    RootsChainRulesCoreExt = "ChainRulesCore"
    RootsForwardDiffExt = "ForwardDiff"
    RootsIntervalRootFindingExt = "IntervalRootFinding"
    RootsSymPyExt = "SymPy"
    RootsSymPyPythonCallExt = "SymPyPythonCall"
    RootsUnitfulExt = "Unitful"

    [deps.Roots.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    IntervalRootFinding = "d2bf35a9-74e0-55ec-b149-d360ff49b807"
    SymPy = "24249f21-da20-56a4-8eb1-6a02cf4ae2e6"
    SymPyPythonCall = "bc8888f7-b21e-4b7c-a06a-5d9c9496438c"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.RoundingEmulator]]
git-tree-sha1 = "40b9edad2e5287e05bd413a38f61a8ff55b9557b"
uuid = "5eaf0fd0-dfba-4ccb-bf02-d820a40db705"
version = "0.2.1"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SIMD]]
deps = ["PrecompileTools"]
git-tree-sha1 = "e24dc23107d426a096d3eae6c165b921e74c18e4"
uuid = "fdea26ae-647d-5447-a871-4b548cad5224"
version = "3.7.2"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "9b81b8393e50b7d4e6d0a9f14e192294d3b7c109"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.3.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.ShaderAbstractions]]
deps = ["ColorTypes", "FixedPointNumbers", "GeometryBasics", "LinearAlgebra", "Observables", "StaticArrays"]
git-tree-sha1 = "818554664a2e01fc3784becb2eb3a82326a604b6"
uuid = "65257c39-d410-5151-9873-9b3e5be5013e"
version = "0.5.0"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"
version = "1.11.0"

[[deps.SignedDistanceFields]]
deps = ["Statistics"]
git-tree-sha1 = "3949ad92e1c9d2ff0cd4a1317d5ecbba682f4b92"
uuid = "73760f76-fbc4-59ce-8f25-708e95d2df96"
version = "0.4.1"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "7ddb0b49c109481b046972c0e4ab02b2127d6a75"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.6"

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
git-tree-sha1 = "13cd91cc9be159e3f4d95b857fa2aa383b53772a"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.3"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.12.0"

[[deps.SpecialFunctions]]
deps = ["IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "429071b23f4c9a13fb6582f807cc2ef454082408"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.9.0"
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

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "PrecompileTools", "Random", "StaticArraysCore"]
git-tree-sha1 = "e206cf4850fd7ac4255ffd2b98922f563e18ac53"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.9.20"
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
git-tree-sha1 = "e2b53ce13a53367e96601081e33d34746b571bad"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.5"
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
git-tree-sha1 = "adb9da019510162e67a4493fc235c23203d8b09e"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.34.13"

[[deps.StatsFuns]]
deps = ["HypergeometricFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "91a5737baed20ee31f3faea0e51f57461f6a689e"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "2.2.1"
weakdeps = ["ChainRulesCore", "InverseFunctions"]

    [deps.StatsFuns.extensions]
    StatsFunsChainRulesCoreExt = "ChainRulesCore"
    StatsFunsInverseFunctionsExt = "InverseFunctions"

[[deps.StringManipulation]]
deps = ["PrecompileTools"]
git-tree-sha1 = "773065c6e0e903924a9d838259be74338422aef2"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.5.0"

[[deps.StructArrays]]
deps = ["ConstructionBase", "DataAPI", "Tables"]
git-tree-sha1 = "ad8002667372439f2e3611cfd14097e03fa4bccd"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.7.3"

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

[[deps.StructUtils]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "2d0fc55c61321ba245c47be599570d11bac50303"
uuid = "ec057cc2-7a8d-4b58-b3b3-92acb9f63b42"
version = "2.8.5"

    [deps.StructUtils.extensions]
    StructUtilsMeasurementsExt = ["Measurements"]
    StructUtilsStaticArraysCoreExt = ["StaticArraysCore"]
    StructUtilsTablesExt = ["Tables"]

    [deps.StructUtils.weakdeps]
    Measurements = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
    StaticArraysCore = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
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
version = "7.8.3+2"

[[deps.SysInfo]]
deps = ["Dates", "DelimitedFiles", "Hwloc", "PrecompileTools", "Random", "Serialization"]
git-tree-sha1 = "dbe0126f74fba2f6e378b81271a6e9538cf490ef"
uuid = "90a7ee08-a23f-48b9-9006-0e0e2a9e4608"
version = "0.3.1"

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
git-tree-sha1 = "a94d9bdda1b7bed0046cea645639ab3f62196fac"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.14.0"

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
git-tree-sha1 = "d125980124c8a02da76d03590b4cae9f3d5df077"
uuid = "811555cd-349b-4f26-b7bc-1f208b848042"
version = "1.1.1"

    [deps.ThreadPinning.extensions]
    DistributedExt = "Distributed"
    MPIExt = "MPI"

    [deps.ThreadPinning.weakdeps]
    Distributed = "8ba89e20-285c-5b6f-9357-94700520ee1b"
    MPI = "da04e1cc-30fd-572f-bb4f-1f8673147195"

[[deps.ThreadPinningCore]]
deps = ["LinearAlgebra", "PrecompileTools", "StableTasks"]
git-tree-sha1 = "bb3c6f3b5600fbff028c43348365681b34d06499"
uuid = "6f48bc29-05ce-4cc8-baad-4adcba581a18"
version = "0.4.5"

[[deps.TiffImages]]
deps = ["CodecZstd", "ColorTypes", "DataStructures", "DocStringExtensions", "FileIO", "FixedPointNumbers", "IndirectArrays", "Inflate", "Mmap", "OffsetArrays", "PkgVersion", "PrecompileTools", "ProgressMeter", "SIMD", "UUIDs"]
git-tree-sha1 = "9ca5f1f2d42f80df4b8c9f6ab5a64f438bbd9976"
uuid = "731e570b-9d59-4bfa-96dc-6df516fadf69"
version = "0.11.9"

[[deps.TimerOutputs]]
deps = ["ExprTools", "PrettyTables", "Printf", "Tables"]
git-tree-sha1 = "03271b02dd1c8f87281271575448b9cf6326a961"
uuid = "a759f4b9-e2f1-59dc-863e-4aeb61b1ea8f"
version = "1.2.1"
weakdeps = ["FlameGraphs"]

    [deps.TimerOutputs.extensions]
    FlameGraphsExt = "FlameGraphs"

[[deps.TranscodingStreams]]
git-tree-sha1 = "0c45878dcfdcfa8480052b6ab162cdd138781742"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.11.3"

[[deps.Tricks]]
git-tree-sha1 = "311349fd1c93a31f783f977a71e8b062a57d4101"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.13"

[[deps.TriplotBase]]
git-tree-sha1 = "4d4ed7f294cda19382ff7de4c137d24d16adc89b"
uuid = "981d1d27-644d-49a2-9326-4793e63143c3"
version = "0.1.0"

[[deps.URIs]]
git-tree-sha1 = "908fec9df6c5de98548ead82a468c95ccf6cd263"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.7.0"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"
version = "1.11.0"

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
git-tree-sha1 = "1f0f9f401753701a7e4113b5056ca38d33875b55"
uuid = "1986cc42-f94f-5a68-af5c-568840ba703d"
version = "1.29.0"

    [deps.Unitful.extensions]
    ConstructionBaseUnitfulExt = "ConstructionBase"
    ForwardDiffExt = "ForwardDiff"
    InverseFunctionsUnitfulExt = "InverseFunctions"
    LatexifyExt = ["Latexify", "LaTeXStrings"]
    NaNMathExt = "NaNMath"
    PrintfExt = "Printf"

    [deps.Unitful.weakdeps]
    ConstructionBase = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"
    LaTeXStrings = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
    Latexify = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
    NaNMath = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
    Printf = "de0858da-6303-5e67-8744-51eddeeeb8d7"

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

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Zlib_jll"]
git-tree-sha1 = "80d3930c6347cfce7ccf96bd3bafdf079d9c0390"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.13.9+0"

[[deps.XZ_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e52eca002a11c30a858185efdfb15311e1c7a6bf"
uuid = "ffd25f8a-64ca-5728-b0f7-c24cf3aae800"
version = "5.8.4+0"

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
git-tree-sha1 = "58972370b81423fc546c56a60ed1a009450177c3"
uuid = "a65dc6b1-eb27-53a1-bb3e-dea574b5389e"
version = "0.19.0+0"

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
version = "1.3.1+2"

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
git-tree-sha1 = "ef17c47d22224aaecc76e597ab21a072e025cf7b"
uuid = "a4ae2306-e953-59d6-aa16-d00cac43593b"
version = "3.14.1+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "cb007192783c56d8249db4cf0e3495001edfe414"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.17.5+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.15.0+0"

[[deps.libdrm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libpciaccess_jll"]
git-tree-sha1 = "28e57478e8a160d346a19c28b3fffb9273bcc9c2"
uuid = "8e53e030-5e6c-5a89-a30b-be5b7263a166"
version = "2.4.134+0"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "646634dd19587a56ee2f1199563ec056c5f228df"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.4+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "e51150d5ab85cee6fc36726850f0e627ad2e4aba"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.58+0"

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
version = "1.64.0+1"

[[deps.p7zip_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.7.0+0"

[[deps.pprof_jll]]
deps = ["Artifacts", "Graphviz_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "41bcaa13dd41f13b2290944e5e5be035e90c6bc4"
uuid = "cf2c5f97-e748-59fa-a03f-dda3c62118cb"
version = "2.0.0+0"

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
# ╠═6aef4225-de33-4369-87f3-70e33521e2b5
# ╠═c6208080-8e90-4e6c-be0e-a1a5eb305c87
# ╟─350f9f9b-31e3-4ce7-a933-363e5a207c18
# ╟─793e5df7-19da-42fd-994a-87e1d80b5cd4
# ╟─f5aedf6b-dead-4cbd-add4-992315566932
# ╟─d6e64482-ff4f-4196-9b56-b3939dc93685
# ╟─08e536bc-a1ed-4ba1-9664-97a0ac21b1fc
# ╟─7dc5d5bd-8813-4803-82e0-de4b390f7be1
# ╟─24a58157-e875-4b5b-854a-bec460593be9
# ╟─29003031-0935-4b81-8d61-22e70f0eacf8
# ╟─5ba4c311-f5f3-4941-b93f-4d44353c052a
# ╟─f294d44f-1d17-48c4-8f1e-7df7c5ecedcd
# ╟─bd98b86c-3385-4be7-ab47-e4715d04c8d0
# ╟─48d24767-564c-41e0-9dfc-3a26a7625bed
# ╟─9f06beb2-a130-4d51-8064-77d1ee1067c8
# ╠═675443bb-7cc7-4148-8bd0-3978595e038d
# ╟─66a66b0d-b915-4eeb-b813-14d45893590d
# ╠═05d7c70d-cbdc-4981-9a0c-7263f85bb9aa
# ╠═0c23b4ce-e886-46b6-9a26-be21e53ba181
# ╠═6edcae4d-c362-489b-8d51-315fe84c69b6
# ╠═ff3dfeca-2e26-4e45-93aa-74cd09e5a30c
# ╟─f67151f7-aa08-4179-ab2d-1a95090d45a0
# ╟─b08f34a3-fe13-4d3d-9efe-8e18ad1deea7
# ╠═a577a567-3d13-42fa-b00a-e2856744e5c4
# ╟─a4511dbe-5695-4b8c-b711-2138d052cf31
# ╠═3a02de5a-0f33-4d2b-931c-9841930a359e
# ╠═4cc73931-209f-4584-956c-51e72e0944d2
# ╠═c7b06dac-b648-405d-b694-0477cef516d1
# ╠═e233786d-46f6-4b6c-8b9e-1482ebf78d7e
# ╟─b97e53d9-245a-4133-bbb0-3fd44032b4ed
# ╠═a789728d-7844-4968-9619-057db332df4e
# ╟─60aebab7-25a3-40f9-9660-70b29b6083df
# ╠═9466dca4-d3c6-45dc-8820-9b1c7caad386
# ╟─f6b2444e-3663-41c8-887b-f8ad6d371bcb
# ╠═7e556c79-262e-4936-8fcb-4d74211d2d81
# ╠═664736c8-8ec2-42d7-bb07-2e57270ec089
# ╠═7da88cb8-6999-4571-8076-6df6fbb2a801
# ╟─c9343e98-cdeb-4ca8-83c6-32d7fb5d6330
# ╟─4497f1a2-d55a-40c4-abd4-6cfe6d6db2e2
# ╠═8c63e0ac-7aff-40d8-adb5-a218680d190b
# ╟─46d0c3fe-8367-4fef-87e8-f4aa91ef95e3
# ╠═19613c14-acdb-4f12-a2c5-5431e167ccae
# ╟─42a36172-362c-4a62-82da-346efcb47a74
# ╟─0c369f82-4269-46a4-9fae-f09a46849251
# ╠═fade6b6e-bb15-4734-9435-af6eb5fb0fbf
# ╟─6e1d446b-f3b2-4bd8-9ee4-b7aae6156d08
# ╠═683e739b-1c6e-40b8-8fe6-d259687949e8
# ╠═72b67bec-a6e3-48c5-9510-dfa2e0b02fe9
# ╟─a84d7b08-103d-4fe3-b265-9ca854f5f5a7
# ╟─25e35d99-a2cd-4f87-a391-e3ccf124953f
# ╠═44ab086e-0013-42a6-91d2-d5cacbe260e3
# ╠═2d8b9925-8095-49e3-89ca-2deb7c247a20
# ╠═6bbe5b23-1fb5-4424-81ae-b465c90f4c69
# ╟─72b24d09-5fe5-43bf-84fa-ac38b22de458
# ╠═4e2edf55-ee91-4785-b2c5-40cc17678de8
# ╟─45bf4e0f-b8ea-44bd-843c-11618ab3f47a
# ╠═f3912092-f7dd-4102-9a36-6b55d98d7dbc
# ╠═146ec37c-3b4d-478a-909e-4a201211623e
# ╠═405edc58-cc41-4e0b-b0fd-069ed69c0666
# ╠═50bab76a-275c-4630-a704-8136ddd0eb6e
# ╠═f0651468-5071-4f1a-9a03-dea756711e05
# ╟─80caaff4-0db2-4101-ba3f-8130065fe67e
# ╟─d8c765b0-06e8-4cad-a0f5-caa13b8a8943
# ╟─407a3519-5a71-4c10-a115-d3d7d79a13f3
# ╟─3471f218-d38c-47e1-b150-010bb589cecc
# ╠═e74fcbaf-ee04-4a62-bb75-d0d60cff9008
# ╠═e02f6740-237a-4ebd-91aa-40e65615c9f7
# ╠═97526d18-3dd6-43a1-9a1c-7501a07a44cc
# ╠═5f3d5027-3bdc-401a-93c7-89f88d22cb4a
# ╠═9a3ad117-5fd5-4601-bc54-6a2261150511
# ╠═e9aa9ce3-d63e-4cde-89ad-ff8e2e5876de
# ╠═0bf14539-ae70-4410-bcaf-e9bb4a635149
# ╟─d2ca125b-6a89-4df3-8985-a0e17c1dbc32
# ╟─ca0880f4-f26b-41b7-b722-b8d6c5e23acd
# ╠═62133544-67cd-47a1-9a55-68dfa8441b87
# ╠═58f17eb8-04e7-43ad-af17-9e2c06143f15
# ╠═e99f8bc7-81a2-4583-a23a-c7365eaaf45d
# ╠═86dd48ac-944f-4e47-bd78-47ccbed5ef45
# ╟─80388821-8451-486c-8c32-e5c5174a0536
# ╟─a28e235d-1023-4b69-9f68-e9db9b793c0f
# ╟─3e06cbf8-2d5c-4168-a62f-e45fba42d79c
# ╠═f90c725d-a183-4af1-91d3-548ab2dd1072
# ╟─c6d4aa26-3ef5-4015-ad66-e309a450a862
# ╠═85c37cc7-26f0-47a7-b60e-e0e5bec201f1
# ╠═d3e81cdf-5bc1-44a3-a7d5-9073d9a158ce
# ╠═cef56b1e-96bc-46c0-bc96-e064b43100b4
# ╠═adeacaf2-15d5-4e26-87ad-a63c6a1252d3
# ╠═92eaad3a-31bf-4db4-b70c-ed03b3d69c9b
# ╠═02cfc5c1-ac2a-46cc-845a-9ed1d56251ea
# ╠═f244f4fb-29c4-4046-957c-561360454137
# ╠═5becd38b-9d23-482c-865d-d3a9a35b241e
# ╠═4307cf31-cdb1-4295-ad4f-a306ab2ec526
# ╠═ce42658d-4714-4c10-bfba-3722f8b8b7d9
# ╟─41ff1baa-8e2b-4ca0-8a14-8dea227c6f60
# ╠═0fd9b537-efb7-4933-8969-7fb2511a8cbd
# ╠═a7cfc945-4260-4cfe-ad61-0124b1ce4b0b
# ╠═a7f06489-85dd-4485-8d67-519b579bb32b
# ╠═98c27c6f-a1d1-4be2-bc98-f6a81ac48876
# ╟─57f2cab6-b1e9-4f8f-9f9e-afee18eead4b
# ╟─19b3c6d0-eff5-4344-b7f5-63e5695c1b7b
# ╟─1c5089a9-3794-42ec-9d1d-b935ce525a95
# ╟─b80c3dd2-3e99-4df9-8562-532a0cd06f06
# ╟─bbdc81ef-b7f1-41d3-8c2e-ce9b3fe87d17
# ╟─3ba72203-3f08-4a0e-9de1-dd57e4f07484
# ╠═b3fdd7a2-4026-4560-bbbe-61cb084ba7ad
# ╠═4c9541d3-1c44-4605-9351-622a467b82f4
# ╟─d089e5aa-d559-4491-aef4-3f9ee504862d
# ╠═daa91aff-fabd-4562-ac41-5b9a179343c1
# ╠═36701e85-124a-4417-9a97-429cd24663f7
# ╠═93249320-2c2a-40d0-b108-8ca35ab424f4
# ╟─5d40a8fd-dc62-4fac-a76e-49a44aabdec3
# ╠═24127ab1-0561-4748-bc55-275b60237e33
# ╠═10348401-8c0e-4d66-bc8d-51e519f76aa2
# ╠═fd79e187-bf0d-4047-aa54-1b76184bbf28
# ╠═40fdd39b-9e4b-46a0-88fb-5a42a2aae4cf
# ╟─3f3aef8c-d7da-4431-a755-378153dad294
# ╠═86916ce5-0a22-46d4-aba2-ddcbbd1d87f3
# ╟─c8ed69f5-2d35-4b82-8f69-9ca69fe21f3f
# ╟─5979387a-38d5-4b8c-908c-219325a617d6
# ╟─7e6a9b3a-7ca0-4805-8abc-0f38b05c5718
# ╠═da0b4696-df79-42b6-a516-10186483ddc4
# ╟─45dd1a2e-252a-400d-926a-5c2994d6d2fe
# ╟─acecd1a1-4a70-4355-a87e-aed1d4c63dc6
# ╟─dd99c12d-7354-4b55-9764-1a5495edea7e
# ╠═3a9632df-7e48-4064-af6d-1946f962ec8b
# ╟─6ee0e4d0-fc6d-43ca-9395-b9e3b341b34b
# ╟─661f8bdd-463d-49a6-8c97-cbc5da8bf143
# ╠═44eea298-437c-4b67-a6ae-135279e91575
# ╠═c65bcaaf-82cb-418a-845e-94a9eaaab64e
# ╠═a7c57f4e-ff4f-4179-93df-a5b602290ab0
# ╟─6b7401c0-f198-4073-accb-d7a627f2d01b
# ╟─c31b20f6-7fc2-4f9e-b52b-7dab1723a045
# ╠═6d452eb2-fc1a-410e-be34-c54526e14a0f
# ╠═6dadd682-8980-47c5-aedd-aa3e57122697
# ╟─4e8bcfd8-11d3-451c-882d-4ef0aceca30b
# ╟─0737ac5f-c947-44e4-b2f0-009529965f48
# ╟─af00dd69-1637-4aaa-b818-1ec653dee5e3
# ╠═9de7f5d6-697b-44bd-9c7e-775a80a97d74
# ╟─ef27fdfc-9d17-4ed8-aed8-1fcd9f586518
# ╟─b63778a0-a167-4949-87fa-0cda95192726
# ╟─872cdcd1-78f9-475b-9e4c-3bbe446b1d87
# ╠═a91206f9-2f69-40dc-9f3d-f099ee2a4826
# ╠═cc9facb8-d67e-4719-aea9-5f417d011b20
# ╠═e7309389-4fb5-4633-8705-b3889b7dca72
# ╠═3df69046-2804-4cb8-8e91-b4433a66cb72
# ╠═76265fcf-5428-464b-bf6f-dec689d091d6
# ╟─f68c8205-9d70-449e-979c-6e3898ed9b67
# ╟─f2d1282f-037d-4f60-b9fe-921839959e52
# ╟─2242d55d-49f9-4e68-bfee-f3b92e2cc4c1
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
