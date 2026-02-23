### A Pluto.jl notebook ###
# v0.20.21

using Markdown
using InteractiveUtils

# ╔═╡ 951eb83f-3971-4c32-9bb9-748de45a8c18
using Symbolics

# ╔═╡ 78c93250-3289-461b-973c-9b27ed679af0
using Enzyme

# ╔═╡ ae4a0a62-3c76-4ae2-8a2e-6bfb4d76f6fa
using CairoMakie

# ╔═╡ 9907d0c8-da00-4cb7-a18e-527d18d37faa
using Integrals

# ╔═╡ 0afe9807-4d90-4ea5-945b-87f5950ae716
using OrdinaryDiffEqTsit5

# ╔═╡ 466e6cdb-7787-46ec-9fc2-99e257a351b5
md"""
# Reproducing 
https://tellusjournal.org/articles/1228/files/submission/proof/1228-1-41706-1-10-20220920.pdf
"""

# ╔═╡ c4bd60dd-69b1-4bd1-b538-aa166f0e6ced
# using QuadGK

# ╔═╡ 3e453d6d-eae2-472c-99e8-2e7982c40221
md"""
Paper uses: 
- 4th order runge-kutta
- dt=0.005
- σ = 10
- b = 8/3
"""

# ╔═╡ 919b6c5a-bdda-4ee2-9c7f-d33ae6e446df
md"""
$\frac{dx}{dt} = -\sigma x + \sigma y$
$\frac{dy}{dt} = -xz + rx - y$
$\frac{dz}{dt} = xy - bz$

"""

# ╔═╡ d2f50766-0e46-11f1-1b14-dbb229dc7e03
function f!(du, u, p, t)
	σ, r, b = p
	du[1] = -σ*u[1] + σ*u[2]
	du[2] = -u[1]*u[3] + r*u[1] - u[2]
	du[3] = u[1]*u[2] - b*u[3]
	return nothing
end

# ╔═╡ 7e481614-e96e-47fc-9c8f-b3753d8db103
md"""
$\bar{z}(r, \tau, x_0, y_0, z_0) = \frac{1}{\tau}\int_0^\tau z(t) dt$
"""

# ╔═╡ d5e28832-42cb-4deb-ada9-975eee10c06b
function solve(u₀, p, τ; dt=0.005)
	# forward euler
	# probably want to replace that with something from DiffEq
	du = zero(u₀)
	u = copy(u₀)

	ts = 0:dt:τ
	U = zeros(length(u), length(ts)+1)

	for i in 1:length(ts)
		U[:, i] .= u
		f!(du, u, p, ts[i])
		u .+= du .* dt
	end
	U[:, end] .= u
	return U
end

# ╔═╡ 2b34d887-ba0c-4990-9e1a-bbf45c63407b
function z_bar(p, τ, u₀; dt=0.005)
	U = solve(u₀, p, τ; dt)
	# bad approximatation of integral
	integral = sum(view(U, 3, :)) * dt
	return 1/τ * integral, U
end

# ╔═╡ d4a994fd-3aaa-4228-a8fe-30c99b2adfd6
begin
	σ = 10.0
	b = 8/3
end;

# ╔═╡ 248e2d62-9dce-4d65-b91a-0f787cb5bc1a
begin
	x₀ = 8.00
	y₀ = -2.00
	z₀ = 36.5
end

# ╔═╡ cafa5c64-9ca6-4382-8dec-6d0c131c6049
md"""
## Figure 1
"""

# ╔═╡ 6505863e-b003-4b1e-b0b9-fd13a83f8e26
U = let r = 30, τ = 131.36

	U = solve([x₀, y₀, z₀], [σ, r, b], τ)
end

# ╔═╡ 69adc8ba-efeb-4f40-8e4c-38b1d87f23f7
let
	τ = 131.36
	fig = Figure(size=(1000,600), fontsize = 20)
	ax = Axis(fig[1,1], xlabel="x", ylabel="z")
	
	r = 30
	z̄, U = z_bar([σ, r, b], τ, [x₀, y₀, z₀])
	scatter!(ax, U[1, :], U[3, :], markersize=3)
	hlines!(ax, z̄)
	annotation!(ax, -20, z̄, text = "r=30")


	r = 80
	z̄, U = z_bar([σ, r, b], τ, [x₀, y₀, z₀])
	scatter!(ax, U[1, :], U[3, :], markersize=3)
	hlines!(ax, z̄)
	annotation!(ax, -30, z̄, text = "r=80")
	fig
end

# ╔═╡ b7fd6824-660d-4e65-9b4b-8b03da932a13
md"""
### Figure 2
"""

# ╔═╡ 49405f73-2ec8-4854-84d5-1d31116c02b8
function f(args...)
	x, _ = z_bar(args...)
	return x
end

# ╔═╡ be3b952b-2f16-4a2f-b951-41b5690d2c51
begin
	τ = 131.36
	rs = 0:0.005:100
	z̄s = [f([σ, r, b], τ, [x₀, y₀, z₀]) for r in rs]
end

# ╔═╡ 6caedf08-206f-4758-8206-8eff4ffbca7e
let

	fig = Figure(size=(1000,600), fontsize = 20)
	rs = 0:0.005:100

	τ = 0.1
	ax = Axis(fig[1,1], xlabel="r", ylabel="z̄", 
	title="τ=$τ")

	z̄s = [f([σ, r, b], τ, [x₀, y₀, z₀]) for r in rs]
	lines!(ax, rs, z̄s)

	τ = 0.44
	ax = Axis(fig[1,2], xlabel="r", ylabel="z̄", 
	title="τ=$τ")

	z̄s = [f([σ, r, b], τ, [x₀, y₀, z₀]) for r in rs]
	lines!(ax, rs, z̄s)

	τ = 2.26
	ax = Axis(fig[2,1], xlabel="r", ylabel="z̄", 
	title="τ=$τ")

	z̄s = [f([σ, r, b], τ, [x₀, y₀, z₀]) for r in rs]
	lines!(ax, rs, z̄s)

	τ = 131.36
	ax = Axis(fig[2,2], xlabel="r", ylabel="z̄", 
	title="τ=$τ")

	z̄s = [f([σ, r, b], τ, [x₀, y₀, z₀]) for r in rs]
	lines!(ax, rs, z̄s)

	fig
end

# ╔═╡ 75203cac-f901-4879-886d-977e67675541
g(r, τ) = f([σ, r, b], τ, [x₀, y₀, z₀])

# ╔═╡ da59ff93-a78c-4fae-8c43-717435f51ffc
# ╠═╡ disabled = true
#=╠═╡
let
	rs = 0:0.005:100
	ts = [0.1, 0.44, 2.26, 131.36]
	gs = g.(rs, ts')
	surface(rs, ts, gs)
end
  ╠═╡ =#

# ╔═╡ 9c17572d-1259-4ad4-b15e-18b4a31a72d5
md"""
## Figure 3
"""

# ╔═╡ d3c8a04c-9344-4d3a-9a61-2ad3d9fdd755
let
	τ = 2.26
	fig = Figure(size=(1000,600), fontsize = 20)
	ax = Axis(fig[1,1], xlabel="t", ylabel="z")
	
	r = 57
	z̄, U = z_bar([σ, r, b], τ, [x₀, y₀, z₀])
	lines!(ax, U[3, :])
	hlines!(ax, z̄)

	r = 59
	z̄, U = z_bar([σ, r, b], τ, [x₀, y₀, z₀])
	lines!(ax, U[3, :])
	hlines!(ax, z̄)


	fig
end

# ╔═╡ faf83ed7-062b-4fe2-bf59-41f2dabb8a79
md"""
!!! note
    - Actually look at a local minima in Fig2c
"""

# ╔═╡ bbe77118-e94d-4ae4-860a-d46641e34a14
md"""
## Using AD for eq 3
"""

# ╔═╡ 01c635d8-fe85-48b7-b70f-90376568b5b1
function f_dp(τ, r)
	autodiff(Enzyme.Forward, f, 
			 Duplicated([σ, r, b],
			            [0.0, 1.0, 0.0]),
			 Const(τ), 
			 Const([x₀, y₀, z₀])) |> only
end

# ╔═╡ f503ca71-5ca4-4dca-8c29-77cd91db9932
function f_dp_paper(τ, r, Δr)
	# 1-st order finite difference
	(f([σ, r + Δr, b], τ, [x₀, y₀, z₀]) - f([σ, r, b], τ, [x₀, y₀, z₀]))/Δr
end

# ╔═╡ be11de34-e3c1-45b2-bdab-f547561bd9dc
let τ = 2.26, r=70
	f_dp(τ, r)
end

# ╔═╡ a42b48a8-e7d5-4b35-abe1-61010fadf0c9
let τ = 2.26, r=70, Δr=0.001
	f_dp_paper(τ, r, Δr)
end

# ╔═╡ bf9bffe4-8e18-445f-ad12-46547ac41e2f
md"""
!!! warning
	Agreement is only good for small τ,
    and in constrast to section 3 which claims that z̄ converges for a given r independent of x₀, y₀, z₀, and τ, varying τ changes z̄
"""

# ╔═╡ 4e249f92-97e7-482a-a7ea-444778945d16
let τ = 5.0, r=70
	f_dp(τ, r)
end

# ╔═╡ c2cee707-499a-4ca6-99b4-bef8a9009f11
let τ = 5.0, r=70, Δr=0.001
	f_dp_paper(τ, r, Δr)
end

# ╔═╡ d77192c2-8291-4977-a6a1-f4b34b3d7293
let r=57
	fig = Figure()
	ax = Axis(fig[1,1])
		lines!(ax, 0.01:0.01:10.0, τ->f([σ, r, b], τ, [x₀, y₀, z₀]))
	ax = Axis(fig[2, 1])
	lines!(ax, 0.01:0.01:10.0, τ->f_dp(τ, r))
	fig
end

# ╔═╡ eccdda89-9532-4df6-81f7-1b500b16c5aa
let r=70
	lines(0.01:0.01:20.0, τ->f_dp_paper(τ, r, √eps(Float64)))
end

# ╔═╡ b1b6e7cb-a6ba-49c1-87e4-06f8be906ed2
md"""
!!! note "TODO"
    - Check with FwdDiff
    - Check with 
""" 

# ╔═╡ 49995729-5303-44ed-b4aa-869b6f149ef1
md"""
!!! note
    In Section 3 they remark, that the choice of Δr is important. It ought to be large enough so that the error due to local extrema is small, and small enough  that the underlying curvature is weak.

	AD gives us an tangent and not a sectant approximation, so it is more sensitive to these local extrema.
"""

# ╔═╡ f8b82e19-9d28-44d2-9baa-289db5253b92
md"""
### Calculate dp
"""

# ╔═╡ d5720e85-00d2-4019-be16-c42cbf397b1b
let τ = 5.0, r=70
	p = [σ, r, b]
	dp = zero(p)
	autodiff(Enzyme.Reverse, f, Active,
			 Duplicated(p,dp),
			 Const(τ), 
			 Const([x₀, y₀, z₀]))
	dp
end

# ╔═╡ 5acce70a-7319-4d71-b72f-dd83908fe3af
md"""
### 
"""

# ╔═╡ Cell order:
# ╟─466e6cdb-7787-46ec-9fc2-99e257a351b5
# ╠═951eb83f-3971-4c32-9bb9-748de45a8c18
# ╠═78c93250-3289-461b-973c-9b27ed679af0
# ╠═ae4a0a62-3c76-4ae2-8a2e-6bfb4d76f6fa
# ╠═c4bd60dd-69b1-4bd1-b538-aa166f0e6ced
# ╠═9907d0c8-da00-4cb7-a18e-527d18d37faa
# ╠═0afe9807-4d90-4ea5-945b-87f5950ae716
# ╟─3e453d6d-eae2-472c-99e8-2e7982c40221
# ╟─919b6c5a-bdda-4ee2-9c7f-d33ae6e446df
# ╠═d2f50766-0e46-11f1-1b14-dbb229dc7e03
# ╟─7e481614-e96e-47fc-9c8f-b3753d8db103
# ╠═d5e28832-42cb-4deb-ada9-975eee10c06b
# ╠═2b34d887-ba0c-4990-9e1a-bbf45c63407b
# ╠═d4a994fd-3aaa-4228-a8fe-30c99b2adfd6
# ╠═248e2d62-9dce-4d65-b91a-0f787cb5bc1a
# ╟─cafa5c64-9ca6-4382-8dec-6d0c131c6049
# ╠═6505863e-b003-4b1e-b0b9-fd13a83f8e26
# ╟─69adc8ba-efeb-4f40-8e4c-38b1d87f23f7
# ╟─b7fd6824-660d-4e65-9b4b-8b03da932a13
# ╠═49405f73-2ec8-4854-84d5-1d31116c02b8
# ╠═be3b952b-2f16-4a2f-b951-41b5690d2c51
# ╟─6caedf08-206f-4758-8206-8eff4ffbca7e
# ╠═75203cac-f901-4879-886d-977e67675541
# ╠═da59ff93-a78c-4fae-8c43-717435f51ffc
# ╟─9c17572d-1259-4ad4-b15e-18b4a31a72d5
# ╠═d3c8a04c-9344-4d3a-9a61-2ad3d9fdd755
# ╟─faf83ed7-062b-4fe2-bf59-41f2dabb8a79
# ╟─bbe77118-e94d-4ae4-860a-d46641e34a14
# ╠═01c635d8-fe85-48b7-b70f-90376568b5b1
# ╠═f503ca71-5ca4-4dca-8c29-77cd91db9932
# ╠═be11de34-e3c1-45b2-bdab-f547561bd9dc
# ╠═a42b48a8-e7d5-4b35-abe1-61010fadf0c9
# ╟─bf9bffe4-8e18-445f-ad12-46547ac41e2f
# ╠═4e249f92-97e7-482a-a7ea-444778945d16
# ╠═c2cee707-499a-4ca6-99b4-bef8a9009f11
# ╠═d77192c2-8291-4977-a6a1-f4b34b3d7293
# ╠═eccdda89-9532-4df6-81f7-1b500b16c5aa
# ╟─b1b6e7cb-a6ba-49c1-87e4-06f8be906ed2
# ╟─49995729-5303-44ed-b4aa-869b6f149ef1
# ╟─f8b82e19-9d28-44d2-9baa-289db5253b92
# ╠═d5720e85-00d2-4019-be16-c42cbf397b1b
# ╠═5acce70a-7319-4d71-b72f-dd83908fe3af
