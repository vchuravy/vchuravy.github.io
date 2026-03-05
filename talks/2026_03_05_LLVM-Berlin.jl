### A Pluto.jl notebook ###
# v0.20.23

#> [frontmatter]
#> title = "A random walk through Julia's compiler"
#> date = "2026-03-05"
#> license = "MIT"
#> description = "LLVM user meeting Berlin"
#> 
#>     [[frontmatter.author]]
#>     name = "Valentin Churavy"
#>     url = "https://vchuravy.dev"

using Markdown
using InteractiveUtils

# ╔═╡ f8f45c14-163e-11f1-15f3-a3fb91cabf98
begin
	using PlutoUI
	using PlutoTeachingTools
	using ShortCodes
end

# ╔═╡ cfa47d1b-33b6-452d-9faf-ecb522c08a65
using JuliaSyntax

# ╔═╡ e2b378f6-7738-4ad7-9d3b-a6bc786d803d
using IRViz

# ╔═╡ b15a2ba0-498d-4dec-a556-a4d147bc8ebe
begin 
	using LLVM
	using LLVM.Interop
end

# ╔═╡ 66c19ed7-dbfd-4475-a0cb-73c41122e713
using Enzyme

# ╔═╡ 5d04d08a-6cd4-4247-bc1a-04a2b568bbc3
html"<button onclick='present()'>Toggle presentation mode</button>"

# ╔═╡ 8f41ec72-b8f7-4a9a-89d7-553087f1438e
PlutoUI.TableOfContents(; depth=4)

# ╔═╡ 392bf0a6-d794-482e-a396-7c7e67cefd29
html"""
<h1> A random walk through Julia's compiler </h1>

<div style="text-align: center;">
March 5th 2026 <br>
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

# ╔═╡ e89d3434-f004-4bb2-91ce-82a1ce1f17ec
md"""
## What's Julia? 🟢 🟣 🔴

Julia is a modern, dynamic, general-purpose, compiled programming language.
It's interactive ("like Python"), can be used in a REPL or notebooks, like Jupyter (it's the "Ju") or Pluto (this one🎈).
Julia has a runtime which includes a just-in-time (JIT) compiler and a garbage collector (GC), for automatic memory management.

Julia is mainly used for technical computing, and addresses a gap in the programming language landscape for numerical computing.


Main paradigm of Julia is multiple dispatch, what functions do depend on type and number of _all_ arguments.
"""

# ╔═╡ 52498869-1e35-4ade-bff0-22da8285cd4d
md"""
!!! note "Why Julia"
    A high-level dynamical programming language build for technical computing (think scientists and engineers).
"""

# ╔═╡ 20cef0cd-434a-406c-82ad-4a1636a1ac31
md"""
### Mixing high-level and low-level code for scientific programming
"""

# ╔═╡ da0c3b13-67f5-4f3e-8560-52cb4905ac92
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

# ╔═╡ 3f077865-1cf3-4f77-a350-7d8073032be9
md"""
!!! note "Compilation"
	Julia is a high-level dynamic programming language that use JIT compilation with LLVM as a primary execution strategy
"""

# ╔═╡ 9d4e03d0-1c8c-4980-a5e3-14d7ec3cfe18
md"""
Isn't dynamic and compiled and oxymoron?
""" |> question_box

# ╔═╡ 650f98c2-b600-4616-9b47-08863b73c3a7
md"""
### Interpretation vs Compilation
"""

# ╔═╡ c09a5ab6-9928-477c-8bed-856dcb44634a
md"""
Is Python interpreted
""" |> question_box

# ╔═╡ 4e3ab5f5-cd29-49c8-ad29-7fe36b05a6f6
   let
	    content = md"""!!! answer
	Compiled to Bytecode: then interpreted (and there are full Python compiler)
    """
	    HTML("<details>$(html(content))</details>")
    end

# ╔═╡ 01db0eb8-4912-4c6a-8a42-5769b08760ff
md"""
Is C compiled?
""" |> question_box

# ╔═╡ ae80d474-d64e-47d9-af14-eedaf861c36e
    let
	    content = md"""
!!! answer
	Yes, but there are also C interpreters such as Cling.
"""
	    HTML("<details>$(html(content))</details>")
    end

# ╔═╡ 125b15b0-52ad-48a1-bec5-8f335debbccb
md"""
!!! note
    **Interpretation** vs **Compilation** is an implementation choice not part of the language **semantics**.
"""

# ╔═╡ b42252af-f2ca-4777-850a-d58729b5ff5b
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

# ╔═╡ 7491f903-8b1d-46fc-a209-ddb8b72f1e6e
md"""
## Challenges in compiling Julia
"""

# ╔═╡ 2c22c47f-fec0-497c-82f6-c3e3191b9234
md"""
1. Multiple-dispatch can lead to a cartesian explosion of methods to compile
2. Julia is a LISP, and uses metaprogramming, the set of functions and methods is only known by running code ("define-by-run").
3. Caching... Caching... Caching...
"""

# ╔═╡ 9dc0f447-9b71-4507-9cc2-36bd5a872a7f
md"""
## Julia's compilation pipeline
"""

# ╔═╡ 5413f7e7-60bb-4ab1-92ca-1a8618c392d2
md"""
1. Parsing
2. Lowering & Linearization
3. Abstract interpretation based type-inference
4. High-level optimizations
5. Codegen to LLVM IR
6. LLVM middle-end
7. LLVM backend
8. Native code
"""

# ╔═╡ b0713138-4769-45d9-a02e-5f35dfd536fb
md"""
!!! warning "Compilation strategy"
    Julia compiles a "function dispatch" at a time. When you use `f(a, b)` it looks at the types of `a` and `b`, and selects the most applicable (dispatch) method of the function `f` (multiple-dispatch/multi-functions). 

     From there it runs "type-inference" and infers the call-graph reachable from `f`. It then performs high-level optimization over the "local" call-graph, and the compiles a method at a time (for better caching) with LLVM.
"""

# ╔═╡ 7071ccce-f164-4e9f-a344-433da4f5ced1
func = """
function example(X)
	acc = zero(eltype(X))
	for x in X
		acc += x
	end
	return acc
end
""";

# ╔═╡ 639fbab4-e36f-4b72-a2df-dea7cd308abf
md"""
## Parsing
"""

# ╔═╡ 6af145a0-f177-414a-8c9b-02072fcedbf0
md"""
!!! note
    Parsing turns **text** into expressions.
"""

# ╔═╡ f6967501-a754-4764-b919-a42be2d86a85
expr = Meta.parse(func)

# ╔═╡ 4afd3ffe-2196-4385-bea7-546b19852429
dump(expr)

# ╔═╡ 9869ff9c-74b4-408d-99ba-a5b687986256
 parsestmt(SyntaxNode, func)

# ╔═╡ 773f27f4-4dcf-412d-a273-24b15678addb
parsestmt(Expr, func)

# ╔═╡ e826cf1e-4acf-4fa9-b0a9-b321b63601cd
md"""
!!! note
    To go from **Expr** to usable function we need to resolve symbols in a namespace and add the function to the system. `eval` will do that for us.
"""

# ╔═╡ a3bf7e5d-3dc0-4bf5-8fa9-586e75eb90c3
example = eval(expr)

# ╔═╡ 1e45cec9-83cc-491d-a10c-96f4392a3836
example(ones(10))

# ╔═╡ 27777746-1ae6-479c-8589-8adb1db62abc
md"""
## Lowering & Linearization
"""

# ╔═╡ f21e2205-f4ba-4f70-9dd3-59921a4901ad
CL = code_lowered(example, (Array{Float64},)) |> only

# ╔═╡ 41b59e90-72be-4eba-8705-772e6ea10e12
md"""
!!! note
    Lowered code is in single-static-assignment (SSA) form with memory.
    `%8  = %7 === nothing` is a SSA statement, and `@_3` are variables (e.g. memory).
"""

# ╔═╡ b25ba9d0-e35c-4b05-bb78-a9f30a596426
md"""
!!! note
    The lowered code forms a control-flow-graph CFG, with a set of basic blocks.
"""

# ╔═╡ 26955e53-7399-4b6e-b5ab-30d56c7b0edf
viz(CL)

# ╔═╡ bb895ca5-c71e-4146-8075-3fc09bf662c6
md"""
!!! note 
    Control-flow is implemented using `goto %n` and `goto %n if not %c` statements.
    Julia's IR uses implicit fallthrough, so a basic-block ending in a `goto %n if not %c` statement has a second implicit successor in the subsequent basic block.
"""

# ╔═╡ 970982ec-9455-41a9-ad38-ab06bb42385c
md"""
!!! note
    All this is nice and so-far fairly standard. It explains how one would implement `macro`s (`Expr` $\to$ `Expr` function), but not how I would compile Julia to efficient code.
"""

# ╔═╡ 305b5965-e15f-4233-87f8-61d59aa59a9a
md"""
### So how do we make dynamic programs run fast: 

**Julia: Avoiding runtime uncertainty**
- Sophisticated type system
- Type inference
- Multiple dispatch
- Specialization
- JIT compilation


> Julia: Dynamism and Performance Reconciled by Design (doi:10.1145/3276490)
"""

# ╔═╡ d22e035e-ddaa-4265-80b4-7ceae6a53a12
md"""
### Type inference

In Julia, type inference is the process of propagating type information from arguments. This utilizes **Abstract Interpretation** as a technique.

- Iteration until fixed-point is reach / Convergence
- Types form a lattice:
  - Bottom: `Union{}`
  - Top: `Any`
- Imprecise answers are permisible: E.g. `Any` is always correct
- Care must be taken for *recursive* functions and *loops*
- Requires heuristics to prevent it from running forever

!!! note
    Type inference allows us to aggressivly de-virtualize calls.
"""

# ╔═╡ be24c760-7d3a-4f01-9c10-278b5c9f33ac
function mysum(X)
	acc = 0
    for x in X
       acc += x
    end
    return acc
end

# ╔═╡ c4310a9b-4c38-4a8b-a86f-bfc464234e2a
md"""
The analysis for `mysum` begins with a specific signature type.

`Tuple{::typeof(mysum), Vector{Float64}}`

```julia
function mysum(X::Vector{Float64})
	acc = 0
    for x in X
       acc += x
    end
    return acc
end
```
"""

# ╔═╡ 550a1eba-8323-4896-a6df-3208b1a543c0

md"""
Examining line 1 we can state that `acc::Int64` due to it being set to a constant.

```julia
function mysum(X::Vector{Float64}) 
	acc = 0::Int # State: {X::Vector{Float64}, acc::Int}
    for x in X
       acc += x
    end
    return acc
end
```
"""

# ╔═╡ 92f81953-5bf9-4212-b63e-07712a5800bd
md"""
Let's for the moment assume that we can deduce `x in X` to imply that `x::Float64`

```julia
function mysum(X::Vector{Float64}) 
	acc = 0::Int
    for x::Float64 in X # State: {X::Vector{Float64}, acc::Int, x::Float64}
       acc += x
    end
    return acc
end
```
"""

# ╔═╡ 780e6e46-6632-485e-9b51-a2e2cb8e88fc
md"""
`acc += x` is syntax sugar for `acc = acc + x`

Julia has a user-extendable promotion scheme for arithmetic ops:

`Base.promote_op(+, Int64, Float64) =` $(Base.promote_op(+, Int64, Float64))

```julia
function mysum(X::Vector{Float64}) 
	acc = 0::Int # State: {X::Vector{Float64}, acc::Int}
    for x::Float64 in X
       acc::Float64 = acc::Int + x::Float64
       # State: {X::Vector{Float64}, acc::Float64, x::Float64}
    end
    return acc
end
```

"""

# ╔═╡ fe9e97c7-0642-44ac-8001-371c5c6632da
md"""
If `length(X) == 0` the for-loop might never be executed. So after the loop we have to unify the abstract interpretation state before the loop with after the loop iteration.

- State Before: `{X::Vector{Float64}, acc::Int64}`
- State After: `{X::Vector{Float64}, acc::Float64}`
- Unification: `{X::Vector{Float64}, acc::Union{Int64, Float64}}`

We haven't yet reached a fix-point. So we re-enter the loop with our new state.

```julia
function mysum(X::Vector{Float64}) 
	acc = 0::Int
    for x::Float64 in X # {X::Vector{...}, acc::Union{Int64, Float64}, x::Float64}
       acc::Union{Float64} = acc::Union{Int64, Float64} + x::Float64
	   # State: {X::Vector{Float64}, acc::Float64, x::Float64}
    end
    return acc
end
```

"""

# ╔═╡ 6cb580aa-1053-4c80-bce1-52bc569f1802
md"""
- State Before: `{X::Vector{Float64}, acc::Union{Int64, Float64}}`
- State After: `{X::Vector{Float64}, acc::Float64}`
- Unification: `{X::Vector{Float64}, acc::Union{Int64, Float64}}`

Fixed point is reached and we can conclude that after the loop `acc::Union{Int64, Float64}` and thus `mysum(X::Vector{Float64})::Union{Int, Float64}`

We can use Julia's introspection tools to automatically query the system:

- `@code_lowered`
- `@code_typed optimize=false`
"""

# ╔═╡ fe3eaded-bcc9-4c24-a660-8dedf4a4ecf9
@code_lowered mysum(rand(3))

# ╔═╡ 1e61ba85-7619-4ded-8512-5ae1b88ef0ec
@code_typed optimize=false mysum(rand(3))

# ╔═╡ d0abc769-38ac-4ba1-b5e7-55952daac63b
md"""
### What information did we use?

Julia has `eval`. So what happens if someone changes the definition of say `+` while the code is running?

Julia uses the so called "world-age" system to track the validity of method definitions and method compilations.
"""

# ╔═╡ f61ffd4a-a612-448c-a60b-1d8fc9352e35
TwoColumn(md"""
Julia 0.3
```julia-repl
julia> f() =  1
julia> g() = f()
julia> g()
1

julia> f() = 2
julia> g()
1

```
""", md"""
Julia 1.0
```julia-repl
julia> f() =  1
julia> g() = f()
julia> g()
1

julia> f() = 2
julia> g()
2
```
""")

# ╔═╡ 7ea481a3-d86f-43e8-9773-0a0f4bdf9646
md"""

> World age in Julia: optimizing method dispatch in the presence of eval (doi:10.1145/3428275)

"""

# ╔═╡ 74d99c11-0605-4de4-b1f4-dc3bc5628d9a
md"""
## Optimizations

- Optimizations are unobservable program transformations
  - Except when they fail

Julia (as many other modern programming languages) uses a multi-stage optimization pipeline.

High-level optimizations:
- Constant propagation
  - Concrete evaluation
- Effect analysis
- Inlining
- Dead code elimination (DCE)
- Scalar replacement of aggregates (SROA)
- (Future) Interprocedural Escape Analyis
- (Future) Alias analysis
- (Future) Loop based optimizations such as loop invariant code motion (LICM)

!!! note
    These optimizations are implemented in Julia, inside the Julia compiler itself, while we still have whole-subprogram visibility.
"""

# ╔═╡ 9a29918f-af90-47d7-a446-0d5d9266e32c
code_typed() do
	sin(3.0) + 4.0
end |> only

# ╔═╡ 4064ccce-ae7e-4beb-b285-0ea5b8dd34d7
md"""
!!! note
    Julia performs constant propagation/concrete evaluation on the level of type-inference. 
    Having an "interpreter" in you compiler is really powerful.
"""

# ╔═╡ 53b768ca-c7b1-4e17-8dfd-b8050ba99721
md"""
### Inlining
"""

# ╔═╡ 35b6654b-205a-4f2b-996c-a10ea2225734
begin
	IR, rt = only(Base.code_ircode(mysum, (Vector{Float64},), optimize_until="compact 1"))
	IR
end

# ╔═╡ 079f6093-fa0c-43e0-87e7-48df8ff221b5
Core.Compiler.ssa_inlining_pass!(
	Core.Compiler.copy(IR),
	Core.Compiler.InliningState(Core.Compiler.NativeInterpreter()), false)

# ╔═╡ 5a31774e-3748-46ad-921d-1b14f81bdc31
md"""
Or simply
"""

# ╔═╡ da269326-5d9d-44e1-b261-598c5aa6f5ba
@code_typed mysum(rand(4))

# ╔═╡ decb653a-9810-4ed5-aa34-5cf7a21e7f11
md"""
!!! note
    Inlining occurs in the high-level optimizer and not in LLVM. In most cases LLVM only get's to see single method compilations
"""

# ╔═╡ a6ad35fd-eb88-4dc6-84b3-75e77e71eb99
md"""
## LLVM based code generation

- LLVM is a widely used compiler framework
- Common set of "middle-end" optimizations based on LLVM IR
- Specific backend optimizations
- Frontends like Julia generate LLVM intermediate representation (IR)
"""

# ╔═╡ c7589717-dfbd-410a-a15b-46e9c4cd1f86
with_terminal() do
	@code_llvm optimize=false debuginfo=:none mysum(rand(30))
end

# ╔═╡ 8f2c9c96-333a-4a56-b78f-7b57503aa95e
md"""
Optimizations include:
- Simplifications (Control flow graph (CFG) / Instructions)
- Julia specific passes
  - allocation optimizations (ellision / heap to stack / ...)
- Loop optimization
  - LICM
  - Vectorization
  - Unrolling/Peeling
  - Loop Unswitch

We also perform **legalization**. Turning the LLVM full or Julia specific concepts into a legal representation.

!!! note
    Each successive lowering simplifies the program and throws information away.
    This opens the question: When to perform what optimization.

"""

# ╔═╡ 87a7d0b4-7a7b-4713-91ad-28347ccf2e9a
md"""
## Interpretation vs JIT vs JAOT vs AOT

There are many flavours of executing programs.
- Interpreters
  - Byte code interpreters
- Compilation
  - Ahead of Time (AOT)
  - Just in Time (JIT)
    - Tracing JIT
  - Just Ahead of Time (JAOT) / Just in the nick of Time

JIT compilers are commonly used for Java or JavaScript, they are often tiered and responsive.

As an example Java may compile your program first with the `C1` compiler tuned for latency, then later if it detects your function has executed many times it will use the `C2` compiler. In JavaScript it will assome the most common type and de-optimize upon uncommon types.
"""

# ╔═╡ c442e8a7-9076-40c1-83f3-84d7a4ca00c3
md"""
Currently Julia compiles every function before it's first execution.

!!! note
    This initial latency or time-to-first-X, is why sometimes folks say:
    "Julia is fast the second time"

Over the years more and more attention has been payed on amortizing this compilation cost by performing caching. Native code caching for Julia 1.9 had a drastic impact on how "snappy" the language feels.
"""

# ╔═╡ f0c57ad2-8778-4316-bc7d-680296967d07
YouTube("jFhL8EVrz7s", 10, 5)

# ╔═╡ b9de447e-e3df-4ce3-a9cd-2ef43a0407e4
md"""
## How to make it correct?

In order to execute dynamic programs fast we need to obtain information/make assumptions. It is crucial that the information remains correct.

!!! info
    The language semantics are dynamic, optimizations and static analysis doesn't change that.

So we need to track the validity of the information. Python compilers and other JITs often use **guard checks** whereas Julia thanks to final concrete types can use **world-ages** to convert open-world semantics to closed-world semantics.

Julia also uses edges to limit the invalidation effect. Methods and compile results have a pair of world-ages (first-valid and last-valid).

!!! important
    On disk caches must be carefully validated as well.
"""

# ╔═╡ dd92da88-f953-458f-9cd9-7e2ae727dcf1
md"""
## Figuring out what is happening
The stages of the compiler

- `@code_lowered`
- `@code_typed` & `@code_warntype`
- `@code_llvm`
- `@code_native`

Where is a function defined `@which` & `@edit`

!!! note
    Compiler explorer in your REPL.
"""

# ╔═╡ 6f7f3602-934d-4919-aa30-c75b53eff1d1
md"""
## Directly working with LLVM

!!! note
    Julia uses the LLVM C-API to provide functionality like compiling Julia to GPUs.
"""

# ╔═╡ aaca3a86-f0ff-4596-9915-501e890b3312
@dispose ctx=Context() begin
    param_types = [LLVM.Int32Type(), LLVM.Int32Type()]
    ret_type = LLVM.Int32Type()
    sum, _ = create_function(ret_type, param_types)

    # generate IR
    @dispose builder=IRBuilder() begin
        entry = BasicBlock(sum, "entry")
        position!(builder, entry)

        tmp = add!(builder, parameters(sum)[1], parameters(sum)[2], "tmp")
        ret!(builder, tmp)
    end

    # make Julia compile and execute the function
    push!(function_attributes(sum), EnumAttribute("alwaysinline"))
    @eval call_sum(x, y) = $(call_function(sum, Int32, Tuple{Int32, Int32}, :x, :y))
end

# ╔═╡ 21c21476-3189-40cd-a744-4bb3b253b812
call_sum(Int32(1), Int32(2))

# ╔═╡ 80882caa-59c6-4518-8c44-958b90e5f13a
with_terminal() do
	@code_llvm call_sum(Int32(1), Int32(2))
end

# ╔═╡ a26bb276-1676-4322-9a2f-3f8663790f14
md"""
### Writing an LLVM pass in Julia
"""

# ╔═╡ ec2fcc61-e589-4750-b704-a35c615d9bba
function example_module_pass!(mod)
	changed = false

	for f in functions(mod)
		@show f
	end
	
	return changed
end

# ╔═╡ 6d35c70e-c918-484e-b20e-b79b6d8ac444
ExampleModulePass() = NewPMModulePass("example_module_pass", example_module_pass!);

# ╔═╡ a8d5aa57-9567-44f3-a62c-c7ddefd2cbd7
ll = """
define i32 @julia_call_sum_21819(i32 signext %"x::Int32", i32 signext %"y::Int32") {
top:
   %tmp.i = add i32 %"y::Int32", %"x::Int32"
   ret i32 %tmp.i
}
""";

# ╔═╡ 9346a034-6703-41fb-95a0-266461dd613b
@dispose ctx=Context() begin
	mod = LLVM.parse(LLVM.Module, ll)

	@dispose pb = LLVM.NewPMPassBuilder() begin
		register!(pb, ExampleModulePass())
		add!(pb, ExampleModulePass())
		
		LLVM.run!(pb, mod)
	end
	
    nothing
end

# ╔═╡ b995cf6b-3034-4f64-97fc-8665236efdd2
md"""
## Getting information out of the darn compiler
"""

# ╔═╡ 0d9bc6fb-05e0-4285-abfd-76ded3ef6120
md"""
!!! note
    We already saw some high-level reflection methods, but those are trying to be "useful" by default.
"""

# ╔═╡ 04b57b59-a17f-4b47-855b-726dfb6e1ad9
with_terminal() do
	@code_llvm +(1, 1)
end

# ╔═╡ 98a7b21d-3305-4f53-bb3a-4b3315cbc251
md"""
!!! note
    Before optimizations!
"""

# ╔═╡ 23718e8c-432c-4dda-b1a8-1d03526de6a7
with_terminal() do
	@code_llvm optimize=false +(1, 1)
end

# ╔═╡ f9d3a2b3-5d66-4387-a878-efad66f57cc0
md"""
!!! note
    Where is my module!
"""

# ╔═╡ dd1968c0-56d4-40bd-a4a0-1c5a16669503
with_terminal() do
	@code_llvm dump_module=true +(1, 1)
end

# ╔═╡ 69e07dc3-90e9-4cf0-9170-c793a2eeba9b
md"""
!!! note
    But where is my metadata!?
"""

# ╔═╡ dede4283-ef1f-406a-8512-fa2052e60332
with_terminal() do
	@code_llvm dump_module=true raw=true +(1, 1)
end

# ╔═╡ b7bcbae8-3cee-48e2-80bf-5ee240af8eea
md"""
## Retargeting to GPUs & Synthesizing gradients
"""

# ╔═╡ b7febfcc-1eff-4d53-96fb-26338c6586c9
md"""
!!! note
    In my abstract I promised to talk about how Julia targets GPUs and how we are synthesizing gradients... That is sadly another hour of a talk.
"""

# ╔═╡ 13a78c25-0f71-4d62-ae2c-dd07fa379912
md"""
!!! warning "GPUs"
	[GPUCompiler.jl](https://github.com/JuliaGPU/GPUCompiler.jl): Takes native Julia code and compiles it directly to GPUs

    [https://vchuravy.dev/talks/2025\_02\_24-EVERSE/](https://vchuravy.dev/talks/2025_02_24-EVERSE/)
"""

# ╔═╡ 7f312c35-f3a4-49f0-9a6b-cbc94a6ed056
g(x) = log(x^2 + exp(sin(x)))

# ╔═╡ 89dd61ea-00cb-4ceb-b379-0b081dfa6969
with_terminal() do
	@code_llvm debuginfo=:none g(2.0)
end

# ╔═╡ 9d60c913-5dea-4156-a5e2-9347205f1869
with_terminal() do
	Enzyme.Compiler.enzyme_code_llvm(
		g, Duplicated, Tuple{Duplicated{Float64}},
		mode=Enzyme.API.DEM_ForwardMode,
		debuginfo=:none
	)
end

# ╔═╡ 87edec2c-447d-4e9d-a200-2a82528f7e54
md"""
!!! warning "More about Enzyme"
    [https://vchuravy.dev/talks/2025\_11\_13-NPS/](https://vchuravy.dev/talks/2025_11_13-NPS/)
"""

# ╔═╡ e48e423f-4ba0-4492-82c1-032e5836571a
md"""
## So why bother?

- The usability improvement of dynamic programming language is not to undervalue
  - Python, JavaScript and co are very popular for accessibility reasons
- Dynamic Programming Languages often have a higher level of abstractions
  - When I work on hard science, I don't want to worry about memory lifetimes
- Dynamic programming languages can be fast
  - The presenence of a JIT allows for value specializationn
  - We can start dynamic and regain information at call-boundaries

!!! note
    Julia is a fast, high-level dynamic programming language.
    It's not magic, but rather clever language design.

!!! warning "Collaboration"
    If this talk resonates and you are curious, I have lots of ideas and little time for how to make LLVM and Julia work better together.
    - OrcJIT and WASM?
    - Actually useful remarks for heavily inlined code
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
Enzyme = "7da242da-08ed-463a-9acd-ee780be4f1d9"
IRViz = "fe03f759-463e-4126-a68f-1df7fb7a8375"
JuliaSyntax = "70703baa-626e-46a2-a12c-08ffd08c73b4"
LLVM = "929cbde3-209d-540e-8aea-75f648917ca0"
PlutoTeachingTools = "661c6b06-c737-4d37-b85c-46df65de6f69"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
ShortCodes = "f62ebe17-55c5-4640-972f-b59c0dd11ccf"

[compat]
Enzyme = "~0.13.129"
IRViz = "~1.0.0"
JuliaSyntax = "~1.0.2"
LLVM = "~9.4.6"
PlutoTeachingTools = "~0.4.7"
PlutoUI = "~0.7.79"
ShortCodes = "~0.3.6"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.11.9"
manifest_format = "2.0"
project_hash = "aa740f364a59749a47dac522c52459765c56edfd"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "6e1d2a35f2f90a4bc7c2ed98079b2ba09c35b83a"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.3.2"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.BitFlags]]
git-tree-sha1 = "0691e34b3bb8be9307330f88d1a3c3f25466c24d"
uuid = "d1d4a3ce-64b1-5f1a-9ba4-7e7e69966f35"
version = "0.1.9"

[[deps.CEnum]]
git-tree-sha1 = "389ad5c84de1ae7cf0e28e381131c98ea87d54fc"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.5.0"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "962834c22b66e32aa10f7611c08c8ca4e20749a9"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.8"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "67e11ee83a43eb71ddc950302c53bf33f0690dfe"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.12.1"

    [deps.ColorTypes.extensions]
    StyledStringsExt = "StyledStrings"

    [deps.ColorTypes.weakdeps]
    StyledStrings = "f489334b-da3d-4c2e-b8f0-e476e12c162b"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.1.1+0"

[[deps.ConcurrentUtilities]]
deps = ["Serialization", "Sockets"]
git-tree-sha1 = "21d088c496ea22914fe80906eb5bce65755e5ec8"
uuid = "f0e56b4a-5159-44fe-b623-3e5288b988bb"
version = "2.5.1"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"
version = "1.11.0"

[[deps.DocStringExtensions]]
git-tree-sha1 = "7442a5dfe1ebb773c29cc2962a8980f47221d76c"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.5"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.Enzyme]]
deps = ["CEnum", "EnzymeCore", "Enzyme_jll", "GPUCompiler", "InteractiveUtils", "LLVM", "Libdl", "LinearAlgebra", "ObjectFile", "PrecompileTools", "Preferences", "Printf", "Random", "SparseArrays"]
git-tree-sha1 = "ea65d3121f09b5f31102542db9445163b7c99182"
uuid = "7da242da-08ed-463a-9acd-ee780be4f1d9"
version = "0.13.129"

    [deps.Enzyme.extensions]
    EnzymeBFloat16sExt = "BFloat16s"
    EnzymeChainRulesCoreExt = "ChainRulesCore"
    EnzymeGPUArraysCoreExt = "GPUArraysCore"
    EnzymeLogExpFunctionsExt = "LogExpFunctions"
    EnzymeSpecialFunctionsExt = "SpecialFunctions"
    EnzymeStaticArraysExt = "StaticArrays"

    [deps.Enzyme.weakdeps]
    ADTypes = "47edcb42-4c32-4615-8424-f2b9edc5f35b"
    BFloat16s = "ab4f0b2a-ad5b-11e8-123f-65d77653426b"
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
    LogExpFunctions = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
    SpecialFunctions = "276daf66-3868-5448-9aa4-cd146d93841b"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.EnzymeCore]]
git-tree-sha1 = "990991b8aa76d17693a98e3a915ac7aa49f08d1a"
uuid = "f151be2c-9106-41f4-ab19-57ee4f262869"
version = "0.8.18"

    [deps.EnzymeCore.extensions]
    AdaptExt = "Adapt"
    EnzymeCoreChainRulesCoreExt = "ChainRulesCore"

    [deps.EnzymeCore.weakdeps]
    Adapt = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"

[[deps.Enzyme_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl", "TOML"]
git-tree-sha1 = "fea21cfc452db42e3878aab62a76896e76d54d12"
uuid = "7cc45869-7501-5eee-bdea-0790c847d4ef"
version = "0.0.249+0"

[[deps.ExceptionUnwrapping]]
deps = ["Test"]
git-tree-sha1 = "d36f682e590a83d63d1c7dbd287573764682d12a"
uuid = "460bff9d-24e4-43bc-9d9f-a8973cb893f4"
version = "0.1.11"

[[deps.ExprTools]]
git-tree-sha1 = "27415f162e6028e81c72b82ef756bf321213b6ec"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.10"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"
version = "1.11.0"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "05882d6995ae5c12bb5f36dd2ed3f61c98cbb172"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.5"

[[deps.Format]]
git-tree-sha1 = "9c68794ef81b08086aeb32eeaf33531668d5f5fc"
uuid = "1fa38f19-a742-5d3f-a2b9-30dd87b9d5f8"
version = "1.3.7"

[[deps.GPUCompiler]]
deps = ["ExprTools", "InteractiveUtils", "LLVM", "Libdl", "Logging", "PrecompileTools", "Preferences", "Scratch", "Serialization", "TOML", "Tracy", "UUIDs"]
git-tree-sha1 = "966946d226e8b676ca6409454718accb18c34c54"
uuid = "61eb1bfa-7361-4325-ad38-22787b887f55"
version = "1.8.2"

[[deps.Ghostscript_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Zlib_jll"]
git-tree-sha1 = "38044a04637976140074d0b0621c1edf0eb531fd"
uuid = "61579ee1-b43e-5ca0-a5da-69d92c66a64b"
version = "9.55.1+0"

[[deps.HTTP]]
deps = ["Base64", "CodecZlib", "ConcurrentUtilities", "Dates", "ExceptionUnwrapping", "Logging", "LoggingExtras", "MbedTLS", "NetworkOptions", "OpenSSL", "PrecompileTools", "Random", "SimpleBufferStream", "Sockets", "URIs", "UUIDs"]
git-tree-sha1 = "5e6fe50ae7f23d171f44e311c2960294aaa0beb5"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "1.10.19"

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

[[deps.IRViz]]
deps = ["Kroki"]
git-tree-sha1 = "fb9307c3ebe6b9e39df4cc26b7218d4ee4f0961d"
uuid = "fe03f759-463e-4126-a68f-1df7fb7a8375"
version = "1.0.0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

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

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "b6893345fd6658c8e475d40155789f4860ac3b21"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.1.4+0"

[[deps.JuliaSyntax]]
git-tree-sha1 = "0d4b3dab95018bcf3925204475693d9f09dc45b8"
uuid = "70703baa-626e-46a2-a12c-08ffd08c73b4"
version = "1.0.2"

[[deps.Kroki]]
deps = ["Base64", "CodecZlib", "DocStringExtensions", "HTTP", "JSON", "Markdown", "Reexport"]
git-tree-sha1 = "a3235f9ff60923658084df500cdbc0442ced3274"
uuid = "b3565e16-c1f2-4fe9-b4ab-221c88942068"
version = "0.2.0"

[[deps.LLVM]]
deps = ["CEnum", "LLVMExtra_jll", "Libdl", "Preferences", "Printf", "Unicode"]
git-tree-sha1 = "69e4739502b7ab5176117e97e1664ed181c35036"
uuid = "929cbde3-209d-540e-8aea-75f648917ca0"
version = "9.4.6"

    [deps.LLVM.extensions]
    BFloat16sExt = "BFloat16s"

    [deps.LLVM.weakdeps]
    BFloat16s = "ab4f0b2a-ad5b-11e8-123f-65d77653426b"

[[deps.LLVMExtra_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl", "TOML"]
git-tree-sha1 = "8e76807afb59ebb833e9b131ebf1a8c006510f33"
uuid = "dad2f222-ce93-54a1-a47d-0025e8a3acab"
version = "0.0.38+0"

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

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"
version = "1.11.0"

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

[[deps.LibTracyClient_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "d4e20500d210247322901841d4eafc7a0c52642d"
uuid = "ad6e5548-8b26-5c9f-8ef3-ef0ad883f3a5"
version = "0.13.1+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"
version = "1.11.0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.11.0"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"
version = "1.11.0"

[[deps.LoggingExtras]]
deps = ["Dates", "Logging"]
git-tree-sha1 = "f00544d95982ea270145636c181ceda21c4e2575"
uuid = "e6f89c97-d47a-5376-807f-9c37f3926c36"
version = "1.2.0"

[[deps.MIMEs]]
git-tree-sha1 = "c64d943587f7187e751162b3b84445bbbd79f691"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "1.1.0"

[[deps.MacroTools]]
git-tree-sha1 = "1e0228a030642014fe5cfe68c2c0a818f9e3f522"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.16"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "MozillaCACerts_jll", "NetworkOptions", "Random", "Sockets"]
git-tree-sha1 = "c067a280ddc25f196b5e7df3877c6b226d390aaf"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.1.9"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.6+0"

[[deps.Memoize]]
deps = ["MacroTools"]
git-tree-sha1 = "2b1dfcba103de714d31c033b5dacc2e4a12c7caa"
uuid = "c03570c3-d221-55d1-a50c-7939bbd78826"
version = "0.4.4"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"
version = "1.11.0"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2023.12.12"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.ObjectFile]]
deps = ["Reexport", "StructIO"]
git-tree-sha1 = "22faba70c22d2f03e60fbc61da99c4ebfc3eb9ba"
uuid = "d8793406-e978-5875-9003-1fc021f44a92"
version = "0.5.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.27+1"

[[deps.OpenSSL]]
deps = ["BitFlags", "Dates", "MozillaCACerts_jll", "NetworkOptions", "OpenSSL_jll", "Sockets"]
git-tree-sha1 = "1d1aaa7d449b58415f97d2839c318b70ffb525a0"
uuid = "4d8831e6-92b7-49fb-bdf8-b643e874388c"
version = "1.6.1"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c9cbeda6aceffc52d8a0017e71db27c7a7c0beaf"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.5.5+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "05868e21324cede2207c6f0f466b4bfef6d5e7ee"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.8.1"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "7d2f8f21da5db6a806faf7b9b292296da42b2810"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.3"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "Random", "SHA", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.11.0"

    [deps.Pkg.extensions]
    REPLExt = "REPL"

    [deps.Pkg.weakdeps]
    REPL = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

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

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "5aa36f7049a63a1528fe8f7c3f2113413ffd4e1f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.1"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "522f093a29b31a93e34eaea17ba055d850edea28"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.5.1"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"
version = "1.11.0"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
version = "1.11.0"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "62389eeff14780bfe55195b7204c0d8738436d64"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.1"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "9b81b8393e50b7d4e6d0a9f14e192294d3b7c109"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.3.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.ShortCodes]]
deps = ["Base64", "CodecZlib", "Downloads", "JSON3", "Memoize", "URIs", "UUIDs"]
git-tree-sha1 = "5844ee60d9fd30a891d48bab77ac9e16791a0a57"
uuid = "f62ebe17-55c5-4640-972f-b59c0dd11ccf"
version = "0.3.6"

[[deps.SimpleBufferStream]]
git-tree-sha1 = "f305871d2f381d21527c770d4788c06c097c9bc1"
uuid = "777ac1f9-54b0-4bf8-805c-2214025038e7"
version = "1.2.0"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"
version = "1.11.0"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.11.0"

[[deps.Statistics]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "ae3bb1eb3bba077cd276bc5cfc337cc65c3075c0"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.1"
weakdeps = ["SparseArrays"]

    [deps.Statistics.extensions]
    SparseArraysExt = ["SparseArrays"]

[[deps.StructIO]]
git-tree-sha1 = "c581be48ae1cbf83e899b14c07a807e1787512cc"
uuid = "53d494c1-5632-5724-8f4c-31dff12d585f"
version = "0.3.1"

[[deps.StructTypes]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "159331b30e94d7b11379037feeb9b690950cace8"
uuid = "856f2bd8-1eba-4b0a-8007-ebc267875bd4"
version = "1.11.0"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.7.0+0"

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
version = "1.11.0"

[[deps.Tracy]]
deps = ["ExprTools", "LibTracyClient_jll", "Libdl"]
git-tree-sha1 = "73e3ff50fd3990874c59fef0f35d10644a1487bc"
uuid = "e689c965-62c8-4b79-b2c5-8359227902fd"
version = "0.1.6"

    [deps.Tracy.extensions]
    TracyProfilerExt = "TracyProfiler_jll"

    [deps.Tracy.weakdeps]
    TracyProfiler_jll = "0c351ed6-8a68-550e-8b79-de6f926da83c"

[[deps.TranscodingStreams]]
git-tree-sha1 = "0c45878dcfdcfa8480052b6ab162cdd138781742"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.11.3"

[[deps.Tricks]]
git-tree-sha1 = "311349fd1c93a31f783f977a71e8b062a57d4101"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.13"

[[deps.URIs]]
git-tree-sha1 = "bef26fb046d031353ef97a82e3fdb6afe7f21b1a"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.6.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"
version = "1.11.0"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"
version = "1.11.0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.11.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.59.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"
"""

# ╔═╡ Cell order:
# ╟─5d04d08a-6cd4-4247-bc1a-04a2b568bbc3
# ╟─8f41ec72-b8f7-4a9a-89d7-553087f1438e
# ╠═f8f45c14-163e-11f1-15f3-a3fb91cabf98
# ╟─392bf0a6-d794-482e-a396-7c7e67cefd29
# ╟─e89d3434-f004-4bb2-91ce-82a1ce1f17ec
# ╟─52498869-1e35-4ade-bff0-22da8285cd4d
# ╟─20cef0cd-434a-406c-82ad-4a1636a1ac31
# ╟─da0c3b13-67f5-4f3e-8560-52cb4905ac92
# ╟─3f077865-1cf3-4f77-a350-7d8073032be9
# ╟─9d4e03d0-1c8c-4980-a5e3-14d7ec3cfe18
# ╟─650f98c2-b600-4616-9b47-08863b73c3a7
# ╟─c09a5ab6-9928-477c-8bed-856dcb44634a
# ╟─4e3ab5f5-cd29-49c8-ad29-7fe36b05a6f6
# ╟─01db0eb8-4912-4c6a-8a42-5769b08760ff
# ╟─ae80d474-d64e-47d9-af14-eedaf861c36e
# ╟─125b15b0-52ad-48a1-bec5-8f335debbccb
# ╟─b42252af-f2ca-4777-850a-d58729b5ff5b
# ╟─7491f903-8b1d-46fc-a209-ddb8b72f1e6e
# ╟─2c22c47f-fec0-497c-82f6-c3e3191b9234
# ╟─9dc0f447-9b71-4507-9cc2-36bd5a872a7f
# ╟─5413f7e7-60bb-4ab1-92ca-1a8618c392d2
# ╟─b0713138-4769-45d9-a02e-5f35dfd536fb
# ╠═7071ccce-f164-4e9f-a344-433da4f5ced1
# ╟─639fbab4-e36f-4b72-a2df-dea7cd308abf
# ╟─6af145a0-f177-414a-8c9b-02072fcedbf0
# ╠═f6967501-a754-4764-b919-a42be2d86a85
# ╠═4afd3ffe-2196-4385-bea7-546b19852429
# ╠═cfa47d1b-33b6-452d-9faf-ecb522c08a65
# ╠═9869ff9c-74b4-408d-99ba-a5b687986256
# ╠═773f27f4-4dcf-412d-a273-24b15678addb
# ╟─e826cf1e-4acf-4fa9-b0a9-b321b63601cd
# ╠═a3bf7e5d-3dc0-4bf5-8fa9-586e75eb90c3
# ╠═1e45cec9-83cc-491d-a10c-96f4392a3836
# ╟─27777746-1ae6-479c-8589-8adb1db62abc
# ╠═f21e2205-f4ba-4f70-9dd3-59921a4901ad
# ╟─41b59e90-72be-4eba-8705-772e6ea10e12
# ╟─b25ba9d0-e35c-4b05-bb78-a9f30a596426
# ╠═e2b378f6-7738-4ad7-9d3b-a6bc786d803d
# ╠═26955e53-7399-4b6e-b5ab-30d56c7b0edf
# ╟─bb895ca5-c71e-4146-8075-3fc09bf662c6
# ╟─970982ec-9455-41a9-ad38-ab06bb42385c
# ╟─305b5965-e15f-4233-87f8-61d59aa59a9a
# ╟─d22e035e-ddaa-4265-80b4-7ceae6a53a12
# ╠═be24c760-7d3a-4f01-9c10-278b5c9f33ac
# ╟─c4310a9b-4c38-4a8b-a86f-bfc464234e2a
# ╟─550a1eba-8323-4896-a6df-3208b1a543c0
# ╟─92f81953-5bf9-4212-b63e-07712a5800bd
# ╟─780e6e46-6632-485e-9b51-a2e2cb8e88fc
# ╟─fe9e97c7-0642-44ac-8001-371c5c6632da
# ╟─6cb580aa-1053-4c80-bce1-52bc569f1802
# ╠═fe3eaded-bcc9-4c24-a660-8dedf4a4ecf9
# ╠═1e61ba85-7619-4ded-8512-5ae1b88ef0ec
# ╟─d0abc769-38ac-4ba1-b5e7-55952daac63b
# ╟─f61ffd4a-a612-448c-a60b-1d8fc9352e35
# ╟─7ea481a3-d86f-43e8-9773-0a0f4bdf9646
# ╟─74d99c11-0605-4de4-b1f4-dc3bc5628d9a
# ╠═9a29918f-af90-47d7-a446-0d5d9266e32c
# ╟─4064ccce-ae7e-4beb-b285-0ea5b8dd34d7
# ╟─53b768ca-c7b1-4e17-8dfd-b8050ba99721
# ╠═35b6654b-205a-4f2b-996c-a10ea2225734
# ╠═079f6093-fa0c-43e0-87e7-48df8ff221b5
# ╟─5a31774e-3748-46ad-921d-1b14f81bdc31
# ╠═da269326-5d9d-44e1-b261-598c5aa6f5ba
# ╟─decb653a-9810-4ed5-aa34-5cf7a21e7f11
# ╟─a6ad35fd-eb88-4dc6-84b3-75e77e71eb99
# ╠═c7589717-dfbd-410a-a15b-46e9c4cd1f86
# ╟─8f2c9c96-333a-4a56-b78f-7b57503aa95e
# ╟─87a7d0b4-7a7b-4713-91ad-28347ccf2e9a
# ╟─c442e8a7-9076-40c1-83f3-84d7a4ca00c3
# ╟─f0c57ad2-8778-4316-bc7d-680296967d07
# ╟─b9de447e-e3df-4ce3-a9cd-2ef43a0407e4
# ╟─dd92da88-f953-458f-9cd9-7e2ae727dcf1
# ╟─6f7f3602-934d-4919-aa30-c75b53eff1d1
# ╠═b15a2ba0-498d-4dec-a556-a4d147bc8ebe
# ╠═aaca3a86-f0ff-4596-9915-501e890b3312
# ╠═21c21476-3189-40cd-a744-4bb3b253b812
# ╠═80882caa-59c6-4518-8c44-958b90e5f13a
# ╟─a26bb276-1676-4322-9a2f-3f8663790f14
# ╠═ec2fcc61-e589-4750-b704-a35c615d9bba
# ╠═6d35c70e-c918-484e-b20e-b79b6d8ac444
# ╠═a8d5aa57-9567-44f3-a62c-c7ddefd2cbd7
# ╠═9346a034-6703-41fb-95a0-266461dd613b
# ╟─b995cf6b-3034-4f64-97fc-8665236efdd2
# ╟─0d9bc6fb-05e0-4285-abfd-76ded3ef6120
# ╠═04b57b59-a17f-4b47-855b-726dfb6e1ad9
# ╟─98a7b21d-3305-4f53-bb3a-4b3315cbc251
# ╠═23718e8c-432c-4dda-b1a8-1d03526de6a7
# ╟─f9d3a2b3-5d66-4387-a878-efad66f57cc0
# ╠═dd1968c0-56d4-40bd-a4a0-1c5a16669503
# ╟─69e07dc3-90e9-4cf0-9170-c793a2eeba9b
# ╠═dede4283-ef1f-406a-8512-fa2052e60332
# ╟─b7bcbae8-3cee-48e2-80bf-5ee240af8eea
# ╟─b7febfcc-1eff-4d53-96fb-26338c6586c9
# ╟─13a78c25-0f71-4d62-ae2c-dd07fa379912
# ╠═66c19ed7-dbfd-4475-a0cb-73c41122e713
# ╠═7f312c35-f3a4-49f0-9a6b-cbc94a6ed056
# ╠═89dd61ea-00cb-4ceb-b379-0b081dfa6969
# ╠═9d60c913-5dea-4156-a5e2-9347205f1869
# ╟─87edec2c-447d-4e9d-a200-2a82528f7e54
# ╟─e48e423f-4ba0-4492-82c1-032e5836571a
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
