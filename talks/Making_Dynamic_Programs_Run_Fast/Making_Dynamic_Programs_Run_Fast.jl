### A Pluto.jl notebook ###
# v0.19.36

#> [frontmatter]
#> title = "Making Dynamic Programs run Fast"
#> date = "2023-12-21"
#> license = "MIT"
#> 
#>     [[frontmatter.author]]
#>     name = "Valentin Churavy"
#>     url = "https://vchuravy.dev"

using Markdown
using InteractiveUtils

# ╔═╡ f1db15d4-9f18-11ee-029a-e51fbd66cfea
begin
	using PlutoUI
	using ShortCodes
	using JET
	using AllocCheck
end

# ╔═╡ 2f03b26e-08e1-4be8-81e3-1d97e9c46e97
html"<button onclick='present()'>Toggle presentation mode</button>"

# ╔═╡ 21735a54-7dd0-4a7a-9368-7495e318e307
PlutoUI.TableOfContents(; depth=4)

# ╔═╡ f38c6e65-e4ab-42df-ba05-d6c057ef350f
html"""
<h1> Making Dynamic Programs Run Fast </h1>

<div style="text-align: center;">
Dec 21nd 2023 <br>
University of Mainz
<br><br>
Valentin Churavy
<br>
JuliaLab, CSAIL, MIT
<br>
@vchuravy
</div>
"""

# ╔═╡ 742144a6-7eff-4172-ad85-064e7a2dd67d
md"""
## Who am I?

- B.Sc in Cognitive Science (University of Osnabrueck 2011-2014)
- Applied ML research (Okinawa Institute of Technology, Japan 2015-2017)
- M.Sc & PhD in Computer Science (Massachussetts Institute of Technology, USA 2017-)

Working on GPU computing in Julia since 2014 -- First Julia version 0.3-dev

PhD student at the MIT JuliaLab working on the Julia compiler and runtime.
My goal is to make HPC and GPU based programming easier and more accessible,
I work with science teams to help them maximise their usage of Julia.
"""

# ╔═╡ 66a9d9d4-37ea-41a9-9c8e-1791fb7e3e6d
md"""
## Why Julia? 😍

$(Resource("https://cdn.hashnode.com/res/hashnode/image/upload/v1681735971356/91b6e886-7ce1-41a3-9d9f-29b7b096e7f2.png"))
$(Resource("https://cdn.hashnode.com/res/hashnode/image/upload/v1681735992315/62fdd58f-4630-4120-8eb4-5238740543e8.png"))

From "[My Target Audience](https://scientificcoder.com/my-target-audience)" by Matthijs Cox:
"""

# ╔═╡ c482bc24-f1d2-46c7-8538-48c90d7e4394
md"""
## What makes a programming language dynamic?

1. Dynamic typing vs static typing
2. Open world vs closed world
3. Dynamic structs vs dynamic
"""

# ╔═╡ 1dd808d9-84d8-4de3-85ea-73febfee62df
md"""
## Dynamic typing vs static typing

The **common** argument: JavaScript vs TypeScript -- reminds one a bit of Vim vs Emacs, or spaces vs tabs.

- [Laurence Tratt: A modest attempt to help prevent unnecessary static dynamic typing debates](https://tratt.net/laurie/blog/2010/a_modest_attempt_to_help_prevent_unnecessary_static_dynamic_typing_debates.html)
- [Laurence Tratt: Dynamically Typed Languages](https://tratt.net/laurie/research/pubs/papers/tratt__dynamically_typed_languages.pdf)

> a dynamically typed language is one that does not check or enforce type-safety at compile-time.

But is there all that is to it?
"""

# ╔═╡ 09939df5-6b00-4d55-9ddb-d87a25264a8e
md"""
## Some terminology

- Types: A type (or in Object-Oriented programming a class) defines a set of values 
```julia
abstract type Fruit end
struct Apples <: Fruit end
abtract type StoneFruit end
struct Peaches <: StoneFruit end
```

- Compile-time: Work done before the user's program
- Run time: Work done during the execution of the program
"""

# ╔═╡ bdf87ca9-ed6c-4d66-9b1c-b9db83453a4d
md"""
## Static typying

In statically typed languages a variable can only be assigned a type once.

Explicitly (Java):
```java
int i = 3;
String s = "4";
int x = i + s;
```

Implicitly (Haskell):

```haskell
let
  i = 3
  s = "4"
in
  i + s
```

!!! note
    This allows us to perform type-checking before executing a program.
    Type errors occur at compile-time.
"""

# ╔═╡ f3d799cf-9bc5-4fa1-b2ad-79473a8d17af
md"""
## Dynamic typying

In a dynamically typed language type-checks are deferred until runtime. 
"""

# ╔═╡ a056c2d2-961e-4b8f-98af-b24f2bfb660e
function f()
	i = 3
	s = "4"
	i + s
end

# ╔═╡ 47e78f05-9751-43d8-8b75-a5603031c4a9
f()

# ╔═╡ 83a4d259-2842-4e1d-af29-70ecf0de2e19
md"""
!!! note
    We can still write analyzers that perform these checks ahead of execution.
    JET.jl is one suche tool in Julia and Julia's own in built type-inference 
    determines that `f` will always fail.
"""

# ╔═╡ b89f5950-3f37-4310-9944-409de578a74a
@report_call f()

# ╔═╡ 23a7ea45-b772-472b-b763-e923bcce7a0f
@code_typed f()

# ╔═╡ 983f57a5-a391-4e68-b891-755cb0e569fe
md"""
Dynamic typing also means that functions can return differently typed values depending on program execution.

In Julia we denotate those as `Union{Int, Float64}`
"""

# ╔═╡ d77dbe9f-87d3-463e-b45b-c7f947b39f3b
g() = rand() ? 1 : 1.0

# ╔═╡ 08d8db52-11b3-4281-b20f-23c038f5d9b3
md"""
## Strong vs weakly typed
Yet another delination is strong vs weakly typed. As an example `C` is a statically typed language, but values are weakly typed.

```c
void f(void* p) {
	int *ints = (int*)p;
    float *floats (float*)p;
    ints[0] + floats[1];
}
```
"""

# ╔═╡ 13d86040-eb93-422e-a522-570fb794353f
md"""
## Open world vs closed world

Many dynamic programing languages have the notion of `eval`.
`Eval` allows one to add code at runtime. Julia is "define by running"
code get's added incrementaly by running code.

!!! note
    Read-Eval-Print-Line (REPL) is a powerful tool, as are use-cases like notebooks.

Open-world semantics means code can be added or change at runtime.

Closed-world semantics mean that the program is fixed before running.
"""

# ╔═╡ 75300e9f-8218-4267-ad8d-99b5a59fa104
md"""
## Interpretation vs Compilation

!!! question
    Is Python interpreted
"""

# ╔═╡ 6dc58b58-f921-4870-a079-3bbdfb69576d
    let
	    content = md"""!!! answer
	Compiled to Bytecode: then interpreted (and there are full Python compiler)
    """
	    HTML("<details>$(html(content))</details>")
    end

# ╔═╡ 7113b4d0-4155-4f68-9189-9a08c23cd385
md"""
!!! question
    Is C compiled?
"""

# ╔═╡ 952bb1db-e62e-4a2a-a5c3-6ad982f51461
    let
	    content = md"""
!!! answer
	Yes, but there are also C interpreters such as Cling.
"""
	    HTML("<details>$(html(content))</details>")
    end

# ╔═╡ 4656cd6b-4c61-49a1-b9c0-5107f8c5dfef
md"""
!!! note
    Interpretations vs Compilation is an implementation choice not part of the language semantics.
"""

# ╔═╡ ce93b6cc-9a05-42b6-be00-b617c36bab1a
md"""
## The curse of leaky abstractions

In Python I can create a class and later modify the fields of an object of said class.

```python
>>> class MyClass:
...   x = 5
... 
>>> c = MyClass()
>>> c.x
5
>>> c.y = 3
>>> c.y
3
>>> c = MyClass()
>>> c.y
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
AttributeError: 'MyClass' object has no attribute 'y'
```
"""

# ╔═╡ 3a853565-a349-4102-9f85-f13c662a704c
md"""

Similarily in Ruby:

```ruby
class A
end

a = A.new
a.age = 20 # Raises undefined method `age='

# Inject attribute accessors into instance of A
class << a
  attr_accessor :age
end

a.age = 20 # Succeeds
a.age # Returns 20

b = A.new
b.age # Raises undefined method, as expected, since we only modified one instance of A
```
"""

# ╔═╡ 4b16cfc8-e77b-4044-a1c1-5fea5828fb4c
md"""
!!! note
    In both Python and Ruby fields are dynamically typed.
"""

# ╔═╡ ca937820-3cb9-4009-93db-0627fe430ab2
md"""
While Julia has inheritance, only abstract types can be inherited from.
Concrete types are final.

```julia
struct A
   age::Int
   data # Untyped field
end
```

Types can also be parametric.

!!! important
    Since concrete types are final we can take advantage of this information, 
    without having to rely on guard checks.
"""

# ╔═╡ 0301eb8a-9363-49fc-8a96-5d4c5b353cf3
md"""
## So how do we make dynamic programs run fast: 

**Julia: Avoiding runtime uncertainty**
- Sophisticated type system
- Type inference
- Multiple dispatch
- Specialization
- JIT compilation


> Julia: Dynamism and Performance Reconciled by Design (doi:10.1145/3276490)
"""

# ╔═╡ 205495c4-4060-48ed-b498-3bd6746c86fa
md"""
## Type inference

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

# ╔═╡ 7ce026fd-c884-41d4-89b4-7e5e7139fdc6
function mysum(X)
	acc = 0
    for x in X
       acc += x
    end
    return acc
end

# ╔═╡ 0d53d881-4599-41dd-9d0e-2adf39230be5
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

# ╔═╡ 7a535689-29d0-4c97-88f7-d09b438d2270

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

# ╔═╡ 5890e3d7-bad6-4260-9584-d7694ce3659e
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

# ╔═╡ b63d195b-a73f-4c72-9dc3-6e7cb216f153
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

# ╔═╡ 89af78f4-c51c-4fc1-a0a9-9279d6728f57
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

# ╔═╡ 101a3517-828b-445e-9939-550b6e6829c8
md"""
- State Before: `{X::Vector{Float64}, acc::Union{Int64, Float64}}`
- State After: `{X::Vector{Float64}, acc::Float64}`
- Unification: `{X::Vector{Float64}, acc::Union{Int64, Float64}}`

Fixed point is reached and we can conclude that after the loop `acc::Union{Int64, Float64}` and thus `mysum(X::Vector{Float64})::Union{Int, Float64}`

We can use Julia's introspection tools to automatically query the system:

- `@code_lowered`
- `@code_typed optimize=false`
"""

# ╔═╡ b435bf1f-13ee-46ca-8c45-58680f286028
@code_lowered mysum(rand(3))

# ╔═╡ 95cb7031-67ae-4243-a07a-c2338ca9bd6e
@code_typed optimize=false mysum(rand(3))

# ╔═╡ c4fd2716-a18a-49af-a317-44c677e40bbe
md"""
## What information did we use?

Julia has `eval`. So what happens if someone changes the definition of say `+` while the code is running?

Julia uses the so called "world-age" system to track the validity of method definitions and method compilations.
"""

# ╔═╡ 7b9eb8e9-943e-4a31-b0ec-1847e70fda6f
md"""

> World age in Julia: optimizing method dispatch in the presence of eval (doi:10.1145/3428275)

"""

# ╔═╡ aa22d898-b106-4812-b0b8-75f5908ee204
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
"""

# ╔═╡ fe94ed49-90cb-44ca-8308-60b76fe9ce93
IR, rt = only(Base.code_ircode(mysum, (Vector{Float64},), optimize_until="compact 1"))

# ╔═╡ 94757fc2-8858-499c-8d26-24844a89fc00
Core.Compiler.ssa_inlining_pass!(
	Core.Compiler.copy(IR),
	Core.Compiler.InliningState(Core.Compiler.NativeInterpreter()), false)

# ╔═╡ e7772c4c-a41e-4ea0-88b4-1482ae155b4a
md"""
Or simply
"""

# ╔═╡ eb2e8913-657a-4c48-93f1-d4b68cf1a990
@code_typed mysum(rand(4))

# ╔═╡ 8bd2c9a8-7c12-4a10-b28a-ca6c4cf86619
md"""
## LLVM based code generation

- LLVM is a widely used compiler framework
- Common set of "middle-end" optimizations based on LLVM IR
- Specific backend optimizations
- Frontends like Julia generate LLVM intermediate representation (IR)
"""

# ╔═╡ e7bae422-7ca6-4cfb-9278-7840a7be647f
@code_llvm optimize=false debuginfo=:none mysum(rand(30))

# ╔═╡ 0516e98c-0a78-43b2-9aec-9d6698032a6e
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

# ╔═╡ b7f12735-8c57-44c6-a922-acd2041c0216
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

# ╔═╡ e3862e23-8942-4c1e-98b0-e4f14b0be8de
md"""
Currently Julia compiles every function before it's first execution.

!!! note
    This initial latency or time-to-first-X, is why sometimes folks say:
    "Julia is fast the second time"

Over the years more and more attention has been payed on amortizing this compilation cost by performing caching. Native code caching for Julia 1.9 had a drastic impact on how "snappy" the language feels.
"""

# ╔═╡ 7e8b6d19-3a9b-41f4-8bfa-3cadc7e69334
YouTube("jFhL8EVrz7s", 10, 5)

# ╔═╡ 55b87adc-2bac-45ae-b8e2-f318502782f4
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

# ╔═╡ 6b5e0098-631d-4a5d-9333-a2ab7c6e95f8
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

"""

# ╔═╡ 12a42930-8299-4711-8c76-bb66f8b3c953
md"""
## Closing words

- Julia is my favorite LLVM frontend.
- Co-design of library and compiler

### Things we haven't talked about today
- Multiple dispatch
- GPU compilation
- Performance engineering
- Global language semantics vs local (boundschecking/fastmath)
- Dynamic on the outside -- static hot loops
- Value specialization
- Non standard program semantics
  - Automatic differentiation
  - GPU programming
  - Instrumentation / Program slicing
- Compiler pipeline tuning for scientific computing
"""

# ╔═╡ 9292017b-3b75-4dfc-af96-889c58d5571b
begin
	struct TwoColumn{L, R}
	    left::L
	    right::R
	end
	
	function Base.show(io, mime::MIME"text/html", tc::TwoColumn)
	    write(io, """<div style="display: flex;"><div style="flex: 50%;">""")
	    show(io, mime, tc.left)
	    write(io, """</div><div style="flex: 50%;">""")
	    show(io, mime, tc.right)
	    write(io, """</div></div>""")
	end
end

# ╔═╡ e0a38f99-3c73-44e0-b4c2-9a9d694eae7e
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

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
AllocCheck = "9b6a8646-10ed-4001-bbdc-1d2f46dfbb1a"
JET = "c3a54625-cd67-489e-a8e7-0a5a0ff4e31b"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
ShortCodes = "f62ebe17-55c5-4640-972f-b59c0dd11ccf"

[compat]
AllocCheck = "~0.1.0"
JET = "~0.8.20"
PlutoUI = "~0.7.54"
ShortCodes = "~0.3.6"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.10.0-rc3"
manifest_format = "2.0"
project_hash = "9eae348a856ec09c60bd094bc49c28335b528c62"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "793501dcd3fa7ce8d375a2c878dca2296232686e"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.2.2"

[[deps.AllocCheck]]
deps = ["ExprTools", "GPUCompiler", "LLVM", "MacroTools"]
git-tree-sha1 = "b7ad7ba856f6a77a4e607e58392177c02ab6be80"
uuid = "9b6a8646-10ed-4001-bbdc-1d2f46dfbb1a"
version = "0.1.0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.CEnum]]
git-tree-sha1 = "389ad5c84de1ae7cf0e28e381131c98ea87d54fc"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.5.0"

[[deps.CodeTracking]]
deps = ["InteractiveUtils", "UUIDs"]
git-tree-sha1 = "c0216e792f518b39b22212127d4a84dc31e4e386"
uuid = "da1fd8a2-8d9e-5ec2-8556-3022fb5608a2"
version = "1.3.5"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "cd67fc487743b2f0fd4380d4cbd3a24660d0eec8"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.3"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "eb7f0f8307f71fac7c606984ea5fb2817275d6e4"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.4"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.0.5+1"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.ExprTools]]
git-tree-sha1 = "27415f162e6028e81c72b82ef756bf321213b6ec"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.10"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.GPUCompiler]]
deps = ["ExprTools", "InteractiveUtils", "LLVM", "Libdl", "Logging", "Scratch", "TimerOutputs", "UUIDs"]
git-tree-sha1 = "5e4487558477f191c043166f8301dd0b4be4e2b2"
uuid = "61eb1bfa-7361-4325-ad38-22787b887f55"
version = "0.24.5"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "7134810b1afce04bbc1045ca1985fbe81ce17653"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.5"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "d75853a0bdbfb1ac815478bacd89cd27b550ace6"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.3"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.JET]]
deps = ["InteractiveUtils", "JuliaInterpreter", "LoweredCodeUtils", "MacroTools", "Pkg", "PrecompileTools", "Preferences", "Revise", "Test"]
git-tree-sha1 = "e67f79f53406ef949dfcaaf775043ed14aac1cc2"
uuid = "c3a54625-cd67-489e-a8e7-0a5a0ff4e31b"
version = "0.8.20"

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

[[deps.JSON3]]
deps = ["Dates", "Mmap", "Parsers", "PrecompileTools", "StructTypes", "UUIDs"]
git-tree-sha1 = "eb3edce0ed4fa32f75a0a11217433c31d56bd48b"
uuid = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
version = "1.14.0"

    [deps.JSON3.extensions]
    JSON3ArrowExt = ["ArrowTypes"]

    [deps.JSON3.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"

[[deps.JuliaInterpreter]]
deps = ["CodeTracking", "InteractiveUtils", "Random", "UUIDs"]
git-tree-sha1 = "e49bce680c109bc86e3e75ebcb15040d6ad9e1d3"
uuid = "aa1ae85d-cabe-5617-a682-6adf51b2e16a"
version = "0.9.27"

[[deps.LLVM]]
deps = ["CEnum", "LLVMExtra_jll", "Libdl", "Preferences", "Printf", "Requires", "Unicode"]
git-tree-sha1 = "0678579657515e88b6632a3a482d39adcbb80445"
uuid = "929cbde3-209d-540e-8aea-75f648917ca0"
version = "6.4.1"

    [deps.LLVM.extensions]
    BFloat16sExt = "BFloat16s"

    [deps.LLVM.weakdeps]
    BFloat16s = "ab4f0b2a-ad5b-11e8-123f-65d77653426b"

[[deps.LLVMExtra_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl", "TOML"]
git-tree-sha1 = "98eaee04d96d973e79c25d49167668c5c8fb50e2"
uuid = "dad2f222-ce93-54a1-a47d-0025e8a3acab"
version = "0.0.27+1"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.4.0+0"

[[deps.LibGit2]]
deps = ["Base64", "LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.6.4+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.0+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.LoweredCodeUtils]]
deps = ["JuliaInterpreter"]
git-tree-sha1 = "0b8cf121228f7dae022700c1c11ac1f04122f384"
uuid = "6f1432cf-f94c-5a45-995e-cdbf5db27b0b"
version = "2.3.2"

[[deps.MIMEs]]
git-tree-sha1 = "65f28ad4b594aebe22157d6fac869786a255b7eb"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "0.1.4"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "b211c553c199c111d998ecdaf7623d1b89b69f93"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.12"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+1"

[[deps.Memoize]]
deps = ["MacroTools"]
git-tree-sha1 = "2b1dfcba103de714d31c033b5dacc2e4a12c7caa"
uuid = "c03570c3-d221-55d1-a50c-7939bbd78826"
version = "0.4.4"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2023.1.10"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.23+2"

[[deps.OrderedCollections]]
git-tree-sha1 = "dfdf5519f235516220579f949664f1bf44e741c5"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.6.3"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "a935806434c9d4c506ba941871b327b96d41f2bf"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.10.0"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "bd7c69c7f7173097e7b5e1be07cee2b8b7447f51"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.54"

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
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.Revise]]
deps = ["CodeTracking", "Distributed", "FileWatching", "JuliaInterpreter", "LibGit2", "LoweredCodeUtils", "OrderedCollections", "Pkg", "REPL", "Requires", "UUIDs", "Unicode"]
git-tree-sha1 = "6990168abf3fe9a6e34ebb0e05aaaddf6572189e"
uuid = "295af30f-e4ad-537b-8983-00126c2a3abe"
version = "3.5.10"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "3bac05bc7e74a75fd9cba4295cde4045d9fe2386"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.2.1"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.ShortCodes]]
deps = ["Base64", "CodecZlib", "Downloads", "JSON3", "Memoize", "URIs", "UUIDs"]
git-tree-sha1 = "5844ee60d9fd30a891d48bab77ac9e16791a0a57"
uuid = "f62ebe17-55c5-4640-972f-b59c0dd11ccf"
version = "0.3.6"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.10.0"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.10.0"

[[deps.StructTypes]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "ca4bccb03acf9faaf4137a9abc1881ed1841aa70"
uuid = "856f2bd8-1eba-4b0a-8007-ebc267875bd4"
version = "1.10.0"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.2.1+1"

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

[[deps.TimerOutputs]]
deps = ["ExprTools", "Printf"]
git-tree-sha1 = "f548a9e9c490030e545f72074a41edfd0e5bcdd7"
uuid = "a759f4b9-e2f1-59dc-863e-4aeb61b1ea8f"
version = "0.5.23"

[[deps.TranscodingStreams]]
git-tree-sha1 = "1fbeaaca45801b4ba17c251dd8603ef24801dd84"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.10.2"
weakdeps = ["Random", "Test"]

    [deps.TranscodingStreams.extensions]
    TestExt = ["Test", "Random"]

[[deps.Tricks]]
git-tree-sha1 = "eae1bb484cd63b36999ee58be2de6c178105112f"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.8"

[[deps.URIs]]
git-tree-sha1 = "67db6cc7b3821e19ebe75791a9dd19c9b1188f2b"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.5.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.8.0+1"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.52.0+1"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"
"""

# ╔═╡ Cell order:
# ╟─2f03b26e-08e1-4be8-81e3-1d97e9c46e97
# ╟─21735a54-7dd0-4a7a-9368-7495e318e307
# ╟─f1db15d4-9f18-11ee-029a-e51fbd66cfea
# ╟─f38c6e65-e4ab-42df-ba05-d6c057ef350f
# ╟─742144a6-7eff-4172-ad85-064e7a2dd67d
# ╟─66a9d9d4-37ea-41a9-9c8e-1791fb7e3e6d
# ╟─c482bc24-f1d2-46c7-8538-48c90d7e4394
# ╟─1dd808d9-84d8-4de3-85ea-73febfee62df
# ╟─09939df5-6b00-4d55-9ddb-d87a25264a8e
# ╟─bdf87ca9-ed6c-4d66-9b1c-b9db83453a4d
# ╟─f3d799cf-9bc5-4fa1-b2ad-79473a8d17af
# ╠═a056c2d2-961e-4b8f-98af-b24f2bfb660e
# ╠═47e78f05-9751-43d8-8b75-a5603031c4a9
# ╟─83a4d259-2842-4e1d-af29-70ecf0de2e19
# ╠═b89f5950-3f37-4310-9944-409de578a74a
# ╠═23a7ea45-b772-472b-b763-e923bcce7a0f
# ╟─983f57a5-a391-4e68-b891-755cb0e569fe
# ╠═d77dbe9f-87d3-463e-b45b-c7f947b39f3b
# ╟─08d8db52-11b3-4281-b20f-23c038f5d9b3
# ╟─13d86040-eb93-422e-a522-570fb794353f
# ╠═75300e9f-8218-4267-ad8d-99b5a59fa104
# ╟─6dc58b58-f921-4870-a079-3bbdfb69576d
# ╟─7113b4d0-4155-4f68-9189-9a08c23cd385
# ╟─952bb1db-e62e-4a2a-a5c3-6ad982f51461
# ╟─4656cd6b-4c61-49a1-b9c0-5107f8c5dfef
# ╟─ce93b6cc-9a05-42b6-be00-b617c36bab1a
# ╟─3a853565-a349-4102-9f85-f13c662a704c
# ╠═4b16cfc8-e77b-4044-a1c1-5fea5828fb4c
# ╟─ca937820-3cb9-4009-93db-0627fe430ab2
# ╟─0301eb8a-9363-49fc-8a96-5d4c5b353cf3
# ╟─205495c4-4060-48ed-b498-3bd6746c86fa
# ╠═7ce026fd-c884-41d4-89b4-7e5e7139fdc6
# ╟─0d53d881-4599-41dd-9d0e-2adf39230be5
# ╟─7a535689-29d0-4c97-88f7-d09b438d2270
# ╟─5890e3d7-bad6-4260-9584-d7694ce3659e
# ╟─b63d195b-a73f-4c72-9dc3-6e7cb216f153
# ╟─89af78f4-c51c-4fc1-a0a9-9279d6728f57
# ╟─101a3517-828b-445e-9939-550b6e6829c8
# ╠═b435bf1f-13ee-46ca-8c45-58680f286028
# ╠═95cb7031-67ae-4243-a07a-c2338ca9bd6e
# ╟─c4fd2716-a18a-49af-a317-44c677e40bbe
# ╟─e0a38f99-3c73-44e0-b4c2-9a9d694eae7e
# ╟─7b9eb8e9-943e-4a31-b0ec-1847e70fda6f
# ╟─aa22d898-b106-4812-b0b8-75f5908ee204
# ╠═fe94ed49-90cb-44ca-8308-60b76fe9ce93
# ╠═94757fc2-8858-499c-8d26-24844a89fc00
# ╠═e7772c4c-a41e-4ea0-88b4-1482ae155b4a
# ╠═eb2e8913-657a-4c48-93f1-d4b68cf1a990
# ╟─8bd2c9a8-7c12-4a10-b28a-ca6c4cf86619
# ╠═e7bae422-7ca6-4cfb-9278-7840a7be647f
# ╟─0516e98c-0a78-43b2-9aec-9d6698032a6e
# ╟─b7f12735-8c57-44c6-a922-acd2041c0216
# ╟─e3862e23-8942-4c1e-98b0-e4f14b0be8de
# ╠═7e8b6d19-3a9b-41f4-8bfa-3cadc7e69334
# ╟─55b87adc-2bac-45ae-b8e2-f318502782f4
# ╟─6b5e0098-631d-4a5d-9333-a2ab7c6e95f8
# ╟─12a42930-8299-4711-8c76-bb66f8b3c953
# ╟─9292017b-3b75-4dfc-af96-889c58d5571b
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
