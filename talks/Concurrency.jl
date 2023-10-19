### A Pluto.jl notebook ###
# v0.19.29

#> [frontmatter]
#> title = "Concurrency in Julia"
#> date = "2023-10-19"
#> license = "MIT"
#> 
#>     [[frontmatter.author]]
#>     name = "Valentin Churavy"
#>     url = "https:://vchuravy.dev"

using Markdown
using InteractiveUtils

# ╔═╡ d90da326-c61b-4198-9880-2e93a5b4ac90
using Hwloc

# ╔═╡ 604fceb5-bd32-484e-8854-416b2f7cb210
using PlutoUI, ThreadPinning

# ╔═╡ f0c67b03-aa63-41ab-95c8-82dcbdf86281
html"<button onclick='present()'>Toggle presentation mode</button>"

# ╔═╡ 42e44fc4-1f26-4563-af42-512c7fa50f4e
md"""
# Concurrency in Julia

Julia has a `Task` based concurrency model, most similar to Go.
Users can `@spawn` work and use **channels**, **atomics** and **locks**
to communicate between tasks.

## Parallelism

Julia uses a homegrown pthread based task runtime + scheduler.
Use `julia --threads=auto` or `julia --threads=4` to start Julia with a number
of worker threads.

### A side-note on naming (Historical note #1)

Due to a historical glitch Julia put all the task related functionality into a module
called `Threads`. I aim to rectify this eventually, since this causes confusion.

Julia doesn't have threads... It only ever had tasks and threads are an implementations detail.
"""

# ╔═╡ d24dacda-6e90-11ee-0e3f-336c6608daab
const Tasks = Base.Threads

# ╔═╡ 903ccef4-950a-49e2-b873-2139fdcfe68a
topology_info()

# ╔═╡ bcdc4654-8ba2-4907-a92c-3305861dedb8
Tasks.nthreads()

# ╔═╡ 4811b76d-5461-4f07-b26e-8be8e4c4dcf4
function fib(x)
	if x <= 1
		return 1
	else
		b = Tasks.@spawn fib(x-2)
		a = fib(x-1)
		return a+(fetch(b)::Int)
	end
end

# ╔═╡ 15a7671b-5af8-49b6-98d3-95b3635f1a03
fib(5)

# ╔═╡ 722e6911-b447-4774-9188-cbe19421ad1b
let ch = Channel{Int}(Inf) # buffered
	@sync begin
		for i in 1:10
			Tasks.@spawn put!(ch, rand(Int))
		end
	end
	close(ch) # Otherwise collect will wait for more data
	collect(ch)
end

# ╔═╡ 1c77e3fc-457a-49e8-84fd-54915a0a9c58
with_terminal() do
	pinthreads(:random)
	threadinfo()
end

# ╔═╡ 4f67afe8-be94-4396-9340-a7de0329d89e
with_terminal() do
	pinthreads(:compact)
	threadinfo()
end

# ╔═╡ f5fa68e4-7c21-4b25-8b63-f3dd0751f795
with_terminal() do
	pinthreads(:numa)
	threadinfo()
end

# ╔═╡ 15f14a5f-ad95-45fa-8dac-cd9e8f613a84
md"""
### The `@threads` macro (Historical note #2)
Before Julia's task runtime supported multiple worker thread, we had the `@threads`
macro for "parallel for-loops"

```julia
function saxpy!(Z, a, X, Y)
    @threads for i in eachindex(Z, X, Y)
        Z[i] = a*X[i] * Y[i]
    end
    return nothing
end
```

### GPU parallelism

Julia has a full-stack GPU programming environment.

1. Kernel-level
2. Library-based
3. Data-parallel primitives

#### Kernels

```julia
using CUDA

function gpu_add2!(y, x)
    index = threadIdx().x
    stride = blockDim().x
    for i in index:stride:length(y)
        @inbounds y[i] += x[i]
    end
    return nothing
end

@cuda threads=256 gpu_add2!(y, x)
```

#### Data-parallel primitives

- `map`, `reduce`, `mapreduce`
- broadcasting

```
map!(+, y, y, x)
y .+= x
```

### Research questions

#### Auto-offloading?
```julia
function saxpy!(Z, a, X, Y)
    for i in eachindex(Z, X, Y)
        Z[i] = a*X[i] * Y[i]
    end
    return nothing
end

N = 1024
Z = CUDA.zeros(N)
X = CUDA.rand(N)
Y = CUDA.rand(N)
saxpy!(Z, 2.0, X, Y) # This runs on CPU

Z .= 2.0 .* X .+ Y # This run on GPU
```

#### Language support for data-parallel primitives on the CPU?

Currently `map`&co are all single-threaded since we would need to prove that `f` 
is safe to auto-parallelize, and that array loads/stores are unaliased.

(The latter can be surprisingly tricky, looking at you `BitArray`)


#### Scheduler and Runtime improvements

- Pluggable scheduler?
- Better insights and instrumentation?
- Cheaper task-switching?
- Growable-stack / Currently we don't have a cactus-stack.
- ...

"""

# ╔═╡ b47bb35f-18f1-4e92-8e76-b35a13523abd
md"""
## Julia Compilation

Julia uses a multi-stage compilation pipeline with the upper half being written in Julia, and the lower-stage(s) using LLVM.

The pipeline is introspectable and fairly hackable.
"""

# ╔═╡ 38f6bf5d-9055-43e9-9336-bcae2c9d5aa8
function f(N)
    acc = 0
    for i in 1:N
        acc += 1
    end
    return acc
end

# ╔═╡ 5ce1082c-b600-4cd0-b6b5-d676d16d5c69
@code_lowered f(10)

# ╔═╡ f2c194d1-8e06-495a-a78b-1b09821a189c
@code_typed optimize=false f(10)

# ╔═╡ 4c6e23c9-2dc5-41ae-a122-515ad37e57a1
@code_typed optimize=true f(10)

# ╔═╡ a2e7b46d-6ae2-4d50-bdbd-accc0d4ad542
with_terminal() do
	@code_llvm optimize=false f(10)
end

# ╔═╡ fc409a14-46a6-4790-84b0-0b071bde2bd9
with_terminal() do
	@code_llvm optimize=true f(10)
end

# ╔═╡ 9f288f86-d868-4509-83c0-66479cdebc86
with_terminal() do
	@code_native f(10)
end

# ╔═╡ 33c85b14-785c-4516-ba8d-4febc4da123b
md"""
## Julia + Tapir

### IR

Firstly we introduce new IR concepts that mimick the OpenCilk+Tapir IR nodes

```julia
import Tapir # requires cesmix-mit/julia
function fib(N)
    if N <= 1
        return N
    end
    x1 = Ref{Int64}()
    local x2
    Tapir.@sync begin
        Tapir.@spawn x1[] = fib(N - 1)
        x2 = fib(N - 2)
    end
    return x1[] + x2
end
```

Lowers to:

```julia-repl
julia> @code_lowered fib(10)
CodeInfo(
1 ─       Core.NewvarNode(:(x2))
│         Core.NewvarNode(:(x1))
│   %3  = N <= 1
└──       goto #3 if not %3
2 ─       return N
3 ─ %6  = Core.apply_type(Main.Ref, Main.Int64)
│         x1 = (%6)()
│   %8  = $(Expr(:syncregion))
│         token#216 = %8
└──       detach within token#216, reattach to #5
4 ─ %11 = N - 1
│   %12 = Main.fib(%11)
│         Base.setindex!(x1, %12)
└──       reattach within token#216, #5
5 ┄ %15 = N - 2
│   %16 = Main.fib(%15)
│         x2 = %16
│         v = %16
└──       sync within token#216
6 ─       v
│   %21 = Base.getindex(x1)
│   %22 = %21 + x2
└──       return %22
)
```

and after type inference:

```julia-repl
julia> @code_typed fib(10)
CodeInfo(
1 ─ %1  = Base.sle_int(N, 1)::Bool
└──       goto #3 if not %1
2 ─       return N
3 ─ %4  = %new(Base.RefValue{Int64})::Base.RefValue{Int64}
│   %5  = $(Expr(:syncregion))
└──       detach within %5, reattach to #5
4 ─ %7  = Base.sub_int(N, 1)::Int64
│   %8  = invoke Main.fib(%7::Int64)::Int64
│         Base.setfield!(%4, :x, %8)::Int64
└──       reattach within %5, #5
5 ┄ %11 = Base.sub_int(N, 2)::Int64
│   %12 = invoke Main.fib(%11::Int64)::Int64
└──       sync within %5
6 ─ %14 = Base.getfield(%4, :x)::Int64
│   %15 = Base.add_int(%14, %12)::Int64
└──       return %15
) => Int64
```
"""

# ╔═╡ 55fc7718-3d85-4f27-b2d4-5b7dd9851119
md"""
### Lowering and optimization

Now we have a choice:

1. Lower the IR above to LLVM IR
2. Perform out-lining before lowering to LLVM IR

Both choices are attractive for different reasons.

But let's pursue `1.`.

```julia-repl
julia> @code_llvm optimize=false debuginfo=:none fib(10)
; Function Signature: fib(Int64)
; Function Attrs: sspstrong
define i64 @julia_fib_3176(i64 signext %"N::Int64") #0 {
top:
  %pgcstack = call {}*** @julia.get_pgcstack()
  %0 = bitcast {}*** %pgcstack to {}**
  %current_task = getelementptr inbounds {}*, {}** %0, i64 -14
  %1 = bitcast {}** %current_task to i64*
  %world_age = getelementptr inbounds i64, i64* %1, i64 15
  %N = alloca i64, align 8
  store i64 %"N::Int64", i64* %N, align 8
  %"*Core.Intrinsics.sle_int#3178" = load {}*, {}** @"*Core.Intrinsics.sle_int#3178", align 8
  %2 = bitcast {}* %"*Core.Intrinsics.sle_int#3178" to {}**
  %3 = getelementptr inbounds {}*, {}** %2, i64 0
  %4 = icmp sle i64 %"N::Int64", 1
  %5 = zext i1 %4 to i8
  %6 = trunc i8 %5 to i1
  %7 = xor i1 %6, true
  br i1 %7, label %L4, label %L3

L3:                                               ; preds = %top
  ret i64 %"N::Int64"

L4:                                               ; preds = %top
  %"+Main.Base.RefValue#3179" = load {}*, {}** @"+Main.Base.RefValue#3179", align 8
  %RefValue = ptrtoint {}* %"+Main.Base.RefValue#3179" to i64
  %8 = inttoptr i64 %RefValue to {}*
  %9 = bitcast {}*** %pgcstack to {}**
  %current_task1 = getelementptr inbounds {}*, {}** %9, i64 -14
  %"new::RefValue" = call noalias nonnull dereferenceable(8) {}* @julia.gc_alloc_obj({}** %current_task1, i64 8, {}* %8) #4
  %10 = call token @llvm.syncregion.start()
  detach within %10, label %L7, label %L11

L7:                                               ; preds = %L4
  %pgcstack2 = call {}*** @julia.get_pgcstack()
  %"*Core.Intrinsics.sub_int#3180" = load {}*, {}** @"*Core.Intrinsics.sub_int#3180", align 8
  %11 = bitcast {}* %"*Core.Intrinsics.sub_int#3180" to {}**
  %12 = getelementptr inbounds {}*, {}** %11, i64 0
  %13 = sub i64 %"N::Int64", 1
  %"*Main.fib#3181" = load {}*, {}** @"*Main.fib#3181", align 8
  %14 = bitcast {}* %"*Main.fib#3181" to {}**
  %15 = getelementptr inbounds {}*, {}** %14, i64 0
  %16 = call i64 @julia_fib_3176(i64 signext %13)
  %"*Core.setfield!#3182" = load {}*, {}** @"*Core.setfield!#3182", align 8
  %17 = bitcast {}* %"*Core.setfield!#3182" to {}**
  %18 = getelementptr inbounds {}*, {}** %17, i64 0
  %19 = bitcast {}* %"new::RefValue" to i64*
  store i64 %16, i64* %19, align 8
  reattach within %10, label %L11

L11:                                              ; preds = %L7, %L4
  %"*Core.Intrinsics.sub_int#31803" = load {}*, {}** @"*Core.Intrinsics.sub_int#3180", align 8
  %20 = bitcast {}* %"*Core.Intrinsics.sub_int#31803" to {}**
  %21 = getelementptr inbounds {}*, {}** %20, i64 0
  %22 = sub i64 %"N::Int64", 2
  %"*Main.fib#31814" = load {}*, {}** @"*Main.fib#3181", align 8
  %23 = bitcast {}* %"*Main.fib#31814" to {}**
  %24 = getelementptr inbounds {}*, {}** %23, i64 0
  %25 = call i64 @julia_fib_3176(i64 signext %22)
  sync within %10, label %L14

L14:                                              ; preds = %L11
  %"*Core.getfield#3183" = load {}*, {}** @"*Core.getfield#3183", align 8
  %26 = bitcast {}* %"*Core.getfield#3183" to {}**
  %27 = getelementptr inbounds {}*, {}** %26, i64 0
  %28 = bitcast {}* %"new::RefValue" to i64*
  %"new::RefValue.x" = load i64, i64* %28, align 8
  %"*Core.Intrinsics.add_int#3184" = load {}*, {}** @"*Core.Intrinsics.add_int#3184", align 8
  %29 = bitcast {}* %"*Core.Intrinsics.add_int#3184" to {}**
  %30 = getelementptr inbounds {}*, {}** %29, i64 0
  %31 = add i64 %"new::RefValue.x", %25
  ret i64 %31
}
```

and after optimization + tapir target lowering

```
julia> @code_llvm optimize=true dump_module=true debuginfo=:none fib(10)
; ModuleID = 'fib'
source_filename = "fib"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

%struct.__rts_stack_frame = type { i64 }

; Function Signature: fib(Int64)
; Function Attrs: sspstrong stealable
define i64 @julia_fib_3239(i64 signext %"N::Int64") #0 {
top:
  %0 = alloca { i64, i64* }, align 8
  %1 = alloca i64, align 8
  %__rts_sf = alloca %struct.__rts_stack_frame, align 8
  call void @__rts_enter_frame(%struct.__rts_stack_frame* nonnull %__rts_sf)
  %2 = icmp sgt i64 %"N::Int64", 1
  br i1 %2, label %L4, label %top.common.ret_crit_edge

top.common.ret_crit_edge:                         ; preds = %top
  %.pre = bitcast i64* %1 to i8*
  br label %common.ret

common.ret:                                       ; preds = %L4, %top.common.ret_crit_edge
  %.0..0..sroa_cast6.pre-phi.pre-phi.pre-phi = phi i8* [ %.pre, %top.common.ret_crit_edge ], [ %.0..0..sroa_cast, %L4 ]
  %common.ret.op = phi i64 [ %8, %L4 ], [ %"N::Int64", %top.common.ret_crit_edge ]
  call void @llvm.lifetime.end.p0i8(i64 8, i8* nonnull %.0..0..sroa_cast6.pre-phi.pre-phi.pre-phi)
  call void @__rts_leave_frame(%struct.__rts_stack_frame* nonnull %__rts_sf)
  ret i64 %common.ret.op

L4:                                               ; preds = %top
  %.0..0..sroa_cast = bitcast i64* %1 to i8*
  call void @llvm.lifetime.start.p0i8(i64 8, i8* nonnull %.0..0..sroa_cast)
  %3 = getelementptr inbounds { i64, i64* }, { i64, i64* }* %0, i64 0, i32 0
  store i64 %"N::Int64", i64* %3, align 8
  %4 = getelementptr inbounds { i64, i64* }, { i64, i64* }* %0, i64 0, i32 1
  store i64* %1, i64** %4, align 8
  %5 = bitcast { i64, i64* }* %0 to i8*
  call void @__rts_spawn(%struct.__rts_stack_frame* nonnull %__rts_sf, void (i8*)* bitcast (void ({ i64, i64* }*)* @julia_fib_3239.outline_L7.otd1 to void (i8*)*), i8* nonnull %5, i64 16, i64 8)
  %6 = add nsw i64 %"N::Int64", -2
  %7 = call i64 @julia_fib_3239(i64 signext %6)
  call void @__rts_sync(%struct.__rts_stack_frame* nonnull %__rts_sf)
  %.0.load7 = load i64, i64* %1, align 8
  %8 = add i64 %.0.load7, %7
  br label %common.ret
}

; Function Attrs: noinline optnone
define nonnull {}* @jfptr_fib_3240({}* %"function::Core.Function", {}** noalias nocapture noundef readonly %"args::Any[]", i32 %"nargs::UInt32") #1 {
top:
  %0 = getelementptr inbounds {}*, {}** %"args::Any[]", i32 0
  %1 = load {}*, {}** %0, align 8
  %2 = bitcast {}* %1 to i64*
  %3 = load i64, i64* %2, align 8
  %4 = call i64 @julia_fib_3239(i64 signext %3)
  %box_Int64 = call nonnull {}* @ijl_box_int64(i64 signext %4)
  ret {}* %box_Int64
}

declare nonnull {}* @ijl_box_int64(i64 signext)

; Function Signature: fib(Int64)
; Function Attrs: noinline sspstrong
define internal void @julia_fib_3239.outline_L7.otd1({ i64, i64* }* align 8 %.otd1) unnamed_addr #6 {
L4.otd1:
  %0 = getelementptr { i64, i64* }, { i64, i64* }* %.otd1, i64 0, i32 0
  %1 = load i64, i64* %0, align 8
  %2 = getelementptr { i64, i64* }, { i64, i64* }* %.otd1, i64 0, i32 1
  %3 = load i64*, i64** %2, align 8
  %4 = add nsw i64 %1, -1
  %5 = call i64 @julia_fib_3239(i64 signext %4)
  store i64 %5, i64* %3, align 8
  ret void
}
```
"""

# ╔═╡ 4c46365c-d951-44c0-841b-766744cf062e
md"""
### Runtime

Calling Julia from non-Julia worker threads requires some finicking (now much easier than when ~1 ago).

Could we use the Julia task runtime to run Tasks created by Tapir?

```julia
@ccallable function __rts_sync(sf::Ptr{StackFrame})::Cvoid
  tg = Base.unsafe_load(sf).tg::TaskGroup
  Base.sync_end(tg)
  return nothing
end

@ccallable function __rts_spawn(sf::Ptr{StackFrame}, func::Ptr{Cvoid}, data::Ptr{Cvoid}, sz::Int, align::Int)::Cvoid
  tg = Base.unsafe_load(sf).tg::TaskGroup
  buf = ccall(:aligned_alloc, Ptr{Cvoid}, (Csize_t, Csize_t), align, sz)
  Base.Libc.memcpy(buf, data, sz)
  buf = Base.unsafe_wrap(Vector{UInt8}, Base.unsafe_convert(Ptr{UInt8}, buf), sz; own = true)
  t = Base.Task(TapirTask(func, buf))
  t.sticky = false
  Base.yield(t) # unfair form of schedule; child-first
  push!(tg, t)
  return nothing
end
```

Indeed we can! We can even write the runtime in Julia
"""

# ╔═╡ 289be8f1-ac6c-49e6-a432-3dd884d04162
md"""
## Challenges

### GC correctness

Julia uses a precise GC (we know at all times where pointers to Julia objects are),
but for that uses custom LLVM passes + addresspaces to track that information.

Performing outlining on the LLVM level can break the needed invariances

### Runtime state
Julia runtime functions need access the the runtime state that is partitioned across worker threads (ptls), before Tapir we would only need to load the current task pointer once, that is no longer true after outlining. So we need to reload the current_task inside the detach.

### Task outputs
With Tapir you occaisionally get a PhiNode after the reattach, we need to teach Julia optimizations that it can't insert PhiNodes after reattach.

Similarly in Julia tasks currently have a return value `fetch(task)`, is this something we want to mimick?

### Concurrency vs may-happen-in-parallel

Julia's tasks are concurrent. OpenCilk/Tapir expects tasks to have may-happen-in-parallel/Serial-projection-property.

```julia
ch = Channel() # unbuffered

@sync begin
    @spawn begin
        put!(ch, 1)
    end
    @spawn begin
        take!(ch)
    end
end
```

Under SPP it would be legal to remove all `@spawn`:

```
ch = Channel()
put!(ch, 1)
take!(ch)
```

And now you created a dead-lock.

Why is this important? Without SPP it is hard to merge two tasks (as is required for coarsening parallel loops).

From a language design perspective you are now introducing two very similar concepts,
with a extremly subtle difference in meaning. 

Could we prove that a Julia task need not be concurrent and could we automatically infer them to be may-happen-in-parallel?

## Next steps:

```julia
function saxpy!(Z, a, X, Y)
    Tapir.@sync for i in eachindex(Z, X, Y)
        Tapir.@spawn Z[i] = a*X[i] * Y[i]
    end
    return nothing
end
```

- Auto-offloading
  - Since Julia does know where memory resides, maybe only for `CuArray`
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
Hwloc = "0e44f5e4-bd66-52a0-8798-143a42290a1d"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
ThreadPinning = "811555cd-349b-4f26-b7bc-1f208b848042"

[compat]
Hwloc = "~2.2.0"
PlutoUI = "~0.7.52"
ThreadPinning = "~0.7.15"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.9.3"
manifest_format = "2.0"
project_hash = "44c0b1f685f6fd19736d920050b52c4177cf55ac"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "91bd53c39b9cbfb5ef4b015e8b582d344532bd0a"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.2.0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "eb7f0f8307f71fac7c606984ea5fb2817275d6e4"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.4"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.0.5+0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
git-tree-sha1 = "9e2f36d3c96a820c678f2f1f1782582fcf685bae"
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"
version = "1.9.1"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "2fb1e02f2b635d0845df5d7c167fec4dd739b00d"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.3"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.Hwloc]]
deps = ["Hwloc_jll", "Statistics"]
git-tree-sha1 = "8338d1bec813d12c4c0d443e3bdf5af564fb37ad"
uuid = "0e44f5e4-bd66-52a0-8798-143a42290a1d"
version = "2.2.0"

[[deps.Hwloc_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "8ecb0b34472a3c98f945e3c75fc7d5428d165511"
uuid = "e33a78d0-f292-5ffc-b300-72abe9b543c8"
version = "2.9.3+0"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "c47c5fa4c5308f27ccaac35504858d8914e102f9"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.4"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "d75853a0bdbfb1ac815478bacd89cd27b550ace6"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.3"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "7e5d6779a1e09a36db2a7b6cff50942a0a7d0fca"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.5.0"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.3"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "7.84.0+0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.10.2+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MIMEs]]
git-tree-sha1 = "65f28ad4b594aebe22157d6fac869786a255b7eb"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "0.1.4"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.10.11"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.21+4"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "716e24b21538abc91f6205fd1d8363f39b442851"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.7.2"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.9.2"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "e47cd150dbe0443c3a3651bc5b9cbd5576ab75b7"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.52"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "03b4c25b43cb84cee5c90aa9b5ea0a78fd848d2f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.0"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "00805cd429dcb4870060ff49ef443486c262e38e"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.1"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.9.0"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "Pkg", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "5.10.1+6"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.ThreadPinning]]
deps = ["DelimitedFiles", "DocStringExtensions", "Libdl", "LinearAlgebra", "PrecompileTools", "Preferences", "Random"]
git-tree-sha1 = "56d6210a740966d2c0967f6dc7b4bc5137d950d6"
uuid = "811555cd-349b-4f26-b7bc-1f208b848042"
version = "0.7.15"

[[deps.Tricks]]
git-tree-sha1 = "aadb748be58b492045b4f56166b5188aa63ce549"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.7"

[[deps.URIs]]
git-tree-sha1 = "b7a5e99f24892b6824a954199a45e9ffcc1c70f0"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.5.0"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.8.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.48.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+0"
"""

# ╔═╡ Cell order:
# ╟─f0c67b03-aa63-41ab-95c8-82dcbdf86281
# ╟─42e44fc4-1f26-4563-af42-512c7fa50f4e
# ╠═d24dacda-6e90-11ee-0e3f-336c6608daab
# ╠═d90da326-c61b-4198-9880-2e93a5b4ac90
# ╠═903ccef4-950a-49e2-b873-2139fdcfe68a
# ╠═bcdc4654-8ba2-4907-a92c-3305861dedb8
# ╠═4811b76d-5461-4f07-b26e-8be8e4c4dcf4
# ╠═15a7671b-5af8-49b6-98d3-95b3635f1a03
# ╠═722e6911-b447-4774-9188-cbe19421ad1b
# ╠═604fceb5-bd32-484e-8854-416b2f7cb210
# ╠═1c77e3fc-457a-49e8-84fd-54915a0a9c58
# ╠═4f67afe8-be94-4396-9340-a7de0329d89e
# ╠═f5fa68e4-7c21-4b25-8b63-f3dd0751f795
# ╟─15f14a5f-ad95-45fa-8dac-cd9e8f613a84
# ╟─b47bb35f-18f1-4e92-8e76-b35a13523abd
# ╠═38f6bf5d-9055-43e9-9336-bcae2c9d5aa8
# ╠═5ce1082c-b600-4cd0-b6b5-d676d16d5c69
# ╠═f2c194d1-8e06-495a-a78b-1b09821a189c
# ╠═4c6e23c9-2dc5-41ae-a122-515ad37e57a1
# ╠═a2e7b46d-6ae2-4d50-bdbd-accc0d4ad542
# ╠═fc409a14-46a6-4790-84b0-0b071bde2bd9
# ╠═9f288f86-d868-4509-83c0-66479cdebc86
# ╟─33c85b14-785c-4516-ba8d-4febc4da123b
# ╟─55fc7718-3d85-4f27-b2d4-5b7dd9851119
# ╟─4c46365c-d951-44c0-841b-766744cf062e
# ╟─289be8f1-ac6c-49e6-a432-3dd884d04162
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
