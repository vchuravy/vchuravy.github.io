### A Pluto.jl notebook ###
# v1.0.1

using Markdown
using InteractiveUtils

# ╔═╡ 665c5ded-f7ad-4a4c-a295-69f82aab5495
begin
	using PlutoUI, PlutoTeachingTools
	using PlutoUI: Slider
end

# ╔═╡ 00c1a967-c4e2-44e8-b6f9-85ea65c654be
begin
	using CairoMakie
	set_theme!(theme_latexfonts();
			   fontsize = 16,
			   Lines = (linewidth = 2,),
			   markersize = 16)
end

# ╔═╡ 9d422306-9c7b-4efd-bd8d-a0b80dcc139a
using Symbolics

# ╔═╡ ca574392-a993-48e0-ac0e-5a2ff8809689
using LinearAlgebra

# ╔═╡ ae5bb7ac-ade2-4ef9-8d83-84cf3215612c
using Enzyme

# ╔═╡ f488d269-bea7-4a96-b7a6-8aade72aa576
using SparseArrays

# ╔═╡ ba0a191d-1dc2-454d-80cd-79fe0c739c00
using Krylov

# ╔═╡ 2f59050b-d630-4a3a-8aa1-3c2e9a70c66f
ChooseDisplayMode()

# ╔═╡ b0448824-81ea-11f0-3d7a-bd269696aca6
html"""
<h1> Automatic differentiation for Scientific Computing</h1>

<div style="text-align: center;">
Jun 18th 2025 <br>
Summer School on HPC Driving AI
<br><br>
Valentin Churavy
<br><br>
High Performance Scientific Computing, University of Augsburg <br>
Numerical Mathematics, University of Mainz <br>
High-Performance Computing, Universität des Saarlandes
<br><br>
@vchuravy
</div>

 <table>
        <tr>
<td><img src="https://upload.wikimedia.org/wikipedia/commons/e/e9/Universit%C3%A4t_Augsburg_logo.svg" width=100px></td>

<td><img src="https://upload.wikimedia.org/wikipedia/commons/8/8a/Johannes_Gutenberg-Universit%C3%A4t_Mainz_logo.svg" width=200px></td>

<td><img src="https://upload.wikimedia.org/wikipedia/de/b/bc/Logo-Universit%C3%A4t_des_Saarlandes.svg" width=200px></td>
        </tr>
</table>
"""

# ╔═╡ 4753cb46-803b-4c4c-a0ed-9e960238ae1b
md"""
## Who am I?
RSE/PostDoc working on the Julia compiler and runtime for accelerated computing and HPC.

My goal is to make HPC and GPU based programming easier and more accessible.

I work with science teams to help them maximise their usage of Julia.

1. B.Sc. Cognitive Science, 2014
   University of Osnabrück
2. Research in applied Machine Learning, 2015-2017
   Okinawa Institute of Science and Technology, Japan
3. M.Sc. Computer Science, 2019
   JuliaLab@MIT
4. Ph.D. Computer Science, 2024
   JuliaLab@MIT
5. RSE/PostDoc in Augsburg & Mainz -- High-Performance Scientific Computing, 2024-2026
6. PostDoc, High-Performance Computing,  Universität des Saarlandes 2026-

"""

# ╔═╡ 35319c71-404a-495b-8555-d8de85de255c
md"""
## Motivation 1: Automated parameter calibration for climate simulations

SpeedyWeather's simple sea ice model with 2 parameters
- freeze rate $f$
- melt rate $m$
- plus parameters from air-ocean, air-ice, ocean-ice fluxes, albedo, snow, ...

So we *need* to calibrate them all together!

$(RobustLocalResource("https://github.com/user-attachments/assets/835a10a6-a008-4a7c-944a-35d255ccdd46", "simulation.mp4"))

 
(Zonal velocity (green), sea ice cover (blue-purple), 150km resolution, Nov-April)

##

Compared to observations 

$(RobustLocalResource("https://github.com/user-attachments/assets/02d5c67e-6573-4d9e-b37f-3bfa77fccd60", "arctic_sea_ice.png"))
- ❌ Arctic is ice-free in summer
- ❌ Sea ice reaches Scotland in winter
"""

# ╔═╡ e7b23248-4475-4ae2-bb8f-88af5c76dc67
md"""

## Motivation 2: Calibrate ocean mixing from high-resolution simulations

Oceananigans can use a high-resolution (but local area) version of itself
to calibrate turbulent kinetic energy for its global simulations

$(LocalResource("./oceananigans_drag_coefficient.png"))


Possible to do this gradient-free (e.g. Ensemble Kalman Inversion) for
few parameters but likely needs recalibration in every coupled simulation ... 


"""

# ╔═╡ 177bd814-0795-48fb-8049-ce8d12bf1025
md"""
## Why do we want gradients/derivatives

Derivatives compute the rate of change of a function’s output with respect to input(s)

```math
f'(x) = \lim_{h\rightarrow 0} \frac{f(a+h)-f(a)}{h}
```

### Used in many places

- Optimization problems
- Implicit time-integration
- Non-linear problems
- Parameter estimation
- Uncertainity quantification
- Machine learning
"""

# ╔═╡ de43f959-683c-44e5-8836-8239a0386997
begin
    N(xᵢ, θ) = θ[1] * xᵢ^2 + θ[2] * xᵢ
    S(xᵢ, cᵢ) = xᵢ + cᵢ
end

# ╔═╡ cac6333c-caa3-4eef-8462-b62d8b802d3d
function simulate(N, S, x₀, y, θ, n)
    xᵢ = x₀
    for i in 1:n
        cᵢ = N(xᵢ, θ)
        xᵢ = S(xᵢ, cᵢ)
    end
    return L = 1 / 2 * (xᵢ - y)^2
end

# ╔═╡ 4876df7e-0545-41d6-83ff-56f629ad85c0
function ∇simulate(N, S, x₀, y, θ, n)
    dθ = MixedDuplicated(θ, Ref(Enzyme.make_zero(θ)))
    Enzyme.autodiff(Enzyme.Reverse, simulate, Const(N), Const(S), Const(x₀), Const(y), dθ, Const(n))
    return dθ.dval[]
end

# ╔═╡ 3e17838b-83c0-4b78-a5a5-44587a984bae
md"""
## Differentiable programming

Tensorflow/PyTorch/Jax are domain-specific languages (DSL) for machine learning that use automatic differentiation to "learn"/optimize neuronal networks.

They can be used for scientific programming as well, but have frustrating limitations to work around.
"""

# ╔═╡ dade7d3c-4b53-4f7a-a63b-82d338512557
TwoColumn(
md"""
### Machine Learning
- High-level operations
- Functional
- Limited control-flow
- Automated parallelism (due to HLO and batches)
""",
md"""
### Scientific programming
- Fine-grained operations
- Inplace/Mutation
- Full control-flow
- Varied parallelism
""")

# ╔═╡ db23cb48-9fc1-40f1-b3f9-96025a5a2343
md"""
## Scientific programming in Julia
"""

# ╔═╡ 49f8208e-20fd-438d-804f-3f44359fc6a6
TwoColumn(
md"""
### Julia
- High-level, yet low-level when needed
- Dynamic
- Multiple-dispatch
- Classical "imperative"
- Types can be "immutable" or "mutable"
""",
md"""
### HPC application wants
- Fine-grained operations
- Inplace/mutation
- Parallelism
  - Shared-memory parallelism
  - MPI
  - GPUs
"""
)

# ╔═╡ 95776f94-e0e5-4a72-8a48-f16e177a750b
md"""
## Fine-grained
"""

# ╔═╡ 01847641-ce9c-4717-add6-68a091fe9bb6
function taylor(x, N)
	sum = 0 * x
	for i in 1:N
		sum += x^i/i
	end
	return sum
end

# ╔═╡ eb358263-a6dc-4971-b13a-7fb1ac897549
md"""
## Control-flow

```julia
res = F(u)
while norm(res) >= tol
	J = assemble_jacobian!(F, u)
	u .+= J \ -res
    res = F(u)
end
```
"""

# ╔═╡ ac00a927-cf53-4176-aa58-3ae99203f6ab
md"""
## Mutation
"""

# ╔═╡ 5eca6a6c-ebf1-4c5f-b51b-9086e1526d0a
function F(X) 
	[
		X[1]^4 - 3;
     	exp(X[2]) - 2; 
	 	log(X[1]) - X[2]^2
	]
end

# ╔═╡ f487a3f1-bfdb-4ea6-9a82-cc8c7ece298a
md"""
to avoid frequent memory-allocations we often write function such that they mutate an argument
"""

# ╔═╡ edc136c6-db1d-48c5-a619-dd5565198989
begin
	function G!(Y, X)
		Y[1] = X[1]^4 - 3
     	Y[2] = exp(X[2]) - 2
	 	Y[3] = log(X[1]) - X[2]^2
		return nothing
	end
	function G(X)
		Y = similar(X, 3)
		G!(Y, X)
		return Y
	end
end

# ╔═╡ a8301438-511d-462c-a759-6c5a1bf9d801
md"""
# How can we obtain derivatives of programs
"""

# ╔═╡ 52f4e73a-7a3f-48fc-9994-4c18661910c7
md"""
## Numerical differentiation / Finite differences
"""

# ╔═╡ fae1668d-9761-4e83-968b-a90266b442de
md"""
#### First-order finite differences
$\frac{F(u + \epsilon) - F(u)}{\epsilon}$
"""

# ╔═╡ 3b36bab3-b7b3-437a-8e63-03b358a290dc
function finite_differences(F, u, ϵ = sqrt(eps()))
	(F(u .+ ϵ) .- F(u)) ./ ϵ
end

# ╔═╡ f22e0e4b-63e6-4117-b867-fb714b0e8f51
finite_differences(x->taylor(x, 8), 0.5)

# ╔═╡ ba4b4c9b-7b49-4afc-9815-abebb8173611
md"""
## Limitations

- Numerical issues
- Choice of ϵ
- Admissabilty 
  (`f` defined over interval; evaluation at the edges of interface)
"""

# ╔═╡ 49b152ce-918c-4fa9-a0c9-94ff78be9d98
md"""
## Symbolic differentiation
"""

# ╔═╡ d194abf2-0e47-4a8d-b7ac-1f5192abdbb2
begin
	@variables v_x
	ex = taylor(v_x, 8)
end

# ╔═╡ becd3850-1474-49ad-ba58-a0723ddafe9d
d_ex = Symbolics.derivative(ex, v_x)

# ╔═╡ 691bb998-b0f4-421e-b697-e722e971d280
d_taylor = eval(build_function(d_ex, [v_x]))

# ╔═╡ dba428fe-700b-429a-a4b9-c91f9f2f49d7
substitute(d_ex, v_x=>0.5)

# ╔═╡ 94de6dad-68ea-4d5e-a76e-ef0829310edc
d_taylor(0.5)

# ╔═╡ ad79adf5-c03d-4499-8258-b1add2f6c636
md"""
## Limitations
"""

# ╔═╡ 14b40f50-defd-420c-86da-59a3084113f9
md"""
Symbolic differentiation is quite powerful, but the complexity of expressions with loops grows quickly. Additionally it cannot handle algorithms whose behavior or control-flow depend on the specific values of symbols.
"""

# ╔═╡ 4bf55868-449e-4c37-a07c-68479a772b70
my_abs(x) = ifelse(x <= 0,  -x, x)

# ╔═╡ fd8b95b8-cefe-42ab-a7d0-a9b84471d66f
my_abs(v_x)

# ╔═╡ ce2631c0-ea8b-4faa-8a4a-5908f87bf760
md"""
## Automatic differentiation
"""

# ╔═╡ 771e861c-3d35-4cfc-996f-a937acef3189
g(x) = log(x^2 + exp(sin(x)))

# ╔═╡ e62da3de-de5a-4c5f-b943-975c1971b728
md"""
### AD: Source-rewriting

Synthesize from the "written" definition of a program using the chain-rule a version that also calculates the derivative. 
"""

# ╔═╡ 76904814-1460-4e60-a8d2-1bbb188196b8
TwoColumn(
md"""
```julia
function g(x)
	c1 = x^2
	c2 = sin(x)
	c3 = exp(c2)
	c4 = c1 + c3
	c5 = log(c4)
	return c5
end
```
""",
md"""
```julia
function δ_g(x, x_ϵ=one(x)))
	c1 = x^2
	c1_ε = x * x_ϵ + x_ϵ * x # 2x
	
	c2 = sin(x)
	c2_ε = cos(x) * x_ϵ
	
	c3 = exp(c2)
	c3_ε = exp(c2) * c2_ε
	
	c4 = c1 + c3
	c4_ε = c1_ε + c3_ε
	
	c5 = log(c4)
	c5_ε = c4_ε / c4
	return c5, c5_ε
end
```
"""
)

# ╔═╡ b89e6d57-050d-4373-8c48-afcf5c1e6abe
question_box(
md"""
How do we know the meaning of names? What does `^`, `sin`, `exp`, `+`, `log` refer to?
"""
)

# ╔═╡ 1762c7cc-4a7d-43af-86d5-fb94e9afa4c2
md"""
In a dynamic language like Julia the semantics of these symbols are not gurantueed from the syntax! 

It would be more correct to translate `log(c4)` into `δ_log(c4, c4_ϵ)`, Which we could then implement as `c4_ε / c4`.

!!! note
    As we can see `δ_g` is expressed in terms of `x` and it's derivative `x_ϵ`.
    Instead of expressing these as two separate arguments we can bundle them in
    a new number type.
"""

# ╔═╡ b4ff8899-4ac2-4c48-b2b3-3a25d8a64d70
md"""
### AD: Operator-overloading

Instead of performing code synthesis on the syntax level, we can define a new number type `Dual`, and use it to provide overloads for all the operators.
"""

# ╔═╡ 1be367e1-0b24-4566-829d-b1769fe0c9e8
md"""
```julia

struct Dual{T}
	value::T
    deriv::T
end
Dual(x::Real, y::Real) = Dual(promote(x, y)...)
δ(f, x) = f(Dual(x, one(x)))

Base.:+(x::Dual, y::Dual) = Dual(x.value + y.value,
								 x.deriv + y.deriv)
Base.log(x::Dual) = Dual(log(x.value), x.deriv / x.value)
...
```
"""

# ╔═╡ 94ac531b-7403-47a4-b657-895747401876
md"""
In Julia one of the most of operator-overloading is ForwardDiff.jl
"""

# ╔═╡ 8e9fc1cb-44de-4280-bcc6-f03be7a47a29
import ForwardDiff

# ╔═╡ 7070c213-922c-4858-820f-40e8b80c3cbc
δ(f, x) = ForwardDiff.derivative(f, x)

# ╔═╡ c6f19816-6e5c-4a4d-9cb3-891055c9fae7
md"""
## Limitations of operator overload approaches
"""

# ╔═╡ 526cbd5e-0eca-4c8b-8ae7-ecdc00395abe
md"""
### Type-constraints
"""

# ╔═╡ d2dc99f2-0892-487f-9b6a-fe224714a8f2
f(x) = x^2

# ╔═╡ a865bc58-8817-48a6-a52b-515646f6cee0
δ(f, 2.0)

# ╔═╡ e568f24a-3694-4cb5-8958-db00643b7fcf
md"""
### Mixing of types
"""

# ╔═╡ 3b858db5-3b5f-465e-9901-2570a8213419
function h(x)
	A = zeros(2, 2)
	A[1,1] = x
	A[2,2] = x
	det(A)
end

# ╔═╡ ec6157b9-0d3b-4e96-a098-e65044716db8
δ(h, 2.0)

# ╔═╡ a280de28-b0e5-4770-a751-78353a692354
md"""
## Compiler-Enabled AD

Compilers like the Julia compilers don't act on the surface syntax, but rather they have multiple intermediate representations (IRs).

- Untyped IR
- Typed IR
- LLVM IR
"""

# ╔═╡ aa1d34de-244c-4254-8b82-7fa30767f969
with_terminal() do
	@code_llvm debuginfo=:none g(2.0)
end

# ╔═╡ bf7dc379-2d87-4df2-a8ae-05299d604617
md"""
Enzyme acts on the LLVM IR (with ample support through language-specific frontends) since the LLVM IR is fully specified it partially side-steps the "semantic" meaning question of the surface syntax.
"""

# ╔═╡ 349eaea0-8ff0-4945-a0f7-ba9bd9dc23e8
with_terminal() do
	Enzyme.Compiler.enzyme_code_llvm(
		g, Duplicated, Tuple{Duplicated{Float64}},
		mode=Enzyme.API.DEM_ForwardMode,
		debuginfo=:none
	)
end

# ╔═╡ a2aac3a8-54ac-449a-8bc7-c6375263a102
Enzyme.autodiff(Forward, x->taylor(x, 8), Duplicated(0.5, 1.0)) |> only

# ╔═╡ c1766483-9d4e-4ac9-9cf4-eb8a680fac71
Enzyme.autodiff(Enzyme.Reverse, x->taylor(x, 8), Active(0.5)) |> first |> only

# ╔═╡ 4d69e335-d027-4ddc-9d7c-2be3ce79e0c5
md"""
!!! note
    You may have notice the term **Forward** in ForwardDiff and Enzyme `autodiff(Forward, ...)`, and now the term **Reverse**. More about this later, but forward and reverse are different mode of AD, and Reverse mode is preferred in ML and Forward is often used in scientific programming.
"""

# ╔═╡ 94d246de-d120-4d66-879f-f28076489dea
Enzyme.gradient(Forward, f, 2.0) # Type-annotation

# ╔═╡ 6dad4e2a-8521-4169-bfbd-a62991d53b5a
Enzyme.gradient(Forward, h, 2.0) # Mixing of types 

# ╔═╡ bbccea64-cc3b-45eb-a816-ef2f4ac09a5e
md"""
## Comparison
| Tool | Result |
| ---- | ------ |
| Symbolics.jl (substitute) |  $(substitute(d_ex, v_x=>0.5)) |
| Symbolics.jl (build_function) |  $(d_taylor(0.5)) |
| ForwardDiff.jl |  $(δ(x->taylor(x, 8), 0.5)) |
| Enzyme.jl | $(only(Enzyme.autodiff(Forward, x->taylor(x, 8), Duplicated(0.5, 1.0)))) |
| Finite differences first order | $(finite_differences(x->taylor(x, 8), 0.5)) |
"""

# ╔═╡ 3b3d3bd4-2242-4941-9331-be465b80b778
md"""
## Benchmarks with other Julia AD tools 

And here we see a comparison against other AD tools within Julia.

$(LocalResource("./comparison.png"))
"""

# ╔═╡ 3fcc4381-dd86-4989-9adf-581fcd8b4eae
md"""
## Datalayout: Dual-Numbers vs Shadow-Heap

While Enzyme.jl and ForwardDiff.jl both implement forward-mode they differ in the memory layout. 

For arrays, ForwardDiff.jl uses arrays of dual numbers and Enzyme.jl uses duals (shadows) of arrays. 

```julia
function h(x)
	A = zeros(2, 2)
	A[1,1] = x
	A[2,2] = x
	det(A)
end
```
"""

# ╔═╡ a1714691-abc4-453e-b187-186ac91bfdd8
function h2(x)
	A = zeros(typeof(x), 2, 2)
	@show typeof(A)
	A[1,1] = x
	A[2,2] = x
	det(A)
end

# ╔═╡ dc75174d-bee2-492c-bb69-0b7825030258
δ(h2, 2.0)

# ╔═╡ b1bed2cc-3112-4dad-92bd-61e665df141b
Enzyme.gradient(Forward, h2, 2.0)

# ╔═╡ cc14f4d0-3392-4350-85e3-65902bb5f224
md"""
!!! note
    Enzyme forms **shadows** of memory allocations.
"""

# ╔═╡ c3392c39-5d2b-4141-85b6-da0b59e23eeb
md"""
## Jacobian

$f: \mathbb{R}^n\rightarrow\mathbb{R}^m$

```math
J = \begin{bmatrix}
  \frac{\partial f_1}{\partial x_1} & 
    \cdots & 
    \frac{\partial f_1}{\partial x_n} \\[1ex] % <-- 1ex more space between rows of matrix
   \vdots & 
    \ddots & 
    \vdots \\[1ex]
  \frac{\partial f_m}{\partial x_1} & 
    \cdots & 
    \frac{\partial f_m}{\partial x_n}
\end{bmatrix}
```

!!! note
    In scientific programming with often the jacobian (or a higher order variant thereof). We can think of **forward**-mode as performing a jacobian-vector-product. Equivalently **reverse**-mode is the same as performing a jacobian-transpose-vector-product.
"""

# ╔═╡ e8da9ea0-d6ff-4669-9d1f-78a1ac12385b
md"""
## Symbolic (Jacobian)
"""

# ╔═╡ 640b75b0-5050-4540-a470-3d0855aa96ac
begin
	@variables X[2]
	ex_F = F(X)
	Symbolics.jacobian(ex_F, X; scalarize=false)
end

# ╔═╡ f346a136-670d-4264-bfb0-d1f4bf0528e7
md"""
## Enzyme.jl (Jacobian)
"""

# ╔═╡ 83c6e894-c423-4713-a434-e66606eeddf4
Enzyme.jacobian(Forward, F, [1.0, 1.0]) |> only

# ╔═╡ da9f01a7-d02e-4191-b209-d9bf17337f5c
md"""
## Seeds / Directional derivatives

We can think of seeds as a vector $v$ that selects a column to extract from the Jacobian, by performing $Jv$ a Jacobian vector product. So using `autodiff` we can extract the Jacobian of a program.
"""

# ╔═╡ 1c3d05e3-a95e-4307-b21f-73355fc9cfaf
md"""
In many texts you will find the directional derivatives approximated using a finite-difference operation.


$\frac{F(u + \epsilon \cdot v) - F(u)}{\epsilon}$
"""

# ╔═╡ 32c19626-6d30-48a2-9d71-bc15ce69512f
function finite_differences_directional(F, u, v, ϵ = sqrt(eps()))
	(F(u .+ v .* ϵ) .- F(u)) ./ ϵ
end

# ╔═╡ 4e8982fd-e2b5-484c-be89-b94be5225ab7
finite_differences_directional(F, [1.0, 1.0], [1.0, 0.0])

# ╔═╡ e33abaac-3843-4dfd-a719-d9feed5ce547
finite_differences_directional(F, [1.0, 1.0], [0.0, 1.0])

# ╔═╡ 119dc126-b00e-4379-9214-82c8311cfd77
md"""
## Using Enzyme (generalized)

$w = J*v$

```
autodiff(Forward, G!, Duplicated(out, w), Duplicated(in, v))
```

$w = v*J$


```
autodiff(Reverse, G!, Duplicated(out, copy(v)), Duplicated(in, w))
```

!!! note
    Enzyme zeros the shadow-inputs. 
    Necessitating the `copy(v)`
"""

# ╔═╡ 30bcef0b-abcb-46d4-84e2-820e40d3aa6c
md"""
## Reverse vs Forward mode
"""

# ╔═╡ 9e8ff58b-9f5b-4d44-9f5c-8da56ce07408
J = Enzyme.jacobian(Forward, G, [1.0, 1.0]) |> only

# ╔═╡ b59663af-5e25-4cd6-956c-c480801efb4b
begin
	x1 = rand(2)
	x2 = rand(3)
end

# ╔═╡ ebd3712f-d1ea-47a4-8cb9-e054760cc1a6
J*x1

# ╔═╡ 771856d1-8166-4a81-a55b-500367c115a6
let
	res = [0.0, 0.0, 0.0]
	dres = zero(res)
	autodiff(Forward, G!, Duplicated(res, dres), Duplicated([1.0, 1.0], x1))
	dres
end

# ╔═╡ 3b3b143a-c8a7-4ebb-869c-18b1dce3df76
transpose(J)*x2

# ╔═╡ d31661c3-a16e-4b2d-b45d-98368e8fd8d6
let
	res = [0.0, 0.0, 0.0]
	dx = zeros(2)
	autodiff(Enzyme.Reverse, G!, Duplicated(res, x2), Duplicated([1.0, 1.0], dx))
	dx
end

# ╔═╡ e3e0f0b7-478c-41c5-923c-f00c39b0f16f
md"""
## Flavors of AD
- ``\color{purple}{\textbf{Forward-Mode}}``: Perform the shadow computation alongside and in the same order as the instructions in the original program. Propagate the derivative from the inputs to the outputs. Lets you compute the derivative of all outputs with respect to a single input.

- ``\color{blue}{\textbf{Reverse-Mode}}``: Perform the shadow computation in the opposite order as the instructions in the original program. Propagate the derivative from the outputs to the inputs. Lets you compute the derivative of a single output with respect to all inputs.

    - More common in machine learning as it lets you take the gradient with respect to all input weights/biases in a single sweep.


$(LocalResource("./fwd_backward.png"))

"""

# ╔═╡ b406e424-a761-4df8-8f6a-d517f0de9fdb
md"""
## Matrix-free methods
"""

# ╔═╡ 9cbce389-05a2-4848-b452-0d8c89583c43
function maybe_duplicated(f, df)
    if !Enzyme.Compiler.guaranteed_const(typeof(f))
        return Duplicated(f, df)
    else
        return Const(f)
    end
end

# ╔═╡ 03cfe8d0-2556-4488-8220-b2b30a967141
begin
	struct JacobianOperator{F, A}
	    f::F # res = F(u)
	    u::A
		res::A
	end
	JacobianOperator(F, u) = JacobianOperator(F, u, F(u))
end

# ╔═╡ fda2e02f-3efb-45bd-b81c-02af941623cf
begin
	Base.size(J::JacobianOperator) = (length(J.res), length(J.u))
	Base.eltype(J::JacobianOperator) = eltype(J.u)
end

# ╔═╡ f955fca1-f8ca-434a-9b74-a7a7053858a9
function LinearAlgebra.mul!(out, J::JacobianOperator, v)
    f_cache = Enzyme.make_zero(J.f)
    dres = autodiff(
        Forward,
        maybe_duplicated(J.f, f_cache), Duplicated,
        Duplicated(J.u, reshape(v, size(J.u)))
    ) |> only
	out .= dres
    return nothing
end

# ╔═╡ f33cc185-1249-4c37-8a5c-324734376857
function Base.collect(JOp::JacobianOperator)
    N, M = size(JOp)
    v = zeros(eltype(JOp), M)
    out = zeros(eltype(JOp), N)
    J = SparseMatrixCSC{eltype(v), Int}(undef, size(JOp)...)
    for j in 1:M
        out .= 0.0
        v .= 0.0
        v[j] = 1.0
        mul!(out, JOp, v)
        for i in 1:N
            if out[i] != 0
                J[i, j] = out[i]
            end
        end
    end
    return J
end

# ╔═╡ 0157fb81-15f4-46ec-9a2c-7be29dde43e8
function plot_gradientfield(N, S, x₀, y, θ₁, θ₂, n)
    θ_space = collect(Iterators.product(θ₁, θ₂))
    gradient_field = ∇simulate.(N, S, x₀, y, θ_space, n)

    fig, ax, hm = heatmap(
        θ₁, θ₂, map(x -> sqrt(x[1]^2 + x[2]^2), gradient_field),
        colorscale = log10,
        colormap = Makie.Reverse(:Blues),
        colorrange = (10^-3, 10^3)
    )
    Colorbar(fig[:, end + 1], hm)

    streamplot!(
        ax, (θ) -> -∇simulate(N, S, x₀, y, θ, n), θ₁, θ₂,
        alpha = 0.5,
        colorscale = log10, color = p -> :red,
        arrow_size = 10
    )
    return fig
end

# ╔═╡ 92ec7201-88f2-404c-a948-717433c319e6
let
	x₀ = -0.3
    y = 2.0
    n = 4

    θ₁ = -4:0.01:4
    θ₂ = -4:0.01:4
    θ_space = collect(Iterators.product(θ₁, θ₂))

	L_space = simulate.(N, S, x₀, y, θ_space, n);

	fig = Figure(size = (1000, 400))
	ax = Axis(fig[1,1], title="Loss landscape", xlabel="θ₁", ylabel="θ₂")
	
    hm = heatmap!(ax,
        θ₁, θ₂, L_space,
        colorscale = log10,
        colormap = Makie.Reverse(:Blues),
        colorrange = (10^-5, 10^5)
    )
    Colorbar(fig[1, 2], hm)

	gradient_field = ∇simulate.(N, S, x₀, y, θ_space, n)
	ax2 = Axis(fig[1, 3], title="Gradient landscape", xlabel="δθ₁", ylabel="δθ₂")

	hm = heatmap!(ax2,
        θ₁, θ₂, map(x -> sqrt(x[1]^2 + x[2]^2), gradient_field),
        colorscale = log10,
        colormap = Makie.Reverse(:Blues),
        colorrange = (10^-3, 10^3)
    )
    Colorbar(fig[1, 4], hm)

	streamplot!(ax2,
        (θ) -> -∇simulate(N, S, x₀, y, θ, n), θ₁, θ₂,
        alpha = 0.5,
        colorscale = log10, color = p -> :red,
        arrow_size = 10
    )
    fig
end

# ╔═╡ dfc03456-f2db-4b1b-b38a-0523881a8398
JOp = JacobianOperator(F, [1.0, 1.0])

# ╔═╡ be6e034f-4246-4c50-a71d-448b78b9ad2a
collect(JOp)

# ╔═╡ b582d82b-945c-4c7e-81f7-52fd1b616480
let
	u = zeros(3)
	mul!(u, JOp, x1)
	u
end

# ╔═╡ c2e3e9af-9434-4fbe-a35f-bde32564103d
J*x1

# ╔═╡ 5f5265fe-9790-48fa-8947-876ec161e20b
md"""
## Newton-Krylov

$F(u) = 0$
$J(F, u) * x = -F(u)$

Problems of the form $F(u) = 0$ can be solved with a Newton method, this particular helpful for finding an iterative solution of nonlinear equations.

We can use a Krylov solver "gmres" to solve the linear system $Ax = -b$ without "materializing" $A$. This is called a matrix-free method.
"""

# ╔═╡ 7242500d-d754-4c09-99a4-83f94142e654
function G2(x)
    [
		x[1]^2 + x[2]^2 - 2,
		exp(x[1] - 1) + x[2]^2 - 2
	]
end

# ╔═╡ ab48a94b-f252-4023-b134-548c0870b393
let
	xs = LinRange(-3, 4, 1000)
	ys = LinRange(-5, 5, 1000)
	
	levels = [0.1, 0.25, 0.5:2:10..., 10.0:10:200..., 200:100:4000...]
	
	fig, ax = contour(xs, ys, (x, y) -> norm(G2([x, y])); levels)
	fig
end

# ╔═╡ c2f8cd38-b602-4848-b662-cc5c26a989b4
function newton_krylov!(F, u;
						tol_rel = 1.0e-6,
        				tol_abs = 1.0e-12,
						max_niter = 50,
						callback = x->nothing)
	
	res = F(u)
	n_res = norm(res)
	callback(u)

	tol = tol_rel * n_res + tol_abs
	iter = 0
	
	while n_res > tol && iter <= max_niter
		# Ax = -b
		J = JacobianOperator(F, u, res)
		x, stats = gmres(J, -res)

		# Take a step in the newton direction
		u .+= x

		res = F(u)
		n_res = norm(res)
		callback(u)
		if isinf(n_res) || isnan(n_res)
			error("Solver blew up")
		end
		iter += 1
	end
	return u, (; solved = n_res <= tol, iter)
end

# ╔═╡ da61268e-1be4-44b1-87f1-ba349db93150
trace_1 = let x₀ = [2.0, 0.5]
    xs = Vector{Tuple{Float64, Float64}}(undef, 0)
    hist(x) = (push!(xs, (x[1], x[2])); nothing)
    _ = newton_krylov!(G2, x₀, callback = hist)
	xs
end

# ╔═╡ fdebd8ba-beac-4025-97a2-af232c8d6471
trace_2 = let x₀ = [2.5, 3.0]
    xs = Vector{Tuple{Float64, Float64}}(undef, 0)
    hist(x) = (push!(xs, (x[1], x[2])); nothing)
    newton_krylov!(G2, x₀, callback = hist)
    xs
end

# ╔═╡ eb5d6110-38d6-46ec-b59d-8615afc3f6f7
let
	xs = LinRange(-3, 4, 1000)
	ys = LinRange(-5, 5, 1000)
	
	levels = [0.1, 0.25, 0.5:2:10..., 10.0:10:200..., 200:100:4000...]
	
	fig, ax = contour(xs, ys, (x, y) -> norm(G2([x, y])); levels)
	lines!(ax, trace_1)
	lines!(ax, trace_2)
	fig
end

# ╔═╡ e185f0ea-e0aa-4fb6-aa7b-f7607899b826
md"""
## Conclusion

1. We need to be able to take gradients through scientific programs
2. Scientific programs don't neatly fall into the language of machine learning


!!! note "Other languages"
    Enzyme is not limited to just Julia, but can handle other programming languages (C/C++/Rust/Fortran) as well, as long as they are LLVM based.

$(RobustLocalResource("https://enzyme.mit.edu/all_top.png", "all_top.png"))
"""

# ╔═╡ cbbeeac0-2c1b-43f3-9440-6fcfbf3870fb
md"""
# AD Curiosities
"""

# ╔═╡ 23c423cd-5227-4eec-a1f1-9fb6e209678a
md"""
## What gradient do we choose?
"""

# ╔═╡ f8c80b48-a9a1-443d-8eaf-b87c7a823830
function maximuml(x)
	acc = -Inf
	for i in 1:length(x)
		acc = max(acc, x[i])
	end
	acc
end

# ╔═╡ ae87f7e8-4305-4a86-9f4a-e39cb63a1bed
function maximumr(x)
	acc = -Inf
	for i in length(x):-1:1
		acc = max(acc, x[i])
	end
	acc
end

# ╔═╡ 6fd33e88-4d5e-44e9-a5a7-f90d9956d2fc
maximuml([1.0, 0.0, 1.0])

# ╔═╡ d14f8af2-009e-4eab-af08-7cf3c06d5814
let dx = zeros(3)
	autodiff(Enzyme.Reverse, maximuml, Duplicated([1.0, 0.0, 1.0], dx))
	dx
end

# ╔═╡ 94a1ca60-444e-4d0b-918a-fe228cca25f4
maximumr([1.0, 0.0, 1.0])

# ╔═╡ c9a56f44-0f24-4074-bdf5-219cbe9c015e
let dx = zeros(3)
	autodiff(Enzyme.Reverse, maximumr, Duplicated([1.0, 0.0, 1.0], dx))
	dx
end

# ╔═╡ dc6c220b-8f48-4170-b080-8d3c2bed7422
md"""
!!! note
    The same mathematical operation ("take the maximum") has different gradients depending on the implementation.
"""

# ╔═╡ ed20ead3-9f8f-4b15-8e58-a25417cd72a2
abs_right(x) = x < 0 ? -x : x

# ╔═╡ d438d77a-0828-48c9-865c-0ecb4bc85531
abs_left(x) = x <= 0 ? -x : x

# ╔═╡ 8776d9df-73d0-498a-be5b-c937a33a3c85
function abs_center(x) 
    if x == 0
		return zero(x)
	elseif x < 0
		return -x
	else
		return x
	end
end

# ╔═╡ 34de48ea-2fff-4045-b786-311bab322916
autodiff(Forward, abs_right, Duplicated(0.0,1.0))

# ╔═╡ 36464a69-184f-47ea-bc02-71dd5642423e
autodiff(Forward, abs_left, Duplicated(0.0,1.0))

# ╔═╡ 7818921f-a2f3-46d5-9341-6ee6884692ad
autodiff(Forward, abs_center, Duplicated(0.0,1.0))

# ╔═╡ 899aa533-fdb2-4613-b9b0-95d4703be1ff
md"""
!!! note
    While all three answers differ, they are all correct, and represent a possible sub-gradient that we can choose at that point. 
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
Enzyme = "7da242da-08ed-463a-9acd-ee780be4f1d9"
ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
Krylov = "ba0b0d4f-ebba-5204-a429-3ac8c609bfb7"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
PlutoTeachingTools = "661c6b06-c737-4d37-b85c-46df65de6f69"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
Symbolics = "0c5d862f-8b57-4792-8d23-62f2024744c7"

[compat]
CairoMakie = "~0.15.11"
Enzyme = "~0.13.159"
ForwardDiff = "~1.4.1"
Krylov = "~0.10.6"
PlutoTeachingTools = "~0.4.7"
PlutoUI = "~0.7.83"
Symbolics = "~7.27.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.12.6"
manifest_format = "2.0"
project_hash = "995f324181095f8d326bc29623f64c3b81a4b2c8"

[[deps.ADTypes]]
git-tree-sha1 = "bbc22a9a08a0ef6460041086d8a7b27940ed4ffd"
uuid = "47edcb42-4c32-4615-8424-f2b9edc5f35b"
version = "1.22.0"
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
git-tree-sha1 = "6c3913f4e9bdf6ba3c08041a446fb1332716cbc2"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.4.0"

[[deps.AbstractTrees]]
git-tree-sha1 = "2d9c9a55f9c93e8887ad391fbae72f8ef55e1177"
uuid = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
version = "0.4.5"

[[deps.Accessors]]
deps = ["CompositionsBase", "ConstructionBase", "Dates", "InverseFunctions", "MacroTools"]
git-tree-sha1 = "2eeb2c9bef11013efc6f8f97f32ee59b146b09fb"
uuid = "7d9f7c33-5ae7-4f3b-8dc6-eff91059b697"
version = "0.1.44"

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
git-tree-sha1 = "7715e5b2b186c4d9b664d299d2c9e48b9a778c88"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "4.6.1"
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

[[deps.ArnoldiMethod]]
deps = ["LinearAlgebra", "Random", "StaticArrays"]
git-tree-sha1 = "d57bd3762d308bded22c3b82d033bff85f6195c6"
uuid = "ec485272-7323-5ecc-a04f-4719b315124d"
version = "0.4.0"

[[deps.ArrayInterface]]
deps = ["Adapt", "LinearAlgebra"]
git-tree-sha1 = "3d0cabd25fab32390e3bcb82cd67e700aebd9816"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "7.25.0"

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
git-tree-sha1 = "bca794632b8a9bbe159d56bf9e31c422671b35e0"
uuid = "18cc8868-cbac-4acf-b575-c8ff214dc66f"
version = "1.3.2"

[[deps.Bijections]]
git-tree-sha1 = "a2d308fcd4c2fb90e943cf9cd2fbfa9c32b69733"
uuid = "e2ed5e7c-b2de-5872-ae92-c73ca462fb04"
version = "0.2.2"

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
git-tree-sha1 = "1a063740329b7ee9ec602505c41cccb8500b637d"
uuid = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
version = "0.15.11"

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

[[deps.Combinatorics]]
git-tree-sha1 = "08c8b6831dc00bfea825826be0bc8336fc369860"
uuid = "861a8166-3701-5b0c-9a16-15d98fcdc6aa"
version = "1.0.2"

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
version = "1.3.0+1"

[[deps.CompositeTypes]]
git-tree-sha1 = "bce26c3dab336582805503bed209faab1c279768"
uuid = "b152e2b5-7a66-4b01-a709-34e65c35f657"
version = "0.1.4"

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

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataStructures]]
deps = ["OrderedCollections"]
git-tree-sha1 = "6fb53a69613a0b2b68a0d12671717d307ab8b24e"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.19.5"

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

[[deps.DiffResults]]
deps = ["StaticArraysCore"]
git-tree-sha1 = "782dd5f4561f5d267313f23853baaaa4c52ea621"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.1.0"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "79a2aca180a85c690c58a020d47b426954b590f8"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.16.0"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"
version = "1.11.0"

[[deps.Distributions]]
deps = ["AliasTables", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SpecialFunctions", "Statistics", "StatsAPI", "StatsBase", "StatsFuns"]
git-tree-sha1 = "96f76dcd6cc75cf8eb49109123868499d413f526"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.126"

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

[[deps.DomainSets]]
deps = ["CompositeTypes", "FunctionMaps", "IntervalSets", "LinearAlgebra", "StaticArrays"]
git-tree-sha1 = "1af39efbaf76fb648432b5efaac0d73af6760407"
uuid = "5b8099bc-c8ec-5219-889f-1d9e522a28bf"
version = "0.8.0"
weakdeps = ["Makie", "Random"]

    [deps.DomainSets.extensions]
    DomainSetsMakieExt = "Makie"
    DomainSetsRandomExt = "Random"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.7.0"

[[deps.DynamicPolynomials]]
deps = ["LinearAlgebra", "MultivariatePolynomials", "MutableArithmetics", "Reexport", "StarAlgebras", "Test"]
git-tree-sha1 = "5bfabc3827dfdd164359bad6800c115a81280c00"
uuid = "7c1d4256-1411-5781-91ec-d7bc3513ac07"
version = "0.6.6"

[[deps.EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e3290f2d49e661fbd94046d7e3726ffcb2d41053"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.4+0"

[[deps.EnumX]]
git-tree-sha1 = "c49898e8438c828577f04b92fc9368c388ac783c"
uuid = "4e289a0a-7415-4d19-859d-a7e5c4648b56"
version = "1.0.7"

[[deps.Enzyme]]
deps = ["CEnum", "EnzymeCore", "Enzyme_jll", "GPUCompiler", "InteractiveUtils", "LLVM", "Libdl", "LinearAlgebra", "ObjectFile", "PrecompileTools", "Preferences", "Printf", "Random", "SparseArrays"]
git-tree-sha1 = "adf8d414290092b377af5003be467d30dfb844af"
uuid = "7da242da-08ed-463a-9acd-ee780be4f1d9"
version = "0.13.159"

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
git-tree-sha1 = "c6ee69ee502060982d12dbaaf3d8fcb4e835a0d1"
uuid = "f151be2c-9106-41f4-ab19-57ee4f262869"
version = "0.8.20"
weakdeps = ["Adapt", "ChainRulesCore"]

    [deps.EnzymeCore.extensions]
    AdaptExt = "Adapt"
    EnzymeCoreChainRulesCoreExt = "ChainRulesCore"

[[deps.Enzyme_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl", "TOML"]
git-tree-sha1 = "e382f2b17521367f0bd2c0aeb0d5c52ebd3dbde7"
uuid = "7cc45869-7501-5eee-bdea-0790c847d4ef"
version = "0.0.267+0"

[[deps.ExactPredicates]]
deps = ["IntervalArithmetic", "Random", "StaticArrays"]
git-tree-sha1 = "83231673ea4d3d6008ac74dc5079e77ab2209d8f"
uuid = "429591f6-91af-11e9-00e2-59fbe8cec110"
version = "2.2.9"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c307cd83373868391f3ac30b41530bc5d5d05d08"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.8.1+0"

[[deps.ExprTools]]
git-tree-sha1 = "27415f162e6028e81c72b82ef756bf321213b6ec"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.10"

[[deps.ExproniconLite]]
git-tree-sha1 = "c13f0b150373771b0fdc1713c97860f8df12e6c2"
uuid = "55351af7-c7e9-48d6-89ff-24e801d99491"
version = "0.10.14"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "PCRE2_jll", "Zlib_jll", "libaom_jll", "libass_jll", "libfdk_aac_jll", "libva_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "cac41ca6b2d399adfc95e51240566f8a60a80806"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "8.1.0+0"

[[deps.FFTA]]
deps = ["AbstractFFTs", "DocStringExtensions", "LinearAlgebra", "MuladdMacro", "Primes", "Random", "Reexport"]
git-tree-sha1 = "65e55303b72f4a567a51b174dd2c47496efeb95a"
uuid = "b86e33f2-c0db-4aa1-a6e0-ab43e668529e"
version = "0.3.1"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "8e9c059d6857607253e837730dbf780b6b151acd"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.19.0"

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
deps = ["Random", "Statistics"]
git-tree-sha1 = "59af96b98217c6ef4ae0dfe065ac7c20831d1a84"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.6"

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
git-tree-sha1 = "2c5d0b0e12088cde2cf84afb2784415b1ea3dfee"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "1.4.1"
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

[[deps.FunctionMaps]]
deps = ["CompositeTypes", "LinearAlgebra", "StaticArrays"]
git-tree-sha1 = "31bd99a57edf98990d1c21486032963955450e8d"
uuid = "a85aefff-f8ca-4649-a888-c8e5398bc76c"
version = "0.1.2"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"
version = "1.11.0"

[[deps.GPUCompiler]]
deps = ["ExprTools", "InteractiveUtils", "LLVM", "Libdl", "Logging", "PrecompileTools", "Preferences", "Scratch", "Serialization", "TOML", "Tracy", "UUIDs"]
git-tree-sha1 = "89e84350265efe953c755f91985accc7a42482ad"
uuid = "61eb1bfa-7361-4325-ad38-22787b887f55"
version = "1.22.0"

    [deps.GPUCompiler.weakdeps]
    LLVMDowngrader_jll = "f52de702-fb25-5922-94ba-81dd59b07444"
    NVPTX_LLVM_Backend_jll = "ef6e0fe3-e6ef-59c0-bde6-4989574699e0"

[[deps.GeometryBasics]]
deps = ["EarCut_jll", "LinearAlgebra", "PrecompileTools", "Random", "StaticArrays"]
git-tree-sha1 = "364685f5ffde25deb1bbcfd5bb278a5c6b7a9b37"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.5.11"

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
git-tree-sha1 = "69ffb934a5c5b7e086a0b4fee3427db2556fba6e"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.16+0"

[[deps.Graphs]]
deps = ["ArnoldiMethod", "DataStructures", "Inflate", "LinearAlgebra", "Random", "SimpleTraits", "SparseArrays", "Statistics"]
git-tree-sha1 = "7eb45fe833a5b7c51cf6d89c5a841d5967e44be3"
uuid = "86223c79-3864-5bf0-83f7-82e725a168b6"
version = "1.14.0"
weakdeps = ["Distributed", "SharedArrays"]

    [deps.Graphs.extensions]
    GraphsSharedArraysExt = "SharedArrays"

[[deps.GridLayoutBase]]
deps = ["GeometryBasics", "InteractiveUtils", "Observables"]
git-tree-sha1 = "93d5c27c8de51687a2c70ec0716e6e76f298416f"
uuid = "3955a311-db13-416c-9275-1d80ed98e5e9"
version = "0.11.2"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll"]
git-tree-sha1 = "f923f9a774fcf3f5cb761bfa43aeadd689714813"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "8.5.1+0"

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

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

[[deps.Interpolations]]
deps = ["Adapt", "AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "48922d06068130f87e43edef52382e6a94305ae6"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.16.3"
weakdeps = ["ForwardDiff", "Unitful"]

    [deps.Interpolations.extensions]
    InterpolationsForwardDiffExt = "ForwardDiff"
    InterpolationsUnitfulExt = "Unitful"

[[deps.IntervalArithmetic]]
deps = ["CRlibm", "CoreMath", "MacroTools", "OpenBLASConsistentFPCSR_jll", "Printf", "Random", "RoundingEmulator"]
git-tree-sha1 = "921d7e91687e15a2c7c269c226960491fc041832"
uuid = "d1acc4aa-44c8-5952-acd4-ba5d80a2a253"
version = "1.0.9"

    [deps.IntervalArithmetic.extensions]
    IntervalArithmeticArblibExt = "Arblib"
    IntervalArithmeticDiffRulesExt = "DiffRules"
    IntervalArithmeticForwardDiffExt = "ForwardDiff"
    IntervalArithmeticIntervalSetsExt = "IntervalSets"
    IntervalArithmeticIrrationalConstantsExt = "IrrationalConstants"
    IntervalArithmeticLinearAlgebraExt = "LinearAlgebra"
    IntervalArithmeticRecipesBaseExt = "RecipesBase"
    IntervalArithmeticSparseArraysExt = "SparseArrays"

    [deps.IntervalArithmetic.weakdeps]
    Arblib = "fb37089c-8514-4489-9461-98f9c8763369"
    DiffRules = "b552c78f-8df3-52c6-915a-8e097449b14b"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    IrrationalConstants = "92d709cd-6900-40b7-9082-c6be49f344b6"
    LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
    RecipesBase = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.IntervalSets]]
git-tree-sha1 = "79d6bd28c8d9bccc2229784f1bd637689b256377"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.7.14"
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
git-tree-sha1 = "7204148362dafe5fe6a273f855b8ccbe4df8173e"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.8.0"

[[deps.JSON]]
deps = ["Dates", "Logging", "Parsers", "PrecompileTools", "StructUtils", "UUIDs", "Unicode"]
git-tree-sha1 = "c89d196f5ffb64bfbf80985b699ea913b0d2c211"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "1.6.1"

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
git-tree-sha1 = "c0c9b76f3520863909825cbecdef58cd63de705a"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.1.5+0"

[[deps.JuliaSyntaxHighlighting]]
deps = ["StyledStrings"]
uuid = "ac6e5ff7-fb65-4e79-a425-ec3bc9c03011"
version = "1.12.0"

[[deps.KernelDensity]]
deps = ["Distributions", "DocStringExtensions", "FFTA", "Interpolations", "StatsBase"]
git-tree-sha1 = "9eda8292dd3268b3b7ec9df21bbfac24e177ec52"
uuid = "5ab0869b-81aa-558d-bb23-cbf5423bbe9b"
version = "0.6.12"

[[deps.Krylov]]
deps = ["LinearAlgebra", "Printf", "SparseArrays"]
git-tree-sha1 = "c4d19f51afc7ba2afbe32031b8f2d21b11c9e26e"
uuid = "ba0b0d4f-ebba-5204-a429-3ac8c609bfb7"
version = "0.10.6"

[[deps.LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "059aabebaa7c82ccb853dd4a0ee9d17796f7e1bc"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.3+0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "17b94ecafcfa45e8360a4fc9ca6b583b049e4e37"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "4.1.0+0"

[[deps.LLVM]]
deps = ["CEnum", "LLVMExtra_jll", "Libdl", "PrecompileTools", "Preferences", "Printf", "Unicode"]
git-tree-sha1 = "57639f07d4670fc6537e97d2686c4c99c13fdd67"
uuid = "929cbde3-209d-540e-8aea-75f648917ca0"
version = "9.9.0"

    [deps.LLVM.extensions]
    BFloat16sExt = "BFloat16s"

    [deps.LLVM.weakdeps]
    BFloat16s = "ab4f0b2a-ad5b-11e8-123f-65d77653426b"

[[deps.LLVMExtra_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl", "TOML"]
git-tree-sha1 = "70c96f133c78c3cdc06234157144fab3744c6b38"
uuid = "dad2f222-ce93-54a1-a47d-0025e8a3acab"
version = "0.0.43+1"

[[deps.LLVMOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "eb62a3deb62fc6d8822c0c4bef73e4412419c5d8"
uuid = "1d63c593-3942-5779-bab2-d838dc0a180e"
version = "18.1.8+0"

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

[[deps.LazyModules]]
git-tree-sha1 = "a560dd966b386ac9ae60bdd3a3d3a326062d3c3e"
uuid = "8cdb02fc-e678-4876-92c5-9defec4f444e"
version = "0.3.1"

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

[[deps.LibTracyClient_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "d4e20500d210247322901841d4eafc7a0c52642d"
uuid = "ad6e5548-8b26-5c9f-8ef3-ef0ad883f3a5"
version = "0.13.1+0"

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
git-tree-sha1 = "f04133fe05eff1667d2054c53d59f9122383fe05"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.7.2+0"

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
git-tree-sha1 = "1cdb9a8ca42229d1ff880ce85e9b31ef2291bce3"
uuid = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
version = "0.24.11"

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

[[deps.Moshi]]
deps = ["ExproniconLite", "Jieko"]
git-tree-sha1 = "999dfa2b4f8334c1c23bd307c2b0cb6f97c54591"
uuid = "2e0e35c7-a2e4-4343-998d-7ef72827ed2d"
version = "0.3.8"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2025.11.4"

[[deps.MuladdMacro]]
git-tree-sha1 = "cac9cc5499c25554cba55cd3c30543cff5ca4fab"
uuid = "46d2c3a1-f734-5fdb-9937-b9b9aeba4221"
version = "0.2.4"

[[deps.MultivariatePolynomials]]
deps = ["DataStructures", "LinearAlgebra", "MutableArithmetics", "StarAlgebras"]
git-tree-sha1 = "4838893d9b035c2f6967c0d533350e1755b58a70"
uuid = "102ac46a-7ee4-5c85-9060-abc95bfdeaa3"
version = "0.5.19"
weakdeps = ["ChainRulesCore"]

    [deps.MultivariatePolynomials.extensions]
    MultivariatePolynomialsChainRulesCoreExt = "ChainRulesCore"

[[deps.MutableArithmetics]]
deps = ["LinearAlgebra", "SparseArrays", "Test"]
git-tree-sha1 = "dc5b2c4c111c46bc79ac4405eeb563523b39c004"
uuid = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"
version = "1.8.0"

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

[[deps.ObjectFile]]
deps = ["Reexport", "StructIO"]
git-tree-sha1 = "22faba70c22d2f03e60fbc61da99c4ebfc3eb9ba"
uuid = "d8793406-e978-5875-9003-1fc021f44a92"
version = "0.5.0"

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
git-tree-sha1 = "3287ec88df50429a934ebc6cf14606215e27b987"
uuid = "6cdc7f73-28fd-5e50-80fb-958a8875b1af"
version = "0.3.33+0"

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
git-tree-sha1 = "4a33fd64a77949468187339d8b10c44a422082f1"
uuid = "18a262bb-aa17-5467-a713-aee519bc75cb"
version = "3.4.12+0"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.7+0"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.5.4+0"

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
git-tree-sha1 = "e4cff168707d441cd6bf3ff7e4832bdf34278e4a"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.37"
weakdeps = ["StatsBase"]

    [deps.PDMats.extensions]
    StatsBaseExt = "StatsBase"

[[deps.PNGFiles]]
deps = ["Base64", "CEnum", "ImageCore", "IndirectArrays", "OffsetArrays", "libpng_jll"]
git-tree-sha1 = "32b657a0d57c310a1a172bfc8c8cf68c5e674323"
uuid = "f57f5aa1-a3ce-4bc8-8ab9-96f992907883"
version = "0.4.5"

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
git-tree-sha1 = "58e5ed5e386e156bd93e86b305ebd21ac63d2d04"
uuid = "36c8627f-9965-5494-a995-c6b170f724f3"
version = "1.57.1+0"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "32a4e09c5f29402573d673901778a0e03b0807b9"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.6"

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

[[deps.Primes]]
deps = ["IntegerMathUtils"]
git-tree-sha1 = "25cdd1d20cd005b52fc12cb6be3f75faaf59bb9b"
uuid = "27ebfcd6-29c5-5fa9-bf4b-fb8fc14df3ae"
version = "0.5.7"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"
version = "1.11.0"

[[deps.ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "fbb92c6c56b34e1a2c4c36058f68f332bec840e7"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.11.0"

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
weakdeps = ["Enzyme"]

    [deps.QuadGK.extensions]
    QuadGKEnzymeExt = "Enzyme"

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

[[deps.ReadOnlyArrays]]
git-tree-sha1 = "e6f7ddf48cf141cb312b078ca21cb2d29d0dc11d"
uuid = "988b38a3-91fc-5605-94a2-ee2116b3bd83"
version = "0.2.0"

[[deps.RecipesBase]]
deps = ["PrecompileTools"]
git-tree-sha1 = "5c3d09cc4f31f5fc6af001c250bf1278733100ff"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.3.4"

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
git-tree-sha1 = "28154d426e557495aa75097861b18c11f2541ded"
uuid = "7e49a35a-f44a-4d26-94aa-eba1b4ca6b47"
version = "0.5.19"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SIMD]]
deps = ["PrecompileTools"]
git-tree-sha1 = "e24dc23107d426a096d3eae6c165b921e74c18e4"
uuid = "fdea26ae-647d-5447-a871-4b548cad5224"
version = "3.7.2"

[[deps.SciMLPublic]]
git-tree-sha1 = "0ba076dbdce87ba230fff48ca9bca62e1f345c9b"
uuid = "431bcebd-1456-4ced-9d72-93c2757fff0b"
version = "1.0.1"

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
git-tree-sha1 = "64d974c2e6fdf07f8155b5b2ca2ffa9069b608d9"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.2"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.12.0"

[[deps.SpecialFunctions]]
deps = ["IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "6547cbdd8ce32efba0d21c5a40fa96d1a3548f9f"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.8.0"
weakdeps = ["ChainRulesCore"]

    [deps.SpecialFunctions.extensions]
    SpecialFunctionsChainRulesCoreExt = "ChainRulesCore"

[[deps.StableRNGs]]
deps = ["Random"]
git-tree-sha1 = "4f96c596b8c8258cc7d3b19797854d368f243ddc"
uuid = "860ef19b-820b-49d6-a774-d7a799459cd3"
version = "1.0.4"

[[deps.StackViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "be1cf4eb0ac528d96f5115b4ed80c26a8d8ae621"
uuid = "cae243ae-269e-4f55-b966-ac2d0dc13c15"
version = "0.1.2"

[[deps.StarAlgebras]]
deps = ["LinearAlgebra", "MutableArithmetics", "SparseArrays"]
git-tree-sha1 = "235b1f9d287bbf34083b3d0829343a7942c0ad1c"
uuid = "0c0c59c1-dc5f-42e9-9a8b-b5dc384a6cd1"
version = "0.3.0"

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
git-tree-sha1 = "e4d7a1a0edc20af42689ea6f4f3587a2175d50ee"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.34.12"

[[deps.StatsFuns]]
deps = ["HypergeometricFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "91f091a8716a6bb38417a6e6f274602a19aaa685"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "1.5.2"
weakdeps = ["ChainRulesCore", "InverseFunctions"]

    [deps.StatsFuns.extensions]
    StatsFunsChainRulesCoreExt = "ChainRulesCore"
    StatsFunsInverseFunctionsExt = "InverseFunctions"

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

[[deps.StructIO]]
git-tree-sha1 = "c581be48ae1cbf83e899b14c07a807e1787512cc"
uuid = "53d494c1-5632-5724-8f4c-31dff12d585f"
version = "0.3.1"

[[deps.StructUtils]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "82bee338d650aa515f31866c460cb7e3bcef90b8"
uuid = "ec057cc2-7a8d-4b58-b3b3-92acb9f63b42"
version = "2.8.2"

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

[[deps.SymbolicIndexingInterface]]
deps = ["Accessors", "ArrayInterface", "RuntimeGeneratedFunctions", "StaticArraysCore"]
git-tree-sha1 = "64b15330b9e3c91a86bcac92f369c58e382981c6"
uuid = "2efcf032-c050-4f8e-a9bb-153293bab1f5"
version = "0.3.48"

    [deps.SymbolicIndexingInterface.extensions]
    SymbolicIndexingInterfacePrettyTablesExt = "PrettyTables"

    [deps.SymbolicIndexingInterface.weakdeps]
    PrettyTables = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"

[[deps.SymbolicLimits]]
deps = ["SymbolicUtils", "TermInterface"]
git-tree-sha1 = "5085671d2cba1eb02136a3d6661c583e801984c1"
uuid = "19f23fe9-fdab-4a78-91af-e7b7767979c3"
version = "1.1.0"

[[deps.SymbolicUtils]]
deps = ["AbstractTrees", "ArrayInterface", "Combinatorics", "ConstructionBase", "DataStructures", "DocStringExtensions", "DynamicPolynomials", "EnumX", "ExproniconLite", "Graphs", "LinearAlgebra", "MacroTools", "Moshi", "MultivariatePolynomials", "MutableArithmetics", "NaNMath", "PrecompileTools", "ReadOnlyArrays", "Setfield", "SparseArrays", "SpecialFunctions", "StaticArraysCore", "SymbolicIndexingInterface", "TaskLocalValues", "TermInterface", "WeakCacheSets"]
git-tree-sha1 = "a6e3bc627252da68a6aa95746b47c7da4bfd9c39"
uuid = "d1185830-fcd6-423d-90d6-eec64667417b"
version = "4.35.1"

    [deps.SymbolicUtils.extensions]
    SymbolicUtilsChainRulesCoreExt = "ChainRulesCore"
    SymbolicUtilsDistributionsExt = "Distributions"
    SymbolicUtilsLabelledArraysExt = "LabelledArrays"
    SymbolicUtilsReverseDiffExt = "ReverseDiff"

    [deps.SymbolicUtils.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
    LabelledArrays = "2ee39098-c373-598a-b85f-a56591580800"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"

[[deps.Symbolics]]
deps = ["ADTypes", "AbstractPlutoDingetjes", "ArrayInterface", "Bijections", "CommonWorldInvalidations", "ConstructionBase", "DataStructures", "DiffRules", "DocStringExtensions", "DomainSets", "DynamicPolynomials", "Libdl", "LinearAlgebra", "LogExpFunctions", "MacroTools", "Markdown", "Moshi", "MultivariatePolynomials", "MutableArithmetics", "NaNMath", "PrecompileTools", "Preferences", "Primes", "RecipesBase", "Reexport", "RuntimeGeneratedFunctions", "SciMLPublic", "Setfield", "SparseArrays", "SpecialFunctions", "StaticArraysCore", "SymbolicIndexingInterface", "SymbolicLimits", "SymbolicUtils", "TermInterface"]
git-tree-sha1 = "cf0102f99cd7750851483aaed78ad565991037c4"
uuid = "0c5d862f-8b57-4792-8d23-62f2024744c7"
version = "7.27.0"

    [deps.Symbolics.extensions]
    SymbolicsD3TreesExt = "D3Trees"
    SymbolicsDistributionsExt = "Distributions"
    SymbolicsForwardDiffExt = "ForwardDiff"
    SymbolicsGroebnerExt = "Groebner"
    SymbolicsHypergeometricFunctionsExt = "HypergeometricFunctions"
    SymbolicsLatexifyExt = ["Latexify", "LaTeXStrings"]
    SymbolicsNemoExt = "Nemo"
    SymbolicsPreallocationToolsExt = ["PreallocationTools", "ForwardDiff"]
    SymbolicsSymPyExt = "SymPy"
    SymbolicsSymPyPythonCallExt = "SymPyPythonCall"

    [deps.Symbolics.weakdeps]
    D3Trees = "e3df1716-f71e-5df9-9e2d-98e193103c45"
    Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    Groebner = "0b43b601-686d-58a3-8a1c-6623616c7cd4"
    HypergeometricFunctions = "34004b35-14d8-5ef3-9330-4cdb6864b03a"
    LaTeXStrings = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
    Latexify = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
    Nemo = "2edaba10-b0f1-5616-af89-8c11ac63239a"
    PreallocationTools = "d236fae5-4411-538c-8e31-a6e3d9e00b46"
    SymPy = "24249f21-da20-56a4-8eb1-6a02cf4ae2e6"
    SymPyPythonCall = "bc8888f7-b21e-4b7c-a06a-5d9c9496438c"

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

[[deps.TaskLocalValues]]
git-tree-sha1 = "67e469338d9ce74fc578f7db1736a74d93a49eb8"
uuid = "ed4db957-447d-4319-bfb6-7fa9ae7ecf34"
version = "0.1.3"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.TermInterface]]
git-tree-sha1 = "d673e0aca9e46a2f63720201f55cc7b3e7169b16"
uuid = "8ea1fca8-c5ef-4a55-8b96-4e9afe9c9a3c"
version = "2.0.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
version = "1.11.0"

[[deps.TiffImages]]
deps = ["CodecZstd", "ColorTypes", "DataStructures", "DocStringExtensions", "FileIO", "FixedPointNumbers", "IndirectArrays", "Inflate", "Mmap", "OffsetArrays", "PkgVersion", "PrecompileTools", "ProgressMeter", "SIMD", "UUIDs"]
git-tree-sha1 = "9ca5f1f2d42f80df4b8c9f6ab5a64f438bbd9976"
uuid = "731e570b-9d59-4bfa-96dc-6df516fadf69"
version = "0.11.9"

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

[[deps.TriplotBase]]
git-tree-sha1 = "4d4ed7f294cda19382ff7de4c137d24d16adc89b"
uuid = "981d1d27-644d-49a2-9326-4793e63143c3"
version = "0.1.0"

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

[[deps.WeakCacheSets]]
git-tree-sha1 = "386050ae4353310d8ff9c228f83b1affca2f7f38"
uuid = "d30d5f5c-d141-4870-aa07-aabb0f5fe7d5"
version = "0.1.0"

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

[[deps.XZ_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "b29c22e245d092b8b4e8d3c09ad7baa586d9f573"
uuid = "ffd25f8a-64ca-5728-b0f7-c24cf3aae800"
version = "5.8.3+0"

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
git-tree-sha1 = "850b06095ee71f0135d644ffd8a52850699581ed"
uuid = "a4ae2306-e953-59d6-aa16-d00cac43593b"
version = "3.13.3+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "125eedcb0a4a0bba65b657251ce1d27c8714e9d6"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.17.4+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.15.0+0"

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
# ╠═665c5ded-f7ad-4a4c-a295-69f82aab5495
# ╠═00c1a967-c4e2-44e8-b6f9-85ea65c654be
# ╠═2f59050b-d630-4a3a-8aa1-3c2e9a70c66f
# ╟─b0448824-81ea-11f0-3d7a-bd269696aca6
# ╟─4753cb46-803b-4c4c-a0ed-9e960238ae1b
# ╟─35319c71-404a-495b-8555-d8de85de255c
# ╟─e7b23248-4475-4ae2-bb8f-88af5c76dc67
# ╟─177bd814-0795-48fb-8049-ce8d12bf1025
# ╠═de43f959-683c-44e5-8836-8239a0386997
# ╠═cac6333c-caa3-4eef-8462-b62d8b802d3d
# ╟─4876df7e-0545-41d6-83ff-56f629ad85c0
# ╟─0157fb81-15f4-46ec-9a2c-7be29dde43e8
# ╟─92ec7201-88f2-404c-a948-717433c319e6
# ╟─3e17838b-83c0-4b78-a5a5-44587a984bae
# ╟─dade7d3c-4b53-4f7a-a63b-82d338512557
# ╟─db23cb48-9fc1-40f1-b3f9-96025a5a2343
# ╟─49f8208e-20fd-438d-804f-3f44359fc6a6
# ╟─95776f94-e0e5-4a72-8a48-f16e177a750b
# ╠═01847641-ce9c-4717-add6-68a091fe9bb6
# ╟─eb358263-a6dc-4971-b13a-7fb1ac897549
# ╟─ac00a927-cf53-4176-aa58-3ae99203f6ab
# ╠═5eca6a6c-ebf1-4c5f-b51b-9086e1526d0a
# ╟─f487a3f1-bfdb-4ea6-9a82-cc8c7ece298a
# ╠═edc136c6-db1d-48c5-a619-dd5565198989
# ╟─a8301438-511d-462c-a759-6c5a1bf9d801
# ╟─52f4e73a-7a3f-48fc-9994-4c18661910c7
# ╟─fae1668d-9761-4e83-968b-a90266b442de
# ╠═3b36bab3-b7b3-437a-8e63-03b358a290dc
# ╠═f22e0e4b-63e6-4117-b867-fb714b0e8f51
# ╟─ba4b4c9b-7b49-4afc-9815-abebb8173611
# ╟─49b152ce-918c-4fa9-a0c9-94ff78be9d98
# ╠═9d422306-9c7b-4efd-bd8d-a0b80dcc139a
# ╠═d194abf2-0e47-4a8d-b7ac-1f5192abdbb2
# ╠═becd3850-1474-49ad-ba58-a0723ddafe9d
# ╠═691bb998-b0f4-421e-b697-e722e971d280
# ╠═dba428fe-700b-429a-a4b9-c91f9f2f49d7
# ╠═94de6dad-68ea-4d5e-a76e-ef0829310edc
# ╟─ad79adf5-c03d-4499-8258-b1add2f6c636
# ╟─14b40f50-defd-420c-86da-59a3084113f9
# ╠═4bf55868-449e-4c37-a07c-68479a772b70
# ╠═fd8b95b8-cefe-42ab-a7d0-a9b84471d66f
# ╟─ce2631c0-ea8b-4faa-8a4a-5908f87bf760
# ╠═771e861c-3d35-4cfc-996f-a937acef3189
# ╟─e62da3de-de5a-4c5f-b943-975c1971b728
# ╟─76904814-1460-4e60-a8d2-1bbb188196b8
# ╟─b89e6d57-050d-4373-8c48-afcf5c1e6abe
# ╟─1762c7cc-4a7d-43af-86d5-fb94e9afa4c2
# ╟─b4ff8899-4ac2-4c48-b2b3-3a25d8a64d70
# ╟─1be367e1-0b24-4566-829d-b1769fe0c9e8
# ╟─94ac531b-7403-47a4-b657-895747401876
# ╠═8e9fc1cb-44de-4280-bcc6-f03be7a47a29
# ╠═7070c213-922c-4858-820f-40e8b80c3cbc
# ╟─c6f19816-6e5c-4a4d-9cb3-891055c9fae7
# ╟─526cbd5e-0eca-4c8b-8ae7-ecdc00395abe
# ╠═d2dc99f2-0892-487f-9b6a-fe224714a8f2
# ╠═a865bc58-8817-48a6-a52b-515646f6cee0
# ╟─e568f24a-3694-4cb5-8958-db00643b7fcf
# ╠═ca574392-a993-48e0-ac0e-5a2ff8809689
# ╠═3b858db5-3b5f-465e-9901-2570a8213419
# ╠═ec6157b9-0d3b-4e96-a098-e65044716db8
# ╟─a280de28-b0e5-4770-a751-78353a692354
# ╠═aa1d34de-244c-4254-8b82-7fa30767f969
# ╟─bf7dc379-2d87-4df2-a8ae-05299d604617
# ╠═ae5bb7ac-ade2-4ef9-8d83-84cf3215612c
# ╠═349eaea0-8ff0-4945-a0f7-ba9bd9dc23e8
# ╠═a2aac3a8-54ac-449a-8bc7-c6375263a102
# ╠═c1766483-9d4e-4ac9-9cf4-eb8a680fac71
# ╟─4d69e335-d027-4ddc-9d7c-2be3ce79e0c5
# ╠═94d246de-d120-4d66-879f-f28076489dea
# ╠═6dad4e2a-8521-4169-bfbd-a62991d53b5a
# ╟─bbccea64-cc3b-45eb-a816-ef2f4ac09a5e
# ╟─3b3d3bd4-2242-4941-9331-be465b80b778
# ╟─3fcc4381-dd86-4989-9adf-581fcd8b4eae
# ╠═a1714691-abc4-453e-b187-186ac91bfdd8
# ╠═dc75174d-bee2-492c-bb69-0b7825030258
# ╠═b1bed2cc-3112-4dad-92bd-61e665df141b
# ╟─cc14f4d0-3392-4350-85e3-65902bb5f224
# ╟─c3392c39-5d2b-4141-85b6-da0b59e23eeb
# ╟─e8da9ea0-d6ff-4669-9d1f-78a1ac12385b
# ╠═640b75b0-5050-4540-a470-3d0855aa96ac
# ╟─f346a136-670d-4264-bfb0-d1f4bf0528e7
# ╠═83c6e894-c423-4713-a434-e66606eeddf4
# ╟─da9f01a7-d02e-4191-b209-d9bf17337f5c
# ╟─1c3d05e3-a95e-4307-b21f-73355fc9cfaf
# ╠═32c19626-6d30-48a2-9d71-bc15ce69512f
# ╠═4e8982fd-e2b5-484c-be89-b94be5225ab7
# ╠═e33abaac-3843-4dfd-a719-d9feed5ce547
# ╟─119dc126-b00e-4379-9214-82c8311cfd77
# ╟─30bcef0b-abcb-46d4-84e2-820e40d3aa6c
# ╠═9e8ff58b-9f5b-4d44-9f5c-8da56ce07408
# ╠═b59663af-5e25-4cd6-956c-c480801efb4b
# ╠═ebd3712f-d1ea-47a4-8cb9-e054760cc1a6
# ╠═771856d1-8166-4a81-a55b-500367c115a6
# ╠═3b3b143a-c8a7-4ebb-869c-18b1dce3df76
# ╠═d31661c3-a16e-4b2d-b45d-98368e8fd8d6
# ╟─e3e0f0b7-478c-41c5-923c-f00c39b0f16f
# ╠═b406e424-a761-4df8-8f6a-d517f0de9fdb
# ╠═9cbce389-05a2-4848-b452-0d8c89583c43
# ╠═03cfe8d0-2556-4488-8220-b2b30a967141
# ╠═fda2e02f-3efb-45bd-b81c-02af941623cf
# ╠═f955fca1-f8ca-434a-9b74-a7a7053858a9
# ╠═f488d269-bea7-4a96-b7a6-8aade72aa576
# ╠═f33cc185-1249-4c37-8a5c-324734376857
# ╠═dfc03456-f2db-4b1b-b38a-0523881a8398
# ╠═be6e034f-4246-4c50-a71d-448b78b9ad2a
# ╠═b582d82b-945c-4c7e-81f7-52fd1b616480
# ╠═c2e3e9af-9434-4fbe-a35f-bde32564103d
# ╟─5f5265fe-9790-48fa-8947-876ec161e20b
# ╠═ba0a191d-1dc2-454d-80cd-79fe0c739c00
# ╠═7242500d-d754-4c09-99a4-83f94142e654
# ╟─ab48a94b-f252-4023-b134-548c0870b393
# ╠═c2f8cd38-b602-4848-b662-cc5c26a989b4
# ╠═da61268e-1be4-44b1-87f1-ba349db93150
# ╟─fdebd8ba-beac-4025-97a2-af232c8d6471
# ╟─eb5d6110-38d6-46ec-b59d-8615afc3f6f7
# ╟─e185f0ea-e0aa-4fb6-aa7b-f7607899b826
# ╟─cbbeeac0-2c1b-43f3-9440-6fcfbf3870fb
# ╟─23c423cd-5227-4eec-a1f1-9fb6e209678a
# ╠═f8c80b48-a9a1-443d-8eaf-b87c7a823830
# ╠═ae87f7e8-4305-4a86-9f4a-e39cb63a1bed
# ╠═6fd33e88-4d5e-44e9-a5a7-f90d9956d2fc
# ╠═d14f8af2-009e-4eab-af08-7cf3c06d5814
# ╠═94a1ca60-444e-4d0b-918a-fe228cca25f4
# ╠═c9a56f44-0f24-4074-bdf5-219cbe9c015e
# ╟─dc6c220b-8f48-4170-b080-8d3c2bed7422
# ╠═ed20ead3-9f8f-4b15-8e58-a25417cd72a2
# ╠═d438d77a-0828-48c9-865c-0ecb4bc85531
# ╠═8776d9df-73d0-498a-be5b-c937a33a3c85
# ╠═34de48ea-2fff-4045-b786-311bab322916
# ╠═36464a69-184f-47ea-bc02-71dd5642423e
# ╠═7818921f-a2f3-46d5-9341-6ee6884692ad
# ╟─899aa533-fdb2-4613-b9b0-95d4703be1ff
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
