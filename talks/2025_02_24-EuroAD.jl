### A Pluto.jl notebook ###
# v0.20.5

using Markdown
using InteractiveUtils

# ╔═╡ 94724c40-6734-4ee1-bd3a-aa86e13b36a1
using PlutoUI

# ╔═╡ 6c560e93-df6a-4084-abcf-21babcc0eba1
begin
	import ForwardDiff
	import Zygote
	using Enzyme
end

# ╔═╡ e344fb09-e6d4-4c29-96f5-f0eea1ce8f27
begin
	using LinearAlgebra
	using BenchmarkTools
end

# ╔═╡ 90267c83-6959-4e74-a23b-d46f7559e1cb
using SparseArrays

# ╔═╡ 1cca2af6-5fed-4e77-ad31-a1a528d7e4c9
html"<button onclick='present()'>Toggle presentation mode</button>"

# ╔═╡ 70ea2b0c-83bb-412a-b820-211ed3d8989a
PlutoUI.TableOfContents(; depth=4)

# ╔═╡ 092f5795-8011-41c2-99f1-5ecf880ba537
html"""
<h1> AD in the wild. Experiences from both implementing and applying AD in Julia for HPC </h1>

<div style="text-align: center;">
Apr 3rd 2025 <br>
27th EuroAD Workshop
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

# ╔═╡ 1bf45125-62c2-4119-bb63-fad3987d5a1f
md"""
## What this talk is about
- Language design
- Application patterns
- AD-framework design and limitations

 $\Rightarrow$ Does the AD-framework necessarily need to limit semantics?
"""

# ╔═╡ ba53b7c9-8b4c-4183-8f46-69fc3c7285c8
md"""
## Julia language features
- High-level, yet low-level when needed
- Dynamic
- Multiple-dispatch
- Classical "declarative"
- Types can be "immutable" or "mutable"
"""

# ╔═╡ b01c4a12-668f-4fb1-8c71-d5bf88166926
md"""
## HPC application wants
- Fine-grained operations
- Inplace/mutation
- Parallelism
  - Shared-memory parallelism
  - MPI
  - GPUs
"""

# ╔═╡ 01aff329-bda7-42ca-9411-cef5994f40f4
md"""
## Fine-grained

### Example: Taylor series-esque function

```julia
function taylor(x, N)
	sum = 0 * x
	for i in 1:N
		sum += x^i/i
	end
	return sum
end
```

- Highlight: Fine-grained operations
- Benchmarks: Overhead of AD frameworks
"""

# ╔═╡ 29517cb4-5c91-47dc-a53b-f731d31f038d
function taylor(x, N)
	sum = 0 * x
	for i in 1:N
		sum += x^i/i
	end
	return sum
end

# ╔═╡ ba725f93-095f-4e8a-89b7-10bf435e983e
autodiff(Forward, x->taylor(x, 8), Duplicated(0.5, 1.0)) |> only

# ╔═╡ f4eb88ac-2608-46d0-ab30-44cd8b548e62
autodiff(Reverse, x->taylor(x, 8), Active(0.5)) |> first |> only

# ╔═╡ 532a888b-df97-4587-8387-8ab197654fe6
ForwardDiff.derivative(x->taylor(x, 8), 0.5)

# ╔═╡ a1c4d4d1-b42a-4958-971b-e98182a510ca
Zygote.gradient(x->taylor(x, 8), 0.5)

# ╔═╡ 65cd8661-2176-44be-8571-39ff6f580c53
@benchmark autodiff(Forward, x->taylor(x, 10^6), Duplicated(0.5, 1.0))

# ╔═╡ 90b2c199-54ad-4eed-9ec5-cbb1bf44ef33
@benchmark autodiff(Reverse, x->taylor(x, 10^6), Active(0.5))

# ╔═╡ 996add16-f1ca-4af2-abd3-5cad5b4a733a
@benchmark ForwardDiff.derivative(x->taylor(x, 10^6), 0.5)

# ╔═╡ 7bf929a7-dbd9-4478-b26c-07d44952daa7
@benchmark Zygote.gradient(x->taylor(x, 10^6), 0.5)

# ╔═╡ 5a1f45c7-9f2a-48a7-b66d-83544b13cdfa
md"""
### Benchmarks with other Julia AD tools 

And here we see a comparison against other AD tools within Julia.

$(LocalResource("./comparison.png"))
"""

# ╔═╡ bbb1eae6-44b7-4f80-b6cf-f9f7985d0ce8
md"""
## Mutation
"""

# ╔═╡ 5f04d7ad-0b8a-4b8d-bbff-30a5d7ea908b
function F(X) 
	[
		X[1]^4 - 3;
     	exp(X[2]) - 2; 
	 	log(X[1]) - X[2]^2
	]
end

# ╔═╡ d9f41544-dec4-46a7-816b-9fdee816ec08
ForwardDiff.jacobian(F, [1.0, 1.0])

# ╔═╡ f2678525-e747-4c24-93c1-26a0e81dae5b
Enzyme.jacobian(Forward, F, [1.0, 1.0]) |> only

# ╔═╡ aff16938-7005-43df-bc94-3c44d994ddc5
Enzyme.jacobian(Reverse, F, [1.0, 1.0]) |> only

# ╔═╡ 644612a2-00f6-424b-ae09-0cef80c43f46
Zygote.jacobian(F, [1.0, 1.0]) |> only

# ╔═╡ 768f0ff5-26cd-42c8-90ec-d9299578055c
begin
	function G!(Y, X)
		Y[1] = X[1]^4 - 3
     	Y[2] = exp(X[2]) - 2
	 	Y[3] = log(X[1]) - X[2]^2
	end
	function G(X)
		Y = similar(X, 3)
		G!(Y, X)
		Y
	end
end

# ╔═╡ de81b6ff-3650-434c-ba40-9a2ed10180a7
ForwardDiff.jacobian(G, [1.0, 1.0])

# ╔═╡ 20d9b90a-887d-4b07-a7f7-a443c069bd12
# ╠═╡ disabled = true
#=╠═╡
J = Enzyme.jacobian(Reverse, G, [1.0, 1.0]) |> only
  ╠═╡ =#

# ╔═╡ 6f176687-c407-48f6-a9ab-ab240c60c9fc
Zygote.jacobian(G, [1.0, 1.0]) |> only

# ╔═╡ 054657f4-6560-42e3-9231-da54f9363544
md"""
## Parallelism

At least for Enzyme "solved". See

- https://dl.acm.org/doi/10.1145/3458817.3476165
- https://dl.acm.org/doi/abs/10.5555/3571885.3571964

Yet many sharp edges still to handle.
"""

# ╔═╡ 6faed881-8e1e-4ccd-9996-5a9645ba7aa0
md"""
## Aside: API design

Enzyme vJp in Julia is

```julia
autodiff(Reverse, G!, Duplicated(out, copy(v)), Duplicated(in, w))
```
"""

# ╔═╡ 51871382-9210-44d9-b246-3d743893f92f
md"""
That's clearly wrong!
"""

# ╔═╡ 32117afb-de7b-460d-9026-e707b5fbdd52
let
	out = zeros(3)
	w = zeros(2)
	autodiff(Reverse, G!, Duplicated(out, [0.0,0.0,0.0]), Duplicated([1.0, 1.0], w))
	w
end

# ╔═╡ a235569f-98c7-4c6a-8d97-2b3dbda259e4
md"""
Uhm... All the seeds are zero...

Or are they?
"""

# ╔═╡ f9fe5b2c-df14-4369-b34b-af8ec2369f76
typeof(G!(zeros(3), [1.0, 1.0]))

# ╔═╡ 42416ab7-f683-4228-9f0d-b6b7d715c9f8
md"""
Due to historic reasons Enzyme inferes function with floating point return as "active return" and provides an implicit seed of `1.0`.
"""

# ╔═╡ 9596948f-bb44-458f-965f-e53018baba9e
let
	out = zeros(3)
	w = zeros(2)
	autodiff(Reverse, G!, Const,
			 Duplicated(out, [0.0,0.0,0.0]), Duplicated([1.0, 1.0], w))
	w
end

# ╔═╡ 686c4319-a9db-42e8-a8cf-19179054e95c
md"""
Sanity restored...
"""

# ╔═╡ b2acdae4-59e0-45cc-8049-dd823f7e823e
md"""
### Aside^2: `copy(v)`?

```
autodiff(Reverse, G!, Const,
			 Duplicated(out, copy(v)), Duplicated([1.0, 1.0], w))
```

The `copy(v)` for the differential input (seeds) is necessary since Enzyme will zero-out the values there.
"""

# ╔═╡ 9bce7f10-706b-48c1-8aec-a3b3bee82e2e
md"""
### Aside^3: Building a linear operator for matrix-free

!!! note
    Need to zero differential output in reverse to avoid spurios gradients
"""

# ╔═╡ 48991f62-79df-43e1-8763-2f73bfcc25c7
struct JacobianOperator{F, A}
    f::F # F!(out, in)
    out::A
    in::A
    function JacobianOperator(f::F, out, in) where {F}
        return new{F, typeof(in)}(f, out, in)
    end
end

# ╔═╡ e913c297-6e32-40f1-9a75-1f1cf993d82a
begin
	Base.size(J::JacobianOperator) = (length(J.out), length(J.in))
	Base.eltype(J::JacobianOperator) = eltype(J.in)
end

# ╔═╡ 12b3a6eb-9e9e-484b-85b8-3dc9eb6eb2e0
begin
	LinearAlgebra.adjoint(J::JacobianOperator) = Adjoint(J)
	LinearAlgebra.transpose(J::JacobianOperator) = Transpose(J)
end

# ╔═╡ 869f4b5b-d50c-4b8c-8f38-73f52d0c3380
function maybe_duplicated(f, df)
    if !Enzyme.Compiler.guaranteed_const(typeof(f))
        return DuplicatedNoNeed(f, df)
    else
        return Const(f)
    end
end

# ╔═╡ e9cecba1-0d7a-4369-9fd2-30b5b41df737
function LinearAlgebra.mul!(out, J::JacobianOperator, v)
    autodiff(
        Forward,
        maybe_duplicated(J.f, Enzyme.make_zero(J.f)), Const,
        DuplicatedNoNeed(J.out, out),
        DuplicatedNoNeed(J.in, v)
    )
    return nothing
end

# ╔═╡ d6bd95e7-381b-4234-b33b-99044331f3a2
function LinearAlgebra.mul!(out, J′::Union{Adjoint{<:Any, <:JacobianOperator}, Transpose{<:Any, <:JacobianOperator}}, v)
    J = parent(J′)
    # If out is non-zero we get spurious gradients
    out .= 0
    autodiff(
        Reverse,
        maybe_duplicated(J.f, Enzyme.make_zero(J.f)), 
		Const,
		# Enzyme zeros input derivatives and that confuses the solvers.
        DuplicatedNoNeed(J.out, copy(v)),
        DuplicatedNoNeed(J.in, out)
    )
    return nothing
end

# ╔═╡ dff61d67-8b83-474f-903e-7b1f09c9028a
J = JacobianOperator(G!, zeros(3), [1.0, 1.0])

# ╔═╡ 9a939eb4-0cd7-4e69-8aa6-0e697e78dce9
J

# ╔═╡ e40e327c-48b6-4e42-9e61-20a7d1095d68
begin
	v = [1.0, 0.0, 0.0]
	transpose(J)*v
end

# ╔═╡ c38b06a1-61ca-4625-a3b4-1094f639a343
let
	out = zeros(3)
	w = zeros(2)
	autodiff(Reverse, G!, Duplicated(out, copy(v)), Duplicated([1.0, 1.0], w))
	w
end

# ╔═╡ 30c4147f-926b-455f-b6fc-746d5c744cca
let
	out = zeros(3)
	w = zeros(2)
	autodiff(Reverse, G!, Const,
			 Duplicated(out, copy(v)), Duplicated([1.0, 1.0], w))
	w
end

# ╔═╡ 383d57b3-0b57-4de6-839b-95b7424e36c7
let
	w = zeros(3)
	mul!(w, J, [1.0, 0.0])
	w
end

# ╔═╡ 8f066edf-fd89-4510-a94a-e942e83e1d96
let
	w = zeros(2)
	mul!(w, transpose(J), [1.0, 0.0, 0.0])
	w
end

# ╔═╡ 4c099e64-7778-4825-a971-5beca56d577e
md"""
```julia
using Krylov

F!(res, u) = ....

res = similar(u)
F!(res, u)

J = JacobianOperator(F!, similar(u), u)
gmres(J, -res) # Newton step
```
"""

# ╔═╡ 1efbc3f7-f622-449d-96ba-86a521ad9ada
md"""
## Limitations of operator overload approaches
"""

# ╔═╡ 5fae9a9d-d05f-48b3-bba8-56f27919b8c1
md"""
### Type-constraints
"""

# ╔═╡ 7e83fe6d-77e0-4720-b71b-4ae9289aae98
f(x::Float64) = x^2

# ╔═╡ 4a923597-c0c5-405e-807e-31558f44fb5e
ForwardDiff.derivative(f, 2.0)

# ╔═╡ e008fe3e-983d-44c7-aa98-3b4e194f4838
Enzyme.gradient(Forward, f, 2.0)

# ╔═╡ f2771f56-e3e4-4828-bab3-f163b305f5bc
md"""
### Mixing of types
"""

# ╔═╡ ab395297-79c8-4a37-96bd-bd3e421500bd
function g(x)
	A = zeros(2, 2)
	A[1,1] = x
	A[2,2] = x
	det(A)
end

# ╔═╡ 330b23f7-e03a-42f4-b665-7450821a69b0
ForwardDiff.derivative(g, 2.0)

# ╔═╡ 59b719a7-7edf-458e-92d6-9b848861ce06
Enzyme.gradient(Forward, g, 2.0)

# ╔═╡ e6476af8-dff1-41b5-9712-05aa21ca433b
md"""
## Enzyme caveats and API challenges
"""

# ╔═╡ 33852fdb-4d77-45b7-8897-3df305ba07a1
md"""
Enzyme.jl fundamental API is centered around the function `autodiff` (the other important one is `autodiff_thunk`).

```
autodiff(
	Mode,
	Function
	[Return Activity]
	Annotates Args...
) -> ([primal], ([active args...],))
```

!!! note
    Other AD frameworks in Julia make the reasonable choice of "Only Active args" and "all args are active". Zygote can't handle mutation so that is a natural choice.
    In the presenece of mutation the API design get's complicated

Arguments get annoted by their arguments:

- `Const`: Inactive argument
- `Active`: Only reverse mode -- used for immutable values
- `Duplicated`: primal argument, with tangent/gradient value
  - In forward mode only -- supports immutable values
  - Must be used for mutable values in reverse mode
- Vector mode variants thereof.


!!! note
    Technically in the Julia wrapper we could support `Active(mutable)`
    for reverse mode, but no one wanted it yet badly enough, and we prefer to
    defer the allocation of the shadow to the user. 

"""

# ╔═╡ 5725011b-78d2-4ae8-9b65-9b80bc4dd1d8
md"""
### Active data being stored in globals
"""

# ╔═╡ 49ee9eac-2a7e-4f33-8902-b60f376907af
begin
	const temp = zeros(3)
	function use_temp(x)
		temp[1] = x
		sum(temp .* temp)
	end
end

# ╔═╡ 2beb6e6e-d72e-47b2-b64d-3a5df6c90b4f
autodiff(Reverse, use_temp, Active(1.0))

# ╔═╡ 8d2f5106-2970-40c8-afd1-f4ae3ac07bcb
autodiff(set_runtime_activity(Reverse), use_temp, Active(1.0)) # incorrect

# ╔═╡ 3d3a72bd-6a06-476d-9dda-9390ac1ceafd
md"""
### Active data stored in temporaries
"""

# ╔═╡ 5eba07ac-864c-4ac8-84c0-38e49af47530
function use_temp2(x, tmp)
	tmp[1] = x
	sum(tmp .* tmp)
end

# ╔═╡ 9f00ceb6-1830-4e19-a795-27dbacc3895c
function use_temp2(x)
	tmp = zeros(2)
	use_temp2(x, tmp)
end

# ╔═╡ 2dd7f550-e6b7-4d10-84e4-95d491360c7e
autodiff(Reverse, use_temp2, Active(1.0), Const(zeros(3)))

# ╔═╡ af43c12e-1594-4f20-9341-65458b115e53
autodiff(Reverse, use_temp2, Active(1.0), Duplicated(zeros(2), zeros(2)))

# ╔═╡ 9657da41-ccf3-4244-a8ba-3e23b65f9bc6
autodiff(Reverse, use_temp2, Active(1.0))

# ╔═╡ b18d943a-54fd-437d-91d4-93522849cad5
md"""
##### Function activity

Julia closures/anonymous functions can capture data.
"""

# ╔═╡ 80952340-fb36-4eb0-a951-50193e078143
begin
	struct Functor
		tmp::Vector{Float64}
	end
	function (o::Functor)(x)
		o.tmp[1] = x
		sum(o.tmp .* o.tmp)
	end
end

# ╔═╡ daeaeca1-3b41-448f-a388-401b3d6eb67b
use_temp3 = Functor(zeros(2))

# ╔═╡ b69e32dd-b1ec-429b-819a-b4d14d178c23
autodiff(Reverse, use_temp3, Active(1.0))

# ╔═╡ 25d00135-2518-4171-a6be-aae2469d1def
autodiff(Reverse, 
		 Const(use_temp3),
		 Active(1.0))

# ╔═╡ bf0bd041-7baa-490d-8f21-960a94685c81
autodiff(Reverse, 
		 Duplicated(use_temp3, Enzyme.make_zero(use_temp3)),
		 Active(1.0))

# ╔═╡ 3af9cf96-7fe3-4761-9ad8-e3dd0d5f92a6
md"""
### Activity confusion
"""

# ╔═╡ fcd8148e-fc8b-4922-92f3-93ad18a88a51
md"""
#### Example: Return of active/inactive data
"""

# ╔═╡ 74c58c71-cd01-4960-a56d-fe2cfb767978
function g2(cond, active_var, constant_var)
  if cond
    return active_var
  else
    return constant_var
  end
end

# ╔═╡ a3227caf-b00d-4b27-b6d9-eccad55007a3
Enzyme.autodiff(Forward, g2, Const(true), Duplicated(1.0, 1.0), Const(2))

# ╔═╡ cfc83079-feee-423f-b7bb-0a0d18417de5
md"""
### Structural equivalency of shadow values
"""

# ╔═╡ 64703c30-8a0d-47ed-9fec-eca5b95305e2
md"""
#### Example: Sparse-Arrays
"""

# ╔═╡ b716f551-1451-45f4-8a38-48eaa9aefb88
a = sparse([2.0])

# ╔═╡ 6911e2a0-e6c1-4c9b-ba6c-aa33af38f5ce
let da1 = sparse([0.0]) # Incorrect: SparseMatrixCSC drops explicit zeros
	Enzyme.autodiff(Reverse, sum, Active, Duplicated(a, da1))
end

# ╔═╡ 88811c11-57d8-4e6f-8d94-001caa52d65c
let da2 = sparsevec([1], [0.0]) # Correct: Prevent SparseMatrixCSC from dropping zeros
	Enzyme.autodiff(Reverse, sum, Active, Duplicated(a, da2))
end

# ╔═╡ 23817ef3-22ef-40ec-b220-b94c0a2d3b4d
md"""
### "mutable"/"immutable" data

Julia has both mutable and immutable objects.

"""

# ╔═╡ 9abce328-4d25-4c70-a4b6-9d1c3ed3672b
struct A
   val::Float64
end

# ╔═╡ 53c122ab-71ff-4a3b-bd70-efd0267a961a
mutable struct B
	val::Float64
end

# ╔═╡ 3444c888-6726-4e7b-8d40-2a38e2311626
function simple(obj)
     obj.val*obj.val
end

# ╔═╡ 226625e5-833c-493d-9536-f50ab29684ff
autodiff(Reverse, simple, Active, 
		 Active(A(1.0))) |> only |> first

# ╔═╡ 04fd69f8-71bd-4fd2-b58b-b5dd5444bd62
let dB = B(0.0)
	autodiff(Reverse, simple, Active, 
			 Duplicated(B(1.0), dB)) |> only |> first
	dB
end

# ╔═╡ d12a0692-b36e-4a51-9810-795c65214c4e
mutable struct C
	const val::Float64
end

# ╔═╡ b6b625c2-d7ae-4ca0-8264-384db1dfc791
let dC = C(0.0)
	autodiff(Reverse, simple, Active, 
			 Duplicated(C(1.0), dC)) |> only |> first
	dC # ooof Enzyme is bypassing the language semantics...
end

# ╔═╡ f82c714f-c872-435a-a01b-2d3f4f837dcd
function simple2(obj)
     obj.ref[]*obj.ref[]
end

# ╔═╡ 9ff6afbb-4a0e-4ad9-99f0-9094f67f0b5f
struct D
    ref::Base.RefValue{Float64}
end

# ╔═╡ 1c495af9-57b1-474c-bd52-6ddfa359f098
autodiff(Reverse, simple2, Active, 
		 Active(D(Ref(1.0)))) |> only |> first

# ╔═╡ 07de9e1b-01a5-4dfe-b5b3-f228160e5cea
let dD = D(Ref(0.0))
	autodiff(Reverse, simple2, Active, 
			 Duplicated(D(Ref(1.0)), dD))
	dD # ooof can't rely on the outer container...
end

# ╔═╡ b00978dd-24c9-4f7b-9326-26ffe1a9d840
let dA = A(0.0)
	autodiff(Reverse, simple, Active, 
			 Duplicated(A(1.0), dA))
	dA # Enzyme can't update in place -- but doesn't error
end

# ╔═╡ 6860bf65-e0da-495b-bec6-05f9ee98eb89
struct Mixed
   val::Float64
   ref::Base.RefValue{Float64}
end

# ╔═╡ 3991a893-0a9a-46ed-81c8-089a368ea1b7
function simple3(obj)
     obj.val*obj.ref[]
end

# ╔═╡ 9372bbcb-09e2-44d2-9653-b19a65328ef5
autodiff(Reverse, simple3, Active, 
		 Active(Mixed(1.0, Ref(1.0)))) |> only |> first

# ╔═╡ e42cee29-e821-4098-800c-105239eb17bc
let dM = Mixed(0.0, Ref(0.0))
	autodiff(Reverse, simple3, Active, 
			 Duplicated(Mixed(1.0, Ref(1.0)), dM))
	dM # Enzyme can't update in place -- noooooo
end

# ╔═╡ 5d993a9f-dbaa-479b-b546-44837b1f9ad3
let dM = Ref(Mixed(0.0, Ref(0.0)))
	autodiff(Reverse, simple3, Active, 
			 MixedDuplicated(Mixed(1.0, Ref(1.0)), dM))
	dM[] # Mixed duplicated is not yet an "external type" -- only used for rules
end

# ╔═╡ d9fbe045-345d-4cfe-9d3e-4aca884fcc9b
md"""
### Aliasing
"""

# ╔═╡ 5b4c4909-8134-4b5f-bc22-e061bbc89013
function alias(x, y)
	sum(x.*y)
end

# ╔═╡ 4a665067-f59f-4f0b-888c-7b5af16dab90
let x = [1.0]
	dx = Enzyme.make_zero(x)
	y = [1.0]
	dy = Enzyme.make_zero(y)
	autodiff(Reverse, alias, Active, 
			 Duplicated(x, dx), Duplicated(y, dy))
	dx, dy, x === y, dx === dy
end

# ╔═╡ 9fc30273-81ca-4d48-8b2d-94e606e9d3ef
let x = y = [1.0] 
	dx = Enzyme.make_zero(x)
	dy = Enzyme.make_zero(y)
	autodiff(Reverse, alias, Active, 
			 Duplicated(x, dx), Duplicated(y, dy))
	dx, dy, x === y, dx === dy
end

# ╔═╡ 6c824443-d4ed-459d-9619-a8a1879357d4
let x = y = [1.0] 
	dx = dy = Enzyme.make_zero(x)
	autodiff(Reverse, alias, Active, 
			 Duplicated(x, dx), Duplicated(y, dy))
	dx, dy, x === y, dx === dy
end

# ╔═╡ e9686572-c6ed-406f-a801-b19f7b09b3cd
let x = y = [1.0] 
	seen = IdDict()
	dx = Enzyme.make_zero(typeof(x), seen, x)
	dy = Enzyme.make_zero(typeof(y), seen, y)
	autodiff(Reverse, alias, Active, 
			 Duplicated(x, dx), Duplicated(y, dy))
	dx, dy, x === y, dx === dy
end

# ╔═╡ 5bab2500-57d1-4fcb-ae5d-7b102932a2fb

md"""
### Other weird corner cases
"""

# ╔═╡ 0354de51-07ea-41fe-87a6-8027d587a11a
md"""
#### Optimization may cause wrong gradients...
"""

# ╔═╡ b7693b28-5941-46ab-aa40-68803f97857c
autodiff(Forward, sin, Duplicated(0.0, 1.0)) |> only

# ╔═╡ dbe46e98-ba3f-4dcd-a2da-a281615d488a
function sin_optimized(x)
	if x == 0
		return zero(x)
	else
		sin(x)
	end
end

# ╔═╡ d7131a1a-2eeb-44f5-8caf-ed9778506109
autodiff(Forward, sin_optimized, Duplicated(0.0, 1.0)) |> only
# oops

# ╔═╡ 1d32ac0c-48a8-4224-8a74-641052059a88
md"""
#### Order of operations matter
"""

# ╔═╡ 01fdd4fb-2b5a-4659-b89e-0de189e44cc8
# order of operations matter
let dx = zeros(3)
	autodiff(Enzyme.Reverse, maximum, Duplicated([1.0, 0.0, 1.0], dx))
	dx
end

# ╔═╡ 6c3d83dc-a4d1-44e6-bbcd-6903d7fe3c0b
function maximuml(x)
	acc = -Inf
	for i in 1:length(x)
		acc = max(acc, x[i])
	end
	acc
end

# ╔═╡ 1d1bf263-c137-4dc8-84c2-a90d216491e5
function maximumr(x)
	acc = -Inf
	for i in length(x):-1:1
		acc = max(acc, x[i])
	end
	acc
end

# ╔═╡ 5425fe74-f406-4db1-a82a-6f11644d2498
maximuml([1.0, 0.0, 1.0])

# ╔═╡ 6807d8bb-49e5-45fe-a42a-4a40b004cbd9
let dx = zeros(3)
	autodiff(Enzyme.Reverse, maximuml, Duplicated([1.0, 0.0, 1.0], dx))
	dx
end

# ╔═╡ 1a97feb1-52b1-4705-bfc5-dbb2b1141d37
maximumr([1.0, 0.0, 1.0])

# ╔═╡ dc3a34cf-0867-4e1a-a45f-9b44225a7d2c
let dx = zeros(3)
	autodiff(Enzyme.Reverse, maximumr, Duplicated([1.0, 0.0, 1.0], dx))
	dx
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
Enzyme = "7da242da-08ed-463a-9acd-ee780be4f1d9"
ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
Zygote = "e88e6eb3-aa80-5325-afca-941959d7151f"

[compat]
BenchmarkTools = "~1.6.0"
Enzyme = "~0.13.14"
ForwardDiff = "~0.10.38"
PlutoUI = "~0.7.60"
Zygote = "~0.6.69"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.11.4"
manifest_format = "2.0"
project_hash = "26107a27b16e41a41dd412b53e4cf2528feecff8"

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

[[deps.Adapt]]
deps = ["LinearAlgebra", "Requires"]
git-tree-sha1 = "50c3c56a52972d78e8be9fd135bfb91c9574c140"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "4.1.1"

    [deps.Adapt.extensions]
    AdaptStaticArraysExt = "StaticArrays"

    [deps.Adapt.weakdeps]
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.BenchmarkTools]]
deps = ["Compat", "JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "e38fbc49a620f5d0b660d7f543db1009fe0f8336"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.6.0"

[[deps.CEnum]]
git-tree-sha1 = "389ad5c84de1ae7cf0e28e381131c98ea87d54fc"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.5.0"

[[deps.ChainRules]]
deps = ["Adapt", "ChainRulesCore", "Compat", "Distributed", "GPUArraysCore", "IrrationalConstants", "LinearAlgebra", "Random", "RealDot", "SparseArrays", "SparseInverseSubset", "Statistics", "StructArrays", "SuiteSparse"]
git-tree-sha1 = "a975ae558af61a2a48720a6271661bf2621e0f4e"
uuid = "082447d4-558c-5d27-93f4-14fc19e9eca2"
version = "1.72.3"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra"]
git-tree-sha1 = "3e4b134270b372f2ed4d4d0e936aabaefc1802bc"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.25.0"
weakdeps = ["SparseArrays"]

    [deps.ChainRulesCore.extensions]
    ChainRulesCoreSparseArraysExt = "SparseArrays"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "b10d0b65641d57b8b4d5e234446582de5047050d"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.5"

[[deps.CommonSubexpressions]]
deps = ["MacroTools"]
git-tree-sha1 = "cda2cfaebb4be89c9084adaca7dd7333369715c5"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.1"

[[deps.Compat]]
deps = ["TOML", "UUIDs"]
git-tree-sha1 = "8ae8d32e09f0dcf42a36b90d4e17f5dd2e4c4215"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.16.0"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.1.1+0"

[[deps.ConstructionBase]]
git-tree-sha1 = "76219f1ed5771adbb096743bff43fb5fdd4c1157"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.5.8"

    [deps.ConstructionBase.extensions]
    ConstructionBaseIntervalSetsExt = "IntervalSets"
    ConstructionBaseLinearAlgebraExt = "LinearAlgebra"
    ConstructionBaseStaticArraysExt = "StaticArrays"

    [deps.ConstructionBase.weakdeps]
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"
version = "1.11.0"

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

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "2fb1e02f2b635d0845df5d7c167fec4dd739b00d"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.3"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.Enzyme]]
deps = ["CEnum", "EnzymeCore", "Enzyme_jll", "GPUCompiler", "LLVM", "Libdl", "LinearAlgebra", "ObjectFile", "Preferences", "Printf", "Random", "SparseArrays"]
git-tree-sha1 = "136f590cfed1c25b956fedc6a4d77342e3d4eaa3"
uuid = "7da242da-08ed-463a-9acd-ee780be4f1d9"
version = "0.13.14"

    [deps.Enzyme.extensions]
    EnzymeBFloat16sExt = "BFloat16s"
    EnzymeChainRulesCoreExt = "ChainRulesCore"
    EnzymeLogExpFunctionsExt = "LogExpFunctions"
    EnzymeSpecialFunctionsExt = "SpecialFunctions"
    EnzymeStaticArraysExt = "StaticArrays"

    [deps.Enzyme.weakdeps]
    BFloat16s = "ab4f0b2a-ad5b-11e8-123f-65d77653426b"
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    LogExpFunctions = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
    SpecialFunctions = "276daf66-3868-5448-9aa4-cd146d93841b"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.EnzymeCore]]
git-tree-sha1 = "0cdb7af5c39e92d78a0ee8d0a447d32f7593137e"
uuid = "f151be2c-9106-41f4-ab19-57ee4f262869"
version = "0.8.8"
weakdeps = ["Adapt"]

    [deps.EnzymeCore.extensions]
    AdaptExt = "Adapt"

[[deps.Enzyme_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl", "TOML"]
git-tree-sha1 = "dec17951c0ba91ef723dc71c7687e60398125226"
uuid = "7cc45869-7501-5eee-bdea-0790c847d4ef"
version = "0.0.163+0"

[[deps.ExprTools]]
git-tree-sha1 = "27415f162e6028e81c72b82ef756bf321213b6ec"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.10"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"
version = "1.11.0"

[[deps.FillArrays]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "6a70198746448456524cb442b8af316927ff3e1a"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "1.13.0"

    [deps.FillArrays.extensions]
    FillArraysPDMatsExt = "PDMats"
    FillArraysSparseArraysExt = "SparseArrays"
    FillArraysStatisticsExt = "Statistics"

    [deps.FillArrays.weakdeps]
    PDMats = "90014a1f-27ba-587c-ab20-58faa44d9150"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "05882d6995ae5c12bb5f36dd2ed3f61c98cbb172"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.5"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions"]
git-tree-sha1 = "a2df1b776752e3f344e5116c06d75a10436ab853"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.38"

    [deps.ForwardDiff.extensions]
    ForwardDiffStaticArraysExt = "StaticArrays"

    [deps.ForwardDiff.weakdeps]
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.GPUArrays]]
deps = ["Adapt", "GPUArraysCore", "LLVM", "LinearAlgebra", "Printf", "Random", "Reexport", "Serialization", "Statistics"]
git-tree-sha1 = "62ee71528cca49be797076a76bdc654a170a523e"
uuid = "0c68f7d7-f131-5f86-a1c3-88cf8149b2d7"
version = "10.3.1"

[[deps.GPUArraysCore]]
deps = ["Adapt"]
git-tree-sha1 = "ec632f177c0d990e64d955ccc1b8c04c485a0950"
uuid = "46192b85-c4d5-4398-a991-12ede77f4527"
version = "0.1.6"

[[deps.GPUCompiler]]
deps = ["ExprTools", "InteractiveUtils", "LLVM", "Libdl", "Logging", "PrecompileTools", "Preferences", "Scratch", "Serialization", "TOML", "TimerOutputs", "UUIDs"]
git-tree-sha1 = "199f213e40a7982e9138bc9edc3299419d510390"
uuid = "61eb1bfa-7361-4325-ad38-22787b887f55"
version = "1.2.0"

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

[[deps.IRTools]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "950c3717af761bc3ff906c2e8e52bd83390b6ec2"
uuid = "7869d1d1-7146-5819-86e3-90919afe41df"
version = "0.4.14"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

[[deps.IrrationalConstants]]
git-tree-sha1 = "630b497eafcc20001bba38a4651b327dcfc491d2"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.2"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "be3dc50a92e5a386872a493a10050136d4703f9b"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.6.1"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.LLVM]]
deps = ["CEnum", "LLVMExtra_jll", "Libdl", "Preferences", "Printf", "Unicode"]
git-tree-sha1 = "d422dfd9707bec6617335dc2ea3c5172a87d5908"
uuid = "929cbde3-209d-540e-8aea-75f648917ca0"
version = "9.1.3"

    [deps.LLVM.extensions]
    BFloat16sExt = "BFloat16s"

    [deps.LLVM.weakdeps]
    BFloat16s = "ab4f0b2a-ad5b-11e8-123f-65d77653426b"

[[deps.LLVMExtra_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl", "TOML"]
git-tree-sha1 = "05a8bd5a42309a9ec82f700876903abce1017dd3"
uuid = "dad2f222-ce93-54a1-a47d-0025e8a3acab"
version = "0.0.34+0"

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

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"
version = "1.11.0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.11.0"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "a2d09619db4e765091ee5c6ffe8872849de0feea"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.28"

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
git-tree-sha1 = "65f28ad4b594aebe22157d6fac869786a255b7eb"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "0.1.4"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "2fa9ee3e63fd3a4f7a9a4f4744a52f4856de82df"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.13"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.6+0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"
version = "1.11.0"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2023.12.12"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "0877504529a3e5c3343c6f8b4c0381e57e4387e4"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.0.2"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.ObjectFile]]
deps = ["Reexport", "StructIO"]
git-tree-sha1 = "09b1fe6ff16e6587fa240c165347474322e77cf1"
uuid = "d8793406-e978-5875-9003-1fc021f44a92"
version = "0.4.4"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.27+1"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.1+4"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "dfdf5519f235516220579f949664f1bf44e741c5"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.6.3"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "8489905bcdbcfac64d1daa51ca07c0d8f0283821"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.1"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "Random", "SHA", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.11.0"

    [deps.Pkg.extensions]
    REPLExt = "REPL"

    [deps.Pkg.weakdeps]
    REPL = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "eba4810d5e6a01f612b948c9fa94f905b49087b0"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.60"

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

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"
version = "1.11.0"

[[deps.Profile]]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"
version = "1.11.0"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
version = "1.11.0"

[[deps.RealDot]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "9f0a1b71baaf7650f4fa8a1d168c7fb6ee41f0c9"
uuid = "c1ae055f-0cd5-4b69-90a6-9a35b1a98df9"
version = "0.1.0"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

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
version = "1.11.0"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"
version = "1.11.0"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.11.0"

[[deps.SparseInverseSubset]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "52962839426b75b3021296f7df242e40ecfc0852"
uuid = "dc90abb0-5640-4711-901d-7e5b23a2fada"
version = "0.1.2"

[[deps.SpecialFunctions]]
deps = ["IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "2f5d4697f21388cbe1ff299430dd169ef97d7e14"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.4.0"
weakdeps = ["ChainRulesCore"]

    [deps.SpecialFunctions.extensions]
    SpecialFunctionsChainRulesCoreExt = "ChainRulesCore"

[[deps.StaticArraysCore]]
git-tree-sha1 = "192954ef1208c7019899fbf8049e717f92959682"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.3"

[[deps.Statistics]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "ae3bb1eb3bba077cd276bc5cfc337cc65c3075c0"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.1"
weakdeps = ["SparseArrays"]

    [deps.Statistics.extensions]
    SparseArraysExt = ["SparseArrays"]

[[deps.StructArrays]]
deps = ["ConstructionBase", "DataAPI", "Tables"]
git-tree-sha1 = "f4dc295e983502292c4c3f951dbb4e985e35b3be"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.18"

    [deps.StructArrays.extensions]
    StructArraysAdaptExt = "Adapt"
    StructArraysGPUArraysCoreExt = "GPUArraysCore"
    StructArraysSparseArraysExt = "SparseArrays"
    StructArraysStaticArraysExt = "StaticArrays"

    [deps.StructArrays.weakdeps]
    Adapt = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.StructIO]]
git-tree-sha1 = "c581be48ae1cbf83e899b14c07a807e1787512cc"
uuid = "53d494c1-5632-5724-8f4c-31dff12d585f"
version = "0.3.1"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.7.0+0"

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
git-tree-sha1 = "598cd7c1f68d1e205689b1c2fe65a9f85846f297"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.12.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
version = "1.11.0"

[[deps.TimerOutputs]]
deps = ["ExprTools", "Printf"]
git-tree-sha1 = "f57facfd1be61c42321765d3551b3df50f7e09f6"
uuid = "a759f4b9-e2f1-59dc-863e-4aeb61b1ea8f"
version = "0.5.28"

    [deps.TimerOutputs.extensions]
    FlameGraphsExt = "FlameGraphs"

    [deps.TimerOutputs.weakdeps]
    FlameGraphs = "08572546-2f56-4bcf-ba4e-bab62c3a3f89"

[[deps.Tricks]]
git-tree-sha1 = "7822b97e99a1672bfb1b49b668a6d46d58d8cbcb"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.9"

[[deps.URIs]]
git-tree-sha1 = "67db6cc7b3821e19ebe75791a9dd19c9b1188f2b"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.5.1"

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

[[deps.Zygote]]
deps = ["AbstractFFTs", "ChainRules", "ChainRulesCore", "DiffRules", "Distributed", "FillArrays", "ForwardDiff", "GPUArrays", "GPUArraysCore", "IRTools", "InteractiveUtils", "LinearAlgebra", "LogExpFunctions", "MacroTools", "NaNMath", "PrecompileTools", "Random", "Requires", "SparseArrays", "SpecialFunctions", "Statistics", "ZygoteRules"]
git-tree-sha1 = "4ddb4470e47b0094c93055a3bcae799165cc68f1"
uuid = "e88e6eb3-aa80-5325-afca-941959d7151f"
version = "0.6.69"

    [deps.Zygote.extensions]
    ZygoteColorsExt = "Colors"
    ZygoteDistancesExt = "Distances"
    ZygoteTrackerExt = "Tracker"

    [deps.Zygote.weakdeps]
    Colors = "5ae59095-9a9b-59fe-a467-6f913c188581"
    Distances = "b4f34e82-e78d-54a5-968a-f98e89d6e8f7"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"

[[deps.ZygoteRules]]
deps = ["ChainRulesCore", "MacroTools"]
git-tree-sha1 = "434b3de333c75fc446aa0d19fc394edafd07ab08"
uuid = "700de1a5-db45-46bc-99cf-38207098b444"
version = "0.2.7"

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
# ╟─1cca2af6-5fed-4e77-ad31-a1a528d7e4c9
# ╟─94724c40-6734-4ee1-bd3a-aa86e13b36a1
# ╟─70ea2b0c-83bb-412a-b820-211ed3d8989a
# ╟─092f5795-8011-41c2-99f1-5ecf880ba537
# ╠═6c560e93-df6a-4084-abcf-21babcc0eba1
# ╠═e344fb09-e6d4-4c29-96f5-f0eea1ce8f27
# ╟─1bf45125-62c2-4119-bb63-fad3987d5a1f
# ╟─ba53b7c9-8b4c-4183-8f46-69fc3c7285c8
# ╟─b01c4a12-668f-4fb1-8c71-d5bf88166926
# ╟─01aff329-bda7-42ca-9411-cef5994f40f4
# ╠═29517cb4-5c91-47dc-a53b-f731d31f038d
# ╠═ba725f93-095f-4e8a-89b7-10bf435e983e
# ╠═f4eb88ac-2608-46d0-ab30-44cd8b548e62
# ╠═532a888b-df97-4587-8387-8ab197654fe6
# ╠═a1c4d4d1-b42a-4958-971b-e98182a510ca
# ╠═65cd8661-2176-44be-8571-39ff6f580c53
# ╠═90b2c199-54ad-4eed-9ec5-cbb1bf44ef33
# ╠═996add16-f1ca-4af2-abd3-5cad5b4a733a
# ╠═7bf929a7-dbd9-4478-b26c-07d44952daa7
# ╟─5a1f45c7-9f2a-48a7-b66d-83544b13cdfa
# ╟─bbb1eae6-44b7-4f80-b6cf-f9f7985d0ce8
# ╠═5f04d7ad-0b8a-4b8d-bbff-30a5d7ea908b
# ╠═d9f41544-dec4-46a7-816b-9fdee816ec08
# ╠═f2678525-e747-4c24-93c1-26a0e81dae5b
# ╠═aff16938-7005-43df-bc94-3c44d994ddc5
# ╠═644612a2-00f6-424b-ae09-0cef80c43f46
# ╠═768f0ff5-26cd-42c8-90ec-d9299578055c
# ╠═de81b6ff-3650-434c-ba40-9a2ed10180a7
# ╠═20d9b90a-887d-4b07-a7f7-a443c069bd12
# ╠═6f176687-c407-48f6-a9ab-ab240c60c9fc
# ╟─054657f4-6560-42e3-9231-da54f9363544
# ╟─6faed881-8e1e-4ccd-9996-5a9645ba7aa0
# ╠═9a939eb4-0cd7-4e69-8aa6-0e697e78dce9
# ╠═e40e327c-48b6-4e42-9e61-20a7d1095d68
# ╠═c38b06a1-61ca-4625-a3b4-1094f639a343
# ╠═51871382-9210-44d9-b246-3d743893f92f
# ╠═32117afb-de7b-460d-9026-e707b5fbdd52
# ╟─a235569f-98c7-4c6a-8d97-2b3dbda259e4
# ╠═f9fe5b2c-df14-4369-b34b-af8ec2369f76
# ╟─42416ab7-f683-4228-9f0d-b6b7d715c9f8
# ╠═9596948f-bb44-458f-965f-e53018baba9e
# ╠═30c4147f-926b-455f-b6fc-746d5c744cca
# ╠═686c4319-a9db-42e8-a8cf-19179054e95c
# ╟─b2acdae4-59e0-45cc-8049-dd823f7e823e
# ╠═9bce7f10-706b-48c1-8aec-a3b3bee82e2e
# ╠═48991f62-79df-43e1-8763-2f73bfcc25c7
# ╠═e913c297-6e32-40f1-9a75-1f1cf993d82a
# ╠═12b3a6eb-9e9e-484b-85b8-3dc9eb6eb2e0
# ╠═869f4b5b-d50c-4b8c-8f38-73f52d0c3380
# ╠═e9cecba1-0d7a-4369-9fd2-30b5b41df737
# ╠═d6bd95e7-381b-4234-b33b-99044331f3a2
# ╠═dff61d67-8b83-474f-903e-7b1f09c9028a
# ╠═383d57b3-0b57-4de6-839b-95b7424e36c7
# ╠═8f066edf-fd89-4510-a94a-e942e83e1d96
# ╟─4c099e64-7778-4825-a971-5beca56d577e
# ╟─1efbc3f7-f622-449d-96ba-86a521ad9ada
# ╟─5fae9a9d-d05f-48b3-bba8-56f27919b8c1
# ╠═7e83fe6d-77e0-4720-b71b-4ae9289aae98
# ╠═4a923597-c0c5-405e-807e-31558f44fb5e
# ╠═e008fe3e-983d-44c7-aa98-3b4e194f4838
# ╟─f2771f56-e3e4-4828-bab3-f163b305f5bc
# ╠═ab395297-79c8-4a37-96bd-bd3e421500bd
# ╠═330b23f7-e03a-42f4-b665-7450821a69b0
# ╠═59b719a7-7edf-458e-92d6-9b848861ce06
# ╟─e6476af8-dff1-41b5-9712-05aa21ca433b
# ╟─33852fdb-4d77-45b7-8897-3df305ba07a1
# ╟─5725011b-78d2-4ae8-9b65-9b80bc4dd1d8
# ╠═49ee9eac-2a7e-4f33-8902-b60f376907af
# ╠═2beb6e6e-d72e-47b2-b64d-3a5df6c90b4f
# ╠═8d2f5106-2970-40c8-afd1-f4ae3ac07bcb
# ╟─3d3a72bd-6a06-476d-9dda-9390ac1ceafd
# ╠═5eba07ac-864c-4ac8-84c0-38e49af47530
# ╠═2dd7f550-e6b7-4d10-84e4-95d491360c7e
# ╠═af43c12e-1594-4f20-9341-65458b115e53
# ╠═9f00ceb6-1830-4e19-a795-27dbacc3895c
# ╠═9657da41-ccf3-4244-a8ba-3e23b65f9bc6
# ╠═b18d943a-54fd-437d-91d4-93522849cad5
# ╠═80952340-fb36-4eb0-a951-50193e078143
# ╠═daeaeca1-3b41-448f-a388-401b3d6eb67b
# ╠═b69e32dd-b1ec-429b-819a-b4d14d178c23
# ╠═25d00135-2518-4171-a6be-aae2469d1def
# ╠═bf0bd041-7baa-490d-8f21-960a94685c81
# ╟─3af9cf96-7fe3-4761-9ad8-e3dd0d5f92a6
# ╟─fcd8148e-fc8b-4922-92f3-93ad18a88a51
# ╠═74c58c71-cd01-4960-a56d-fe2cfb767978
# ╟─a3227caf-b00d-4b27-b6d9-eccad55007a3
# ╟─cfc83079-feee-423f-b7bb-0a0d18417de5
# ╟─64703c30-8a0d-47ed-9fec-eca5b95305e2
# ╠═90267c83-6959-4e74-a23b-d46f7559e1cb
# ╠═b716f551-1451-45f4-8a38-48eaa9aefb88
# ╠═6911e2a0-e6c1-4c9b-ba6c-aa33af38f5ce
# ╠═88811c11-57d8-4e6f-8d94-001caa52d65c
# ╟─23817ef3-22ef-40ec-b220-b94c0a2d3b4d
# ╠═9abce328-4d25-4c70-a4b6-9d1c3ed3672b
# ╠═53c122ab-71ff-4a3b-bd70-efd0267a961a
# ╠═3444c888-6726-4e7b-8d40-2a38e2311626
# ╠═226625e5-833c-493d-9536-f50ab29684ff
# ╠═04fd69f8-71bd-4fd2-b58b-b5dd5444bd62
# ╠═d12a0692-b36e-4a51-9810-795c65214c4e
# ╠═b6b625c2-d7ae-4ca0-8264-384db1dfc791
# ╠═f82c714f-c872-435a-a01b-2d3f4f837dcd
# ╠═9ff6afbb-4a0e-4ad9-99f0-9094f67f0b5f
# ╠═1c495af9-57b1-474c-bd52-6ddfa359f098
# ╠═07de9e1b-01a5-4dfe-b5b3-f228160e5cea
# ╠═b00978dd-24c9-4f7b-9326-26ffe1a9d840
# ╠═6860bf65-e0da-495b-bec6-05f9ee98eb89
# ╠═3991a893-0a9a-46ed-81c8-089a368ea1b7
# ╠═9372bbcb-09e2-44d2-9653-b19a65328ef5
# ╠═e42cee29-e821-4098-800c-105239eb17bc
# ╠═5d993a9f-dbaa-479b-b546-44837b1f9ad3
# ╟─d9fbe045-345d-4cfe-9d3e-4aca884fcc9b
# ╠═5b4c4909-8134-4b5f-bc22-e061bbc89013
# ╠═4a665067-f59f-4f0b-888c-7b5af16dab90
# ╠═9fc30273-81ca-4d48-8b2d-94e606e9d3ef
# ╠═6c824443-d4ed-459d-9619-a8a1879357d4
# ╠═e9686572-c6ed-406f-a801-b19f7b09b3cd
# ╟─5bab2500-57d1-4fcb-ae5d-7b102932a2fb
# ╟─0354de51-07ea-41fe-87a6-8027d587a11a
# ╠═b7693b28-5941-46ab-aa40-68803f97857c
# ╠═dbe46e98-ba3f-4dcd-a2da-a281615d488a
# ╠═d7131a1a-2eeb-44f5-8caf-ed9778506109
# ╟─1d32ac0c-48a8-4224-8a74-641052059a88
# ╠═01fdd4fb-2b5a-4659-b89e-0de189e44cc8
# ╠═6c3d83dc-a4d1-44e6-bbcd-6903d7fe3c0b
# ╠═1d1bf263-c137-4dc8-84c2-a90d216491e5
# ╠═5425fe74-f406-4db1-a82a-6f11644d2498
# ╠═6807d8bb-49e5-45fe-a42a-4a40b004cbd9
# ╠═1a97feb1-52b1-4705-bfc5-dbb2b1141d37
# ╠═dc3a34cf-0867-4e1a-a45f-9b44225a7d2c
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
