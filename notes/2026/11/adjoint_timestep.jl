### A Pluto.jl notebook ###
# v1.1.0

#> [frontmatter]
#> title = "Differentiating through an adaptive time step"
#> date = "2026-11-15"
#> description = "Why a differentiated step-size controller can give an O(1) adjoint error, reproduced with Enzyme and Checkpointing.jl"
#> 
#>     [[frontmatter.author]]
#>     name = "Valentin Churavy"
#>     url = "https://vchuravy.dev"

using Markdown
using InteractiveUtils

# ╔═╡ 7ee72db5-ef43-47e4-905e-bba3e4c79a37
md"""
# Differentiating through an adaptive time step

Adaptive time steppers choose ``Δt_n`` from the state: a CFL condition ``Δt_n = c\,Δx / \max_i |u_i^n|``, or an error controller driven by an embedded error estimate. When reverse-mode AD differentiates such a loop as written, it also differentiates the step sizes. [Alexe and Sandu (2008)](https://vtechworks.lib.vt.edu/items/dcd7a23f-7fcc-4096-acc3-706b74ed9dc7/full) report that this gives an ``\mathcal{O}(1)`` error in the adjoint, one that does not shrink as the tolerance is tightened.

This note reproduces that error with [Enzyme.jl](https://github.com/EnzymeAD/Enzyme.jl), identifies where it comes from, and checks what it means for a CFL-stepped solver whose time loop is checkpointed with [Checkpointing.jl](https://github.com/Argonne-National-Laboratory/Checkpointing.jl).

**What we find.**

1. The ``\mathcal{O}(1)`` error is real. On Alexe and Sandu's test problem the differentiated gradient is off by a factor of about 1000 at every tolerance from ``10^{-3}`` to ``10^{-10}``.
2. It comes from the end time. When the loop stops at the first ``t_N \ge T``, the end time ``t_N = \sum_n Δt_n`` depends on the parameters, and AD faithfully differentiates that dependence. This is the mechanism [Eberhard and Bischof (1999)](https://www.ams.org/mcom/1999-68-226/S0025-5718-99-01027-3/) described for forward mode.
3. Two fixes, and you want both. Clipping the last step so the loop ends exactly at ``T`` removes the ``\mathcal{O}(1)`` term. Freezing the step-size computation removes what is left: with clipping alone, the error-controlled gradient was still 15 to 55 times less accurate than with a frozen controller.
4. For a CFL-stepped Burgers solver with the last step clipped, differentiating ``Δt`` made no visible difference. Without clipping, the same solver shows the same ``\mathcal{O}(1)`` error.
5. In Enzyme, freeze the step with an `EnzymeRules.inactive` function. `Enzyme.ignore_derivatives` currently fails to compile inside `@ad_checkpoint` loops.
"""

# ╔═╡ 13178939-2b8f-4ded-8473-361dcb97b310
using Enzyme, Checkpointing, Plots, Printf, PlutoUI

# ╔═╡ 8514be47-a0a8-4e67-ae8c-f3cd7f5e2c31
TableOfContents()

# ╔═╡ 8cd1dde1-6e63-4162-9d73-bae45f4b5484
md"""
## Where an ``\mathcal{O}(1)`` error can come from

Write one adaptive step as ``y_{n+1} = Φ(y_n, h_n, t_n)``, ``h_{n+1} = g(y_n, h_n)``, ``t_{n+1} = t_n + h_n``. Reverse-mode AD of this loop carries an adjoint ``μ_n`` for the step size, and the state adjoint picks up an extra term:

```math
λ_n = \Big(\frac{\partial Φ}{\partial y}\Big)^{\!T} λ_{n+1} + \Big(\frac{\partial g}{\partial y}\Big)^{\!T} μ_{n+1}.
```

For an error controller ``\partial h_{n+1}/\partial y_n = \mathcal{O}(h_n)``, so each step contributes ``\mathcal{O}(h)``. Over ``N = \mathcal{O}(1/h)`` steps that sums to ``\mathcal{O}(1)``. Alexe and Sandu propose dropping the second term (``μ \leftarrow 0``), which is the same as not differentiating the controller. Bock's [internal numerical differentiation](https://publications.anl.gov/anlpubs/1998/10/30856.pdf) gives the same rule: "step and order selection are not differentiated."

Whether the sum actually survives depends on where it goes. Every step-size perturbation moves the end time, ``\partial t_N/\partial p = \sum_n \partial h_n/\partial p = \mathcal{O}(1)``, and an objective evaluated at ``t_N`` then changes by ``\dot J(t_N)\, \partial t_N/\partial p``. If instead the last step is clipped to ``h_{N-1} = T - t_{N-1}``, then ``t_N = T`` exactly. A shifted step boundary then changes the result only through the local errors of the steps on either side, and that effect vanishes as the tolerance shrinks. Eberhard and Bischof make the same point: "the computation of the final time step plays a special role."
"""

# ╔═╡ 7337e780-9b56-4e6c-be09-e9acd08ac14e
md"""
## Part 1: Reproducing Alexe and Sandu

[Alexe and Sandu (2008)](https://vtechworks.lib.vt.edu/items/dcd7a23f-7fcc-4096-acc3-706b74ed9dc7/full), Section 6.1, use the Prothero–Robinson problem

```math
y' = \gamma\,(y - \varphi(t)) + \varphi'(t), \qquad \varphi(t) = (\sin t, \cos t), \qquad \gamma = -5,
```

on ``t \in [0, 2]`` with ``y(0) = (0.5, 0.5)`` and cost ``J = y_1(2)``. They integrate with DOPRI5(4), every step accepted, and the controller

```math
h_{n+1} = h_n \min\{5, \max\{0.2,\ 0.9\,\|e_n\|^{-1/5}\}\}, \qquad \|e_n\| = \sqrt{\tfrac{1}{2}\textstyle\sum_i \big(e_{n,i} / (\mathrm{tol}\,(1 + |y_{n,i}|))\big)^2}.
```

The exact gradient is ``\partial J / \partial y_0 = (e^{2\gamma}, 0) \approx (4.54\times10^{-5}, 0)``, small because the problem is strongly damped. That smallness is what makes the problem a sharp test: any spurious ``\mathcal{O}(h)``-per-step term swamps it.

The paper does not say how the last step is handled, so both finishes are run: `:clip` shortens the last step to land on ``t = 2``, and `:overshoot` stops at the first ``t_N \ge 2``. Each is run with the controller differentiated and with it frozen through an `EnzymeRules.inactive` function. To keep the code short this part is not checkpointed. Since `@ad_checkpoint` replays exactly the same steps, checkpointing would not change the numbers.
"""

# ╔═╡ e026bf9f-2b52-42f9-a3fd-e43e61c7711a
begin
    const DP_A = ((), (1 / 5,), (3 / 40, 9 / 40), (44 / 45, -56 / 15, 32 / 9),
        (19372 / 6561, -25360 / 2187, 64448 / 6561, -212 / 729),
        (9017 / 3168, -355 / 33, 46732 / 5247, 49 / 176, -5103 / 18656),
        (35 / 384, 0.0, 500 / 1113, 125 / 192, -2187 / 6784, 11 / 84))
    const DP_C = (0.0, 1 / 5, 3 / 10, 4 / 5, 8 / 9, 1.0, 1.0)
    const DP_B5 = (35 / 384, 0.0, 500 / 1113, 125 / 192, -2187 / 6784, 11 / 84, 0.0)
    const DP_B4 = (5179 / 57600, 0.0, 7571 / 16695, 393 / 640, -92097 / 339200, 187 / 2100, 1 / 40)
end

# ╔═╡ 2b88b61c-72f1-4337-a622-61851e2a9186
const γ_pr = -5.0

# ╔═╡ 620bab60-ab2f-4b9a-a465-6a05561001a2
pr_rhs(t, y1, y2) = (γ_pr * (y1 - sin(t)) + cos(t), γ_pr * (y2 - cos(t)) - sin(t))

# ╔═╡ 4a3c3b86-08cf-4a6b-b0a9-bbe2f2f5dd78
"One DOPRI5(4) step. Returns the 5th-order solution (z1, z2) and the error estimate (e1, e2)."
function dopri5_step(t, y1, y2, h)
    A, c = DP_A, DP_C
    k1 = pr_rhs(t, y1, y2)
    k2 = pr_rhs(t + c[2]h, y1 + h * A[2][1] * k1[1], y2 + h * A[2][1] * k1[2])
    k3 = pr_rhs(t + c[3]h, y1 + h * (A[3][1] * k1[1] + A[3][2] * k2[1]),
                           y2 + h * (A[3][1] * k1[2] + A[3][2] * k2[2]))
    k4 = pr_rhs(t + c[4]h, y1 + h * (A[4][1] * k1[1] + A[4][2] * k2[1] + A[4][3] * k3[1]),
                           y2 + h * (A[4][1] * k1[2] + A[4][2] * k2[2] + A[4][3] * k3[2]))
    k5 = pr_rhs(t + c[5]h, y1 + h * (A[5][1] * k1[1] + A[5][2] * k2[1] + A[5][3] * k3[1] + A[5][4] * k4[1]),
                           y2 + h * (A[5][1] * k1[2] + A[5][2] * k2[2] + A[5][3] * k3[2] + A[5][4] * k4[2]))
    k6 = pr_rhs(t + c[6]h, y1 + h * (A[6][1] * k1[1] + A[6][2] * k2[1] + A[6][3] * k3[1] + A[6][4] * k4[1] + A[6][5] * k5[1]),
                           y2 + h * (A[6][1] * k1[2] + A[6][2] * k2[2] + A[6][3] * k3[2] + A[6][4] * k4[2] + A[6][5] * k5[2]))
    b = DP_B5
    z1 = y1 + h * (b[1] * k1[1] + b[3] * k3[1] + b[4] * k4[1] + b[5] * k5[1] + b[6] * k6[1])
    z2 = y2 + h * (b[1] * k1[2] + b[3] * k3[2] + b[4] * k4[2] + b[5] * k5[2] + b[6] * k6[2])
    k7 = pr_rhs(t + h, z1, z2)
    E = DP_B5 .- DP_B4
    e1 = h * (E[1] * k1[1] + E[3] * k3[1] + E[4] * k4[1] + E[5] * k5[1] + E[6] * k6[1] + E[7] * k7[1])
    e2 = h * (E[1] * k1[2] + E[3] * k3[2] + E[4] * k4[2] + E[5] * k5[2] + E[6] * k6[2] + E[7] * k7[2])
    return z1, z2, e1, e2
end

# ╔═╡ 53c8d9b1-991a-4084-b38b-7a981c6c3dec
begin
    function dopri_controller(h, y1, y2, e1, e2, tol)
        n = sqrt(((e1 / (tol * (1 + abs(y1))))^2 + (e2 / (tol * (1 + abs(y2))))^2) / 2)
        return h * min(5.0, max(0.2, 0.9 * n^(-1 / 5)))
    end
    dopri_controller_inactive(args...) = dopri_controller(args...)
    Enzyme.EnzymeRules.inactive(::typeof(dopri_controller_inactive), args...) = true
    choose_h(::Val{:active}, args...) = dopri_controller(args...)
    choose_h(::Val{:inactive}, args...) = dopri_controller_inactive(args...)
    clip_h(::Val{:clip}, h, t, tF) = min(h, tF - t)
    clip_h(::Val{:overshoot}, h, t, tF) = h
end

# ╔═╡ b8d50454-4ec0-4a71-a603-35114e951188
"J = y₁(t_F) after integrating Prothero–Robinson with DOPRI5(4). Returns (J, number of steps, t_N)."
function prothero_robinson(y01, y02, tol, mode, finish; tF = 2.0, h0 = 1e-3)
    t, y1, y2, h, M = 0.0, y01, y02, h0, 0
    while t < tF * (1 - 1e-14)
        h = clip_h(finish, h, t, tF)
        z1, z2, e1, e2 = dopri5_step(t, y1, y2, h)
        hnew = choose_h(mode, h, y1, y2, e1, e2, tol)
        y1, y2, t, h, M = z1, z2, t + h, hnew, M + 1
    end
    return y1, M, t
end

# ╔═╡ e78c481e-2e2f-41b9-ae60-012ef48d4e4b
J_pr(y01, y02, tol, mode, finish) = prothero_robinson(y01, y02, tol, mode, finish)[1]

# ╔═╡ e2ad7e32-b3e2-4a28-bde2-680fa13a4f15
pr_grad(tol, mode, finish) = autodiff(Reverse, J_pr, Active, Active(0.5), Active(0.5),
    Const(tol), Const(Val(mode)), Const(Val(finish)))[1][1]

# ╔═╡ 6517c61e-cd76-4877-9eeb-630b268e89ab
pr_tols = [1e-3, 1e-4, 1e-5, 1e-6, 1e-7, 1e-8, 1e-9, 1e-10]

# ╔═╡ d48e56ac-a1e4-4482-a357-c107fb67eaa7
g_pr_exact = exp(2γ_pr)

# ╔═╡ 35804463-5e1f-4933-bce2-48a614d999bb
pr_results = map(Iterators.product(pr_tols, (:clip, :overshoot))) do (tol, finish)
    _, M, tN = prothero_robinson(0.5, 0.5, tol, Val(:active), Val(finish))
    δ = 1e-7
    fd = (J_pr(0.5 + δ, 0.5, tol, Val(:active), Val(finish)) - J_pr(0.5 - δ, 0.5, tol, Val(:active), Val(finish))) / 2δ
    (; tol, finish, M, overshoot = tN - 2.0,
        active = pr_grad(tol, :active, finish), inactive = pr_grad(tol, :inactive, finish), fd)
end

# ╔═╡ af42ef44-a2e2-425c-92fb-c19bb730cf38
let
    rows = ["| finish | tol | steps | t_N − 2 | controller differentiated | finite difference of solver | controller inactive |",
            "|---|---|---|---|---|---|---|"]
    for r in pr_results
        push!(rows, @sprintf("| %s | %.0e | %d | %.1e | %.3e | %.3e | %.3e |", r.finish, r.tol, r.M, r.overshoot, r.active, r.fd, r.inactive))
    end
    Markdown.parse(@sprintf("Exact ``\\partial J/\\partial y_{0,1}`` = %.4e\n\n", g_pr_exact) * join(rows, "\n"))
end

# ╔═╡ 17cee903-8ddb-4a06-8944-ad6335f20cac
let
    plt = plot(xscale = :log10, yscale = :log10, xflip = true, xlabel = "tolerance", ylabel = "relative error in ∂J/∂y₀",
        title = "Prothero–Robinson, DOPRI5(4)", legend = :outerright, minorgrid = true, size = (760, 420))
    for (finish, ls) in ((:overshoot, :solid), (:clip, :dash))
        rs = filter(r -> r.finish == finish, vec(pr_results))
        plot!(plt, pr_tols, [abs(r.active - g_pr_exact) / g_pr_exact for r in rs], marker = :circle, linestyle = ls, label = "$finish, controller differentiated")
        plot!(plt, pr_tols, [abs(r.inactive - g_pr_exact) / g_pr_exact for r in rs], marker = :square, linestyle = ls, label = "$finish, controller inactive")
    end
    plt
end

# ╔═╡ e925df77-8556-4a15-b310-efa6aceac0a2
md"""
Without clipping, the differentiated gradient is about ``5\times10^{-2}`` against an exact ``4.5\times10^{-5}``: a relative error near ``10^3`` at every tolerance. This is the ``\mathcal{O}(1)`` error. The finite difference of the solver agrees with Enzyme, so AD is computing the true derivative of the code. The code's output just depends on ``y_0`` through the end time ``t_N``, which is not part of the ODE problem.

Freezing the controller removes the ``\mathcal{O}(1)`` term. The 4 to 50 percent error that remains comes from evaluating ``J`` at ``t_N`` instead of ``2``, and it shrinks only as fast as the overshoot does.

With clipping, both versions converge. The differentiated controller still costs accuracy: at `tol = 1e-3` its gradient has the wrong sign, and across the range it is 15 to 55 times less accurate than the frozen one. Clipping removes the ``\mathcal{O}(1)`` term, and freezing the controller removes the rest.
"""

# ╔═╡ e01f965b-e61e-4aed-a822-53580982cb45
md"""
## Part 2: A CFL-stepped solver with checkpointing

Part 1 used a small ODE. The question for PDE codes such as [Trixi.jl](https://github.com/trixi-framework/Trixi.jl) is what happens with a CFL step size on a time loop that is checkpointed, so that the reverse pass recomputes the forward from stored states. Here the same two finishes are run on a Burgers solver.
"""

# ╔═╡ 0e0a7d57-3cf6-437b-b866-22c93f2fdf4f
md"""
### The model

We solve inviscid Burgers, ``u_t + (u^2/2)_x = 0``, on the periodic unit interval with initial condition ``u_0(x) = 1 + p \sin(2\pi x)``. The parameter is the amplitude ``p = 0.5``, and the objective is

```math
J(p) = \int_0^1 \sin(2\pi x)\, u(x, T)^3 \,\mathrm{d}x, \qquad T = 0.2 .
```

A shock forms at ``t = 1/(2\pi p) \approx 0.32``, so the solution is smooth up to ``T`` and the exact gradient is available from characteristics. The space discretization is fourth-order central differences and time stepping is classical RK4, so the gradient error should fall like ``\mathcal{O}(Δx^4)`` when nothing goes wrong.

Checkpointing.jl wants every value the loop body reads to live in one mutable struct. The struct carries the state, the RK4 stage buffers, the clock, and the solver constants.
"""

# ╔═╡ deb4f8e0-33b8-42aa-8fb3-c0bb8d42fff6
begin
    mutable struct Burgers
        u::Vector{Float64}
        k1::Vector{Float64}
        k2::Vector{Float64}
        k3::Vector{Float64}
        k4::Vector{Float64}
        tmp::Vector{Float64}
        t::Float64     # current time
        dt::Float64    # current (or, for the error controller, next) step
        dx::Float64
        cfl::Float64   # CFL number, or tolerance for the error controller
        T::Float64     # final time
    end

    Burgers(n) = Burgers(zeros(n), zeros(n), zeros(n), zeros(n), zeros(n), zeros(n), 0.0, 0.0, 1 / n, 0.0, 0.0)
end

# ╔═╡ 529732b0-2b41-4968-b2c4-fc7376bc4317
# -(u²/2)_x with fourth-order central differences, periodic
function rhs!(du, u, dx)
    n = length(u)
    @inbounds for i in 1:n
        im2, im1, ip1, ip2 = mod1(i - 2, n), mod1(i - 1, n), mod1(i + 1, n), mod1(i + 2, n)
        du[i] = -0.5 * (-u[ip2]^2 + 8u[ip1]^2 - 8u[im1]^2 + u[im2]^2) / (12dx)
    end
    return nothing
end

# ╔═╡ d0ddcbdd-c532-493b-a5b8-6fb70325e949
function rk4!(s::Burgers, dt)
    rhs!(s.k1, s.u, s.dx)
    @. s.tmp = s.u + dt / 2 * s.k1; rhs!(s.k2, s.tmp, s.dx)
    @. s.tmp = s.u + dt / 2 * s.k2; rhs!(s.k3, s.tmp, s.dx)
    @. s.tmp = s.u + dt * s.k3;     rhs!(s.k4, s.tmp, s.dx)
    @. s.u += dt / 6 * (s.k1 + 2s.k2 + 2s.k3 + s.k4)
    return nothing
end

# ╔═╡ a1c4bd15-01d4-474f-8e40-caa2de869405
md"""
### Three ways to compute the step

* `:active`: plain code. Enzyme differentiates ``Δt`` like any other value.
* `:ignore`: wrap the result in `Enzyme.ignore_derivatives`.
* `:inactive`: compute it in a function marked with `EnzymeRules.inactive`, so Enzyme treats its result as a constant.

The last two should give the same gradient. They differ in where they work, as the section on Enzyme below shows.
"""

# ╔═╡ 917b2e43-0dfe-4438-b064-98c215e4edd8
function cfl_dt(u, dx, cfl)
    m = 0.0
    for v in u
        m = max(m, abs(v))
    end
    return cfl * dx / m
end

# ╔═╡ 30543463-4ec0-4197-a40a-234d90646641
begin
    cfl_dt_inactive(u, dx, cfl) = cfl_dt(u, dx, cfl)
    Enzyme.EnzymeRules.inactive(::typeof(cfl_dt_inactive), args...) = true
end

# ╔═╡ 84c93d05-4b60-4071-830d-a77b14cffaad
begin
    choose_dt(::Val{:active}, u, dx, cfl) = cfl_dt(u, dx, cfl)
    choose_dt(::Val{:ignore}, u, dx, cfl) = Enzyme.ignore_derivatives(cfl_dt(u, dx, cfl))
    choose_dt(::Val{:inactive}, u, dx, cfl) = cfl_dt_inactive(u, dx, cfl)
end

# ╔═╡ 1d618830-5f36-4c8f-bc3e-539f1daa2750
md"""
### Two ways to finish

* `:clip`: the last step is shortened to ``T - t``, so the loop ends exactly at ``T``. OrdinaryDiffEq.jl and therefore Trixi.jl do this.
* `:overshoot`: the loop runs `while t < T` with the full CFL step and stops at the first ``t_N \ge T``. Many hand-written solvers do this.
"""

# ╔═╡ 9019f3b6-9098-43b6-b03d-5b3380b97489
begin
    finish_dt(::Val{:clip}, dt, s) = min(dt, s.T - s.t)
    finish_dt(::Val{:overshoot}, dt, s) = dt
end

# ╔═╡ fe13f927-d4ff-4a39-a8b0-6a0ce08884d6
function cfl_step!(s::Burgers, mode, finish)
    dt = choose_dt(mode, s.u, s.dx, s.cfl)
    dt = finish_dt(finish, dt, s)
    s.dt = dt
    rk4!(s, dt)
    s.t += dt
    return nothing
end

# ╔═╡ 7f9ea423-c757-4383-8bb0-0abe5a102990
md"""
### The checkpointed objective

`@ad_checkpoint` with `Online_r2` handles a `while` loop whose trip count is not known in advance, which is the situation an adaptive step creates. During the reverse pass it recomputes the forward from checkpoints. Since the step size is recomputed from the restored state, the replay takes exactly the same steps.
"""

# ╔═╡ 1a78113d-1e50-44f6-84e7-cb021dba3d71
function objective(s::Burgers, p, x, cfl, T, mode, finish, scheme)
    @inbounds for i in eachindex(s.u)
        s.u[i] = 1 + p * sin(2π * x[i])
    end
    s.t = 0.0
    s.cfl = cfl
    s.T = T
    @ad_checkpoint scheme while s.t < s.T * (1 - 1e-14)
        cfl_step!(s, mode, finish)
    end
    J = 0.0
    @inbounds for i in eachindex(s.u)
        J += sin(2π * x[i]) * s.u[i]^3 * s.dx
    end
    return J
end

# ╔═╡ 68d44df6-db4c-4a43-9654-b68d660402e0
const p₀ = 0.5

# ╔═╡ e58c06bb-e71e-415d-aaa0-2abec87c55f5
const T₀ = 0.2

# ╔═╡ 292a230d-3309-4042-b281-27328cf390a0
"Gradient dJ/dp from Enzyme, with the time loop checkpointed."
function enzyme_gradient(n; p = p₀, T = T₀, cfl = 0.5, mode = :active, finish = :clip, scheme = Online_r2(60))
    x = collect((0:n-1) ./ n)
    s, ds = Burgers(n), Burgers(n)
    res = autodiff(Reverse, objective, Active, Duplicated(s, ds), Active(p),
        Const(x), Const(cfl), Const(T), Const(Val(mode)), Const(Val(finish)), Const(scheme))
    return res[1][2]
end

# ╔═╡ d2e89515-24e6-4a24-a759-862915e750da
"Run the solver without AD; returns J and the final time t_N."
function run_solver(n; p = p₀, T = T₀, cfl = 0.5, finish = :clip)
    x = collect((0:n-1) ./ n)
    s = Burgers(n)
    J = objective(s, p, x, cfl, T, Val(:active), Val(finish), Online_r2(60))
    return J, s.t
end

# ╔═╡ a6ad4272-57d3-4400-836c-f332cec48028
md"""
#### Exact reference

Before the shock, ``u(x, t) = u_0(\xi)`` with ``\xi + u_0(\xi)\, t = x``. We solve for ``\xi`` by Newton's method on a fine grid, integrate ``J``, and differentiate in ``p`` with a central difference. This is the gradient of the PDE, not of any discretization.
"""

# ╔═╡ e62d4c1f-54d7-4b54-b2cb-0d213ed7eed7
function J_exact(p, t; m = 4000)
    J = 0.0
    for i in 0:m-1
        x = i / m
        ξ = x
        for _ in 1:50
            ξ -= (ξ + (1 + p * sin(2π * ξ)) * t - x) / (1 + 2π * p * cos(2π * ξ) * t)
        end
        J += sin(2π * x) * (1 + p * sin(2π * ξ))^3 / m
    end
    return J
end

# ╔═╡ f510e2d1-1fad-4b2c-97c4-c3bc116e8b31
dJ_exact(p, t; h = 1e-6) = (J_exact(p + h, t) - J_exact(p - h, t)) / 2h

# ╔═╡ d8acb75e-80dc-43b2-9bae-a5c647ce9170
g_exact = dJ_exact(p₀, T₀)

# ╔═╡ e492178c-120b-47d8-9a4d-e28c95601739
ns = [32, 64, 128, 256, 512]

# ╔═╡ 814ebe27-9afa-461d-8c26-103c6b69b952
md"""
### Landing exactly on ``T``

With the last step clipped, both variants converge at fourth order. The differentiated step adds nothing visible. As derived above, with the step sizes summing to exactly ``T`` a moved step boundary only changes the local errors.
"""

# ╔═╡ c53a452a-cdd2-4976-8627-45147f04356d
clip_errors = Dict(mode => [abs(enzyme_gradient(n; mode, finish = :clip) - g_exact) for n in ns] for mode in (:active, :inactive))

# ╔═╡ 26e4082e-0b0a-49d0-9332-e0518c6e5acb
let
    plt = plot(xscale = :log10, yscale = :log10, xlabel = "grid points n", xticks = (ns, string.(ns)), ylabel = "|dJ/dp − exact|",
        title = "Last step clipped to T", legend = :bottomleft, minorgrid = true)
    plot!(plt, ns, clip_errors[:active], marker = :circle, label = "Δt differentiated")
    plot!(plt, ns, clip_errors[:inactive], marker = :square, linestyle = :dash, label = "Δt inactive")
    plot!(plt, ns, clip_errors[:active][1] .* (ns[1] ./ ns) .^ 4, color = :gray, linestyle = :dot, label = "slope −4")
    plt
end

# ╔═╡ e21ca5a4-be94-47ee-9d44-cae358c57589
md"""
### Overshooting ``T``

Now the loop stops at the first ``t_N \ge T``. The final time ``t_N = \sum_n Δt_n`` depends on ``p`` through every step, and ``\partial t_N / \partial p`` is a sum of ``N = \mathcal{O}(1/Δt)`` terms of size ``\mathcal{O}(Δt)``, so it is ``\mathcal{O}(1)``, exactly as in Part 1. The differentiated gradient picks up ``\partial_t J \cdot \partial t_N / \partial p`` and stays wrong as the grid is refined.

The table also shows a central finite difference of the solver itself. It agrees with Enzyme, so AD is computing the correct derivative of what the code does. What the code does is the problem.
"""

# ╔═╡ 12ce43e7-8058-4e48-b805-1dffb2681c61
overshoot = map(ns) do n
    J, tN = run_solver(n; finish = :overshoot)
    h = 1e-7
    fd = (run_solver(n; p = p₀ + h, finish = :overshoot)[1] - run_solver(n; p = p₀ - h, finish = :overshoot)[1]) / 2h
    (; n, overshoot = tN - T₀,
        active = enzyme_gradient(n; mode = :active, finish = :overshoot),
        inactive = enzyme_gradient(n; mode = :inactive, finish = :overshoot),
        fd, exact_at_tN = dJ_exact(p₀, tN))
end

# ╔═╡ 49410069-3a5c-4cb3-92bb-15a972c3e900
let
    rows = ["| n | t_N − T | Δt differentiated | finite difference of solver | Δt inactive | exact gradient at t_N |",
            "|---|---|---|---|---|---|"]
    for r in overshoot
        push!(rows, @sprintf("| %d | %.2e | %.5f | %.5f | %.5f | %.5f |", r.n, r.overshoot, r.active, r.fd, r.inactive, r.exact_at_tN))
    end
    Markdown.parse("Exact gradient at ``T``: " * @sprintf("%.5f", g_exact) * "\n\n" * join(rows, "\n"))
end

# ╔═╡ 8717b85a-f56f-4661-9773-52f00f2572ae
let
    plt = plot(xscale = :log10, yscale = :log10, xlabel = "grid points n", xticks = (ns, string.(ns)), ylabel = "|dJ/dp − exact at T|",
        title = "Loop overshoots T", legend = :right, minorgrid = true)
    plot!(plt, ns, [abs(r.active - g_exact) for r in overshoot], marker = :circle, label = "Δt differentiated")
    plot!(plt, ns, [abs(r.inactive - g_exact) for r in overshoot], marker = :square, linestyle = :dash, label = "Δt inactive")
    plot!(plt, ns, clip_errors[:inactive], marker = :diamond, linestyle = :dot, label = "clipped (previous plot)")
    plt
end

# ╔═╡ 7761f78b-68f7-46d8-8255-37a44284bb2f
md"""
With ``Δt`` inactive the ``\mathcal{O}(1)`` term is gone, and the gradient matches the exact gradient at ``t_N`` to the scheme's accuracy. But ``t_N - T`` is up to one step, so the error against the gradient at ``T`` is only first order, and here it stalls near ``7\times10^{-3}`` because ``t_N - T`` stops shrinking for ``n \ge 128``: it depends on where the last full step happens to land. Ignoring the step derivative fixes the symptom; landing on ``T`` fixes the cause.
"""

# ╔═╡ 96b2cb9a-fc9e-4c46-9cac-e1f6e5ed3d73
md"""
### An error-based controller

Part 1 showed that, even with clipping, a differentiated error controller can cost accuracy. Here is the Burgers problem with an error controller ``Δt_{n+1} = Δt_n \min(5, \max(0.2, 0.9\,\mathrm{err}_n^{-1/3}))``, using Bogacki–Shampine 3(2), every step accepted, the last step clipped to ``T``, and a fixed grid of ``n = 128`` points. The reference is the time-converged gradient of the same semi-discretization.
"""

# ╔═╡ dd76d7e6-1c71-4032-98db-7e8b202e97cb
function err_norm(s::Burgers, h)
    e = 0.0
    @inbounds for i in eachindex(s.u)
        d = h * ((2 / 9 - 7 / 24) * s.k1[i] + (1 / 3 - 1 / 4) * s.k2[i] + (4 / 9 - 1 / 3) * s.k3[i] - (1 / 8) * s.k4[i])
        e += (d / (s.cfl * (1 + abs(s.u[i]))))^2
    end
    return sqrt(e / length(s.u))
end

# ╔═╡ ea6206c9-c982-42dd-8e5f-75187197ad14
begin
    next_dt(s, h) = h * min(5.0, max(0.2, 0.9 * err_norm(s, h)^(-1 / 3)))
    next_dt_inactive(s, h) = next_dt(s, h)
    Enzyme.EnzymeRules.inactive(::typeof(next_dt_inactive), args...) = true
    choose_next(::Val{:active}, s, h) = next_dt(s, h)
    choose_next(::Val{:inactive}, s, h) = next_dt_inactive(s, h)
end

# ╔═╡ 7120c2dc-34dc-4aa4-ad91-54f13f9d7860
function bs3_step!(s::Burgers, mode)
    h = min(s.dt, s.T - s.t)
    rhs!(s.k1, s.u, s.dx)
    @. s.tmp = s.u + h / 2 * s.k1;  rhs!(s.k2, s.tmp, s.dx)
    @. s.tmp = s.u + 3h / 4 * s.k2; rhs!(s.k3, s.tmp, s.dx)
    @. s.tmp = s.u + h * (2 / 9 * s.k1 + 1 / 3 * s.k2 + 4 / 9 * s.k3)
    rhs!(s.k4, s.tmp, s.dx)
    s.dt = choose_next(mode, s, h)
    s.u .= s.tmp
    s.t += h
    return nothing
end

# ╔═╡ 71473ad0-0cb3-4259-9346-eb99fb414be8
function objective_bs3(s::Burgers, p, x, tol, T, mode, scheme)
    @inbounds for i in eachindex(s.u)
        s.u[i] = 1 + p * sin(2π * x[i])
    end
    s.t, s.dt, s.cfl, s.T = 0.0, 1e-4, tol, T
    @ad_checkpoint scheme while s.t < s.T * (1 - 1e-14)
        bs3_step!(s, mode)
    end
    J = 0.0
    @inbounds for i in eachindex(s.u)
        J += sin(2π * x[i]) * s.u[i]^3 * s.dx
    end
    return J
end

# ╔═╡ 22edafbe-8d11-4736-8ab6-c9237922db84
function enzyme_gradient_bs3(n, tol; mode = :active, scheme = Online_r2(200))
    x = collect((0:n-1) ./ n)
    s, ds = Burgers(n), Burgers(n)
    res = autodiff(Reverse, objective_bs3, Active, Duplicated(s, ds), Active(p₀),
        Const(x), Const(tol), Const(T₀), Const(Val(mode)), Const(scheme))
    return res[1][2]
end

# ╔═╡ fdba8aa2-bda3-4e2e-b72a-968044503be4
g_semi = enzyme_gradient(128; cfl = 0.02, mode = :inactive, scheme = Online_r2(200))

# ╔═╡ 9258219c-34e2-4f7a-b84f-2277eb471d60
tols = [1e-3, 1e-4, 1e-5, 1e-6, 1e-7, 1e-8]

# ╔═╡ 13a01a94-2fc1-410d-95e0-ab902df05f35
bs3_errors = Dict(mode => [abs(enzyme_gradient_bs3(128, tol; mode) - g_semi) for tol in tols] for mode in (:active, :inactive))

# ╔═╡ 4cad2121-380e-46b2-b7ba-d74197066907
let
    plt = plot(xscale = :log10, yscale = :log10, xflip = true, xlabel = "tolerance", ylabel = "|dJ/dp − time-converged|",
        title = "Bogacki–Shampine 3(2), last step clipped", legend = :bottomleft, minorgrid = true)
    plot!(plt, tols, bs3_errors[:active], marker = :circle, label = "Δt differentiated")
    plot!(plt, tols, bs3_errors[:inactive], marker = :square, linestyle = :dash, label = "Δt inactive")
    plt
end

# ╔═╡ c402796b-aa6f-47c1-8b67-7b9a4b50cf3a
md"""
Both converge as the tolerance shrinks, and here the differentiated controller is, if anything, slightly more accurate. So the excess error from a differentiated controller depends on the problem: large for the strongly damped Prothero–Robinson problem in Part 1, invisible here. Freezing the controller is the choice that is safe in both cases.
"""

# ╔═╡ a51685a0-7c17-4957-ad25-a67fe42f1fd4
md"""
## Freezing the step size in Enzyme

Enzyme offers two ways to keep a value out of the derivative: wrap it in `Enzyme.ignore_derivatives`, or compute it in a function declared with `EnzymeRules.inactive`, as this note does. Without checkpointing both work and give the same gradient. Inside `@ad_checkpoint`, `ignore_derivatives` currently does not: replacing `:inactive` by `:ignore` in the checkpointed runs of Part 2 fails at compile time with

```
JIT session error: Symbols not found: [ __enzyme_ignore_derivatives.Float64 ]
LLVM error: Failed to materialize symbols: { (JuliaExternal, { diffejulia_objective_…wrap }) }
```

The failure does not depend on Checkpointing.jl. Any custom rule whose primal calls `ignore_derivatives` triggers it, in reverse and in forward mode:

```julia
using Enzyme, Enzyme.EnzymeRules

f(x) = x * x
function EnzymeRules.augmented_primal(c, ::Const{typeof(f)}, ::Type{<:Active}, x::Active)
    y = Enzyme.ignore_derivatives(x.val) * x.val
    return EnzymeRules.AugmentedReturn(EnzymeRules.needs_primal(c) ? y : nothing, nothing, nothing)
end
EnzymeRules.reverse(c, ::Const{typeof(f)}, dy::Active, tape, x::Active) = (2 * x.val * dy.val,)

autodiff(Reverse, f, Active, Active(3.0))   # expected ((6.0,),); fails to link
```

The rule body is small enough to be inlined, so Enzyme compiles it in a separate module and links that module in only after the pass that replaces `__enzyme_ignore_derivatives` by its argument has run. Marking the rule method `@noinline` avoids the failure. This is reported as [Enzyme.jl#4059](https://github.com/EnzymeAD/Enzyme.jl/issues/4059). Until that is fixed, use an `EnzymeRules.inactive` function for the step size.
"""

# ╔═╡ 65c9b965-bdf6-4a2d-a2ce-8785380ced1d
md"""
## Takeaways

* Differentiating an adaptive step size can give an ``\mathcal{O}(1)`` gradient error, as Alexe and Sandu report. The error comes through the end time: each step adds ``\mathcal{O}(h)``, ``N = \mathcal{O}(1/h)`` steps add up to ``\mathcal{O}(1)``, and a loop that stops at the first ``t_N \ge T`` turns that into a gradient error.
* Land exactly on ``T``. This removes the ``\mathcal{O}(1)`` term for both CFL and error controllers. OrdinaryDiffEq.jl, and so Trixi.jl, already does this.
* Freeze the step-size computation as well. With clipping, a differentiated CFL step made no visible difference for Burgers, but a differentiated error controller was 15 to 55 times less accurate on Prothero–Robinson. Freezing it was never worse.
* In Enzyme, use an `EnzymeRules.inactive` function for the step size. `ignore_derivatives` does not currently work inside `@ad_checkpoint` loops.

The numbers above were produced with Enzyme 0.13.219 and Checkpointing.jl 0.13.0 on Julia 1.10.
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
Checkpointing = "eb46d486-4f9c-4c3d-b445-a617f2a2f1ca"
Enzyme = "7da242da-08ed-463a-9acd-ee780be4f1d9"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Printf = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[compat]
Checkpointing = "~0.13.0"
Enzyme = "~0.13.219"
Plots = "~1.41"
PlutoUI = "~0.7"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.10.4"
manifest_format = "2.0"
project_hash = "fe2299b5e4911f4f4e836f0c14c8194f1588c40d"

[[deps.AbstractPlutoDingetjes]]
git-tree-sha1 = "e71ee7b4aa06b045259a7d6101e1cb45ad140bce"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.4.1"

[[deps.AliasTables]]
deps = ["PtrArrays", "Random"]
git-tree-sha1 = "9876e1e164b144ca45e9e3198d0b689cadfed9ff"
uuid = "66dad0bd-aa9a-41b7-9441-69ab47430ed8"
version = "1.1.3"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1b96ea4a01afe0ea4090c5c8039690672dd13f2e"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.9+0"

[[deps.CEnum]]
git-tree-sha1 = "389ad5c84de1ae7cf0e28e381131c98ea87d54fc"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.5.0"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "Libdl", "Pixman_jll", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "0cfb779e24fdced77a05df1dbe99200821a9f563"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.18.8+1"

[[deps.Checkpointing]]
deps = ["Enzyme", "EnzymeCore", "Serialization"]
git-tree-sha1 = "72ff0fc0e1e359a8689015d0715b70291c4118c5"
uuid = "eb46d486-4f9c-4c3d-b445-a617f2a2f1ca"
version = "0.13.0"

    [deps.Checkpointing.extensions]
    CheckpointingHDF5Ext = "HDF5"

    [deps.Checkpointing.weakdeps]
    HDF5 = "f67ccb44-e63f-5c2f-98bd-6dc0ccc4ba2f"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "PrecompileTools", "Random"]
git-tree-sha1 = "060adaf7a5c2e14bca025edf0eea0206ffdebd87"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.32.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "af523e59de94de05b9b367a2ca4d63233aacd222"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.12.5"

    [deps.ColorTypes.extensions]
    StyledStringsExt = "StyledStrings"

    [deps.ColorTypes.weakdeps]
    StyledStrings = "f489334b-da3d-4c2e-b8f0-e476e12c162b"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "Requires", "Statistics", "TensorCore"]
git-tree-sha1 = "96fce5c80e0834e96ab6d24fb384fd945c9cb2d4"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.11.2"

    [deps.ColorVectorSpace.extensions]
    SpecialFunctionsExt = "SpecialFunctions"

    [deps.ColorVectorSpace.weakdeps]
    SpecialFunctions = "276daf66-3868-5448-9aa4-cd146d93841b"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "Reexport"]
git-tree-sha1 = "0737a3e59f9d94957f5b177fa2ca40901636b85b"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.13.4"

[[deps.CompilerCaching]]
deps = ["LMDB", "SHA", "Scratch"]
git-tree-sha1 = "1de3647e392372f1a77e41ae705ceaa12473bc08"
uuid = "9db33cc3-5358-4881-8759-fa4194144afd"
version = "0.5.3"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.1.1+0"

[[deps.Contour]]
git-tree-sha1 = "439e35b0b36e2e5881738abc8857bd92ad6ff9a8"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.6.3"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataStructures]]
deps = ["OrderedCollections"]
git-tree-sha1 = "b0bc6d2cad1fed8b7fd59a1551a991cb3d2809e6"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.19.6"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.Dbus_jll]]
deps = ["Artifacts", "Expat_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "473e9afc9cf30814eb67ffa5f2db7df82c3ad9fd"
uuid = "ee1fde0b-3d02-5ea6-8484-8dfef6360eab"
version = "1.16.2+0"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
git-tree-sha1 = "9e2f36d3c96a820c678f2f1f1782582fcf685bae"
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"
version = "1.9.1"

[[deps.DocStringExtensions]]
git-tree-sha1 = "38ef52f18cbdfa783ec6c25acc23fb1e8525ec16"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.10.2"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.Enzyme]]
deps = ["CEnum", "EnzymeCore", "Enzyme_jll", "GPUCompiler", "InteractiveUtils", "LLVM", "Libdl", "LinearAlgebra", "ObjectFile", "PrecompileTools", "Preferences", "Printf", "Random", "ScopedValues", "SparseArrays"]
git-tree-sha1 = "49a2f5cefe1810e44e898377f4de6e1ec7b97c19"
uuid = "7da242da-08ed-463a-9acd-ee780be4f1d9"
version = "0.13.219"

    [deps.Enzyme.extensions]
    EnzymeBFloat16sExt = "BFloat16s"
    EnzymeCUDAExt = "CUDA"
    EnzymeChainRulesCoreExt = "ChainRulesCore"
    EnzymeGPUArraysCoreExt = "GPUArraysCore"
    EnzymeGPUArraysExt = "GPUArrays"
    EnzymeLogExpFunctionsExt = "LogExpFunctions"
    EnzymeOrderedCollectionsExt = "OrderedCollections"
    EnzymeSpecialFunctionsExt = "SpecialFunctions"
    EnzymeStaticArraysExt = "StaticArrays"

    [deps.Enzyme.weakdeps]
    ADTypes = "47edcb42-4c32-4615-8424-f2b9edc5f35b"
    BFloat16s = "ab4f0b2a-ad5b-11e8-123f-65d77653426b"
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    GPUArrays = "0c68f7d7-f131-5f86-a1c3-88cf8149b2d7"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
    LogExpFunctions = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
    OrderedCollections = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
    SpecialFunctions = "276daf66-3868-5448-9aa4-cd146d93841b"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.EnzymeCore]]
git-tree-sha1 = "d88c803e26799193db42e47f6e1e28eeb0322e4d"
uuid = "f151be2c-9106-41f4-ab19-57ee4f262869"
version = "0.8.27"

    [deps.EnzymeCore.extensions]
    AdaptExt = "Adapt"
    EnzymeCoreChainRulesCoreExt = "ChainRulesCore"

    [deps.EnzymeCore.weakdeps]
    Adapt = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"

[[deps.Enzyme_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl", "TOML"]
git-tree-sha1 = "5464e555af2b36b35ac10ceda173b35a5eee63ef"
uuid = "7cc45869-7501-5eee-bdea-0790c847d4ef"
version = "0.0.307+0"

[[deps.EpollShim_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "8a4be429317c42cfae6a7fc03c31bad1970c310d"
uuid = "2702e6a9-849d-5ed8-8c21-79e8b8f9ee43"
version = "0.0.20230411+1"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "f2659a735f9360fedfa29925812380f322679e93"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.10.0+0"

[[deps.ExprTools]]
git-tree-sha1 = "d2e49e7efd29719d6f28b891b0e0e159daa9d2b4"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.11"

[[deps.FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "7bd13840b4148949e290748071bbe6826b3eabcd"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.6"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "PCRE2_jll", "Zlib_jll", "libaom_jll", "libass_jll", "libfdk_aac_jll", "libva_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "d9d3cd382f2c999f684e6bfa4039fcc16c153b6f"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "9.0.2+0"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FixedPointNumbers]]
deps = ["Random", "Statistics"]
git-tree-sha1 = "59af96b98217c6ef4ae0dfe065ac7c20831d1a84"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.6"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Zlib_jll"]
git-tree-sha1 = "e1e9ba3a8f5d71e6ae698f138a1362aeabb42e9f"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.18.3+0"

[[deps.Format]]
git-tree-sha1 = "9c68794ef81b08086aeb32eeaf33531668d5f5fc"
uuid = "1fa38f19-a742-5d3f-a2b9-30dd87b9d5f8"
version = "1.3.7"

[[deps.FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "d95a7a3a7e0f2fffc6291bd33035830aab01310b"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.15.0+0"

[[deps.FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e894be022a2eba58463939f1bf1f7f7006f27f52"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.19+0"

[[deps.GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll", "libdecor_jll", "xkbcommon_jll"]
git-tree-sha1 = "64bbbb7d1499297751b536dd39c58b20750ab1db"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.5.1+0"

[[deps.GPUCompiler]]
deps = ["CompilerCaching", "ExprTools", "InteractiveUtils", "LLVM", "Libdl", "Logging", "PrecompileTools", "Preferences", "REPL", "ScopedValues", "TOML", "Tracy", "UUIDs", "tree_sitter_gcn_jll", "tree_sitter_llvm_jll", "tree_sitter_ptx_jll", "tree_sitter_spirv_jll"]
git-tree-sha1 = "6bf1aeb555d3b5dcf3d2af4b867945eb334498a7"
uuid = "61eb1bfa-7361-4325-ad38-22787b887f55"
version = "2.10.0"

    [deps.GPUCompiler.extensions]
    HighlightsExt = "Highlights"

    [deps.GPUCompiler.weakdeps]
    AMDGPU_LLVM_Backend_jll = "cc5c0156-bd05-5a77-8a68-bb0aafb29019"
    Highlights = "eafb193a-b7ab-5a9e-9068-77385905fa72"
    LLVMDowngrader_jll = "f52de702-fb25-5922-94ba-81dd59b07444"
    NVPTX_LLVM_Backend_jll = "ef6e0fe3-e6ef-59c0-bde6-4989574699e0"
    SPIRV_LLVM_Backend_jll = "4376b9bf-cff8-51b6-bb48-39421dff0d0c"
    SPIRV_LLVM_Translator_jll = "4a5d46fc-d8cf-5151-a261-86b458210efb"

[[deps.GR]]
deps = ["Artifacts", "Base64", "DelimitedFiles", "Downloads", "GR_jll", "JSON", "Libdl", "LinearAlgebra", "Preferences", "Printf", "Qt6Wayland_jll", "Random", "Serialization", "Sockets", "TOML", "Tar", "Test", "p7zip_jll"]
git-tree-sha1 = "4d777f73c46b46b8b5276206059cf8a195499314"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.73.27"

    [deps.GR.extensions]
    IJuliaExt = "IJulia"

    [deps.GR.weakdeps]
    IJulia = "7073ff75-c697-5162-941a-fcdaad2a7d2a"

[[deps.GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "FreeType2_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Qt6Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "f8eb8f7ba13ea75083531647fc8faeda8d541f07"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.73.27+0"

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

[[deps.Glib_jll]]
deps = ["Artifacts", "GettextRuntime_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE2_jll", "Zlib_jll"]
git-tree-sha1 = "ea9f1fb37ff10597353b56f3ba0ebd525acef6e0"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.90.1+0"

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "69ffb934a5c5b7e086a0b4fee3427db2556fba6e"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.16+0"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll"]
git-tree-sha1 = "59d266e426ab9695f625fe2b6a51c2d3a04f1ecd"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "100.15001.0+0"

[[deps.HashArrayMappedTries]]
git-tree-sha1 = "2eaa69a7cab70a52b9687c8bf950a5a93ec895ae"
uuid = "076d061b-32b6-4027-95e0-9a2c6f6d7e74"
version = "0.2.0"

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

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.IrrationalConstants]]
git-tree-sha1 = "d22e8bdb3f03c300a103ff23c0dd5a654c6701de"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.7"

[[deps.JLFzf]]
deps = ["REPL", "Random", "fzf_jll"]
git-tree-sha1 = "82f7acdc599b65e0f8ccd270ffa1467c21cb647b"
uuid = "1019f520-868f-41f5-a6de-eb00f4b6a39c"
version = "0.1.11"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "7204148362dafe5fe6a273f855b8ccbe4df8173e"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.8.0"

[[deps.JSON]]
deps = ["Dates", "Logging", "Parsers", "PrecompileTools", "StructUtils", "UUIDs", "Unicode"]
git-tree-sha1 = "06d90f699285d055e34f0b014636a75a17ff2252"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "1.13.4"

    [deps.JSON.extensions]
    JSONArrowExt = ["ArrowTypes"]
    JSONSerializationExt = ["Serialization"]

    [deps.JSON.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"
    Serialization = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e06b451acfb1c6fa5ea753b5042207226271f455"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.2.1+0"

[[deps.LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "059aabebaa7c82ccb853dd4a0ee9d17796f7e1bc"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.3+0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6d7c65411dda4bfa0beb7490476122b4f805cf31"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "4.3.0+0"

[[deps.LLVM]]
deps = ["CEnum", "LLVMExtra_jll", "Libdl", "PrecompileTools", "Preferences", "Printf", "Unicode"]
git-tree-sha1 = "3bcfa5cd59aecfc0680d8b5b8ea38237b009f112"
uuid = "929cbde3-209d-540e-8aea-75f648917ca0"
version = "9.13.2"

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

[[deps.LMDB]]
deps = ["CEnum", "LMDB_jll"]
git-tree-sha1 = "84e5cba87693714bfd67f589a91f24a996ff3e69"
uuid = "11f193de-5e89-5f17-923a-7d207d56daf9"
version = "3.0.1"

[[deps.LMDB_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "196c962b4d66b978b9be1e15e4e1d53441d5f028"
uuid = "6206cf0b-f360-5984-af49-5437264c140e"
version = "1.0.3+0"

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

[[deps.LibTracyClient_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "d4e20500d210247322901841d4eafc7a0c52642d"
uuid = "ad6e5548-8b26-5c9f-8ef3-ef0ad883f3a5"
version = "0.13.1+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

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
git-tree-sha1 = "b8a91037379e1fd661e9b5ff3d7a770424b1f9f2"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.42.4+0"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "XZ_jll", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "aebd334d06cee9f24cea70bd19a39749daf73881"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.7.3+0"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "9e887184f306b28dbfcff88cefbb0ec80f1aa9e0"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.42.4+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "52847246e86dd3dd88c39716748c57fd2bc43dce"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "1.0.6"

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

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+1"

[[deps.Measures]]
git-tree-sha1 = "b513cedd20d9c914783d8ad83d08120702bf2c77"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.3"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "d9d20d6eb2a3290ba5c70a1c013b45305cc39c9e"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.2.1"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2023.1.10"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "676c0f1c1c34224d6869675047a54b42fdc7b8c5"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.1.5"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.ObjectFile]]
deps = ["Reexport", "StructIO"]
git-tree-sha1 = "23c4d109603f7a7bfe888c1f63c5ab7be6183d0b"
uuid = "d8793406-e978-5875-9003-1fc021f44a92"
version = "0.5.1"

[[deps.Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "b6aa4566bb7ae78498a5e68943863fa8b5231b59"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.6+0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.23+4"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.1+2"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "20dd6a885a6fe8b07584d3eb8073133ad04c72e3"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.5.9+0"

[[deps.Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e2bb57a313a74b8104064b7efd01406c0a50d2ff"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.6.1+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "b079a6affebde167dad8ffe0d670b53917fbcb68"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "2.0.3"

[[deps.PCRE2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "efcefdf7-47ab-520b-bdef-62a2eaa19f15"
version = "10.42.0+1"

[[deps.Pango_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "FriBidi_jll", "Glib_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1912a9f1b9ca55005b03ba075f8e19993583e237"
uuid = "36c8627f-9965-5494-a995-c6b170f724f3"
version = "1.58.2+0"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools"]
git-tree-sha1 = "e5ae52d1f4f19a9591d615cb0f1ef8d415b40933"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "3.0.6"

[[deps.Pixman_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "LLVMOpenMP_jll", "Libdl"]
git-tree-sha1 = "e4a6721aa89e62e5d4217c0b21bd714263779dda"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.46.4+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.10.0"

[[deps.PlotThemes]]
deps = ["PlotUtils", "Statistics"]
git-tree-sha1 = "41031ef3a1be6f5bbbf3e8073f210556daeae5ca"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "3.3.0"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "PrecompileTools", "Printf", "Reexport", "Statistics"]
git-tree-sha1 = "ddcc36fd83fb4cd459a53c891981697bde0d3de6"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.5.1"

[[deps.Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "JLFzf", "JSON", "LaTeXStrings", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "Pkg", "PlotThemes", "PlotUtils", "PrecompileTools", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "RelocatableFolders", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "TOML", "UUIDs", "UnicodeFun", "Unzip"]
git-tree-sha1 = "83bd514e8ff16b5858ac54c53fa0bcf6002a3b00"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.41.7"

    [deps.Plots.extensions]
    FileIOExt = "FileIO"
    GeometryBasicsExt = "GeometryBasics"
    IJuliaExt = "IJulia"
    ImageInTerminalExt = "ImageInTerminal"
    UnitfulExt = "Unitful"

    [deps.Plots.weakdeps]
    FileIO = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
    GeometryBasics = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
    IJulia = "7073ff75-c697-5162-941a-fcdaad2a7d2a"
    ImageInTerminal = "d8c32880-2388-543b-8c61-d9f865259254"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "Downloads", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "9869376035f47756b8b8e711fd0d06a06d51da6f"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.84"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "5aa36f7049a63a1528fe8f7c3f2113413ffd4e1f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.1"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "aef1987d90dcc2e2cbd919ad10b2d25bcce4f418"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.6.1"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.PtrArrays]]
git-tree-sha1 = "4fbbafbc6251b883f4d2705356f3641f3652a7fe"
uuid = "43287f4e-b6f4-7ad1-bb20-aadabca52c3d"
version = "1.4.0"

[[deps.Qt6Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Vulkan_Loader_jll", "Xorg_libSM_jll", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_cursor_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "libinput_jll", "xkbcommon_jll"]
git-tree-sha1 = "144895f6166994730ee7ff8113b981fc360638f1"
uuid = "c0090381-4147-56d7-9ebc-da0b1113ec56"
version = "6.10.2+2"

[[deps.Qt6Declarative_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Qt6Base_jll", "Qt6ShaderTools_jll", "Qt6Svg_jll"]
git-tree-sha1 = "159d253ab126d5b29230cf53521899bea4ef4648"
uuid = "629bc702-f1f5-5709-abd5-49b8460ea067"
version = "6.10.2+2"

[[deps.Qt6ShaderTools_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Qt6Base_jll"]
git-tree-sha1 = "4d85eedf69d875982c46643f6b4f66919d7e157b"
uuid = "ce943373-25bb-56aa-8eca-768745ed7b5a"
version = "6.10.2+1"

[[deps.Qt6Svg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Qt6Base_jll"]
git-tree-sha1 = "81587ff5ff25a4e1115ce191e36285ede0334c9d"
uuid = "6de9746b-f93d-5813-b365-ba18ad4a9cf3"
version = "6.10.2+0"

[[deps.Qt6Wayland_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Qt6Base_jll", "Qt6Declarative_jll"]
git-tree-sha1 = "672c938b4b4e3e0169a07a5f227029d4905456f2"
uuid = "e99dba38-086e-5de3-a5b1-6e4c66e897c3"
version = "6.10.2+1"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.RecipesBase]]
deps = ["PrecompileTools"]
git-tree-sha1 = "5c3d09cc4f31f5fc6af001c250bf1278733100ff"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.3.4"

[[deps.RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "PrecompileTools", "RecipesBase"]
git-tree-sha1 = "45cf9fd0ca5839d06ef333c8201714e888486342"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.6.12"

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

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.ScopedValues]]
deps = ["HashArrayMappedTries", "Logging"]
git-tree-sha1 = "67a144433c4ce877ee6d1ada69a124d6b1ecf7be"
uuid = "7e506255-f358-4e82-b7e4-beb19740aa63"
version = "1.6.2"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "9b81b8393e50b7d4e6d0a9f14e192294d3b7c109"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.3.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Showoff]]
deps = ["Dates"]
git-tree-sha1 = "8238217340ad0aaabe11afe39c1098b5bc9f4c8e"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.1.1"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "13cd91cc9be159e3f4d95b857fa2aa383b53772a"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.3"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.10.0"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.10.0"

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

[[deps.StructIO]]
git-tree-sha1 = "c581be48ae1cbf83e899b14c07a807e1787512cc"
uuid = "53d494c1-5632-5724-8f4c-31dff12d585f"
version = "0.3.1"

[[deps.StructUtils]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "d9cfc07e1d1a8985aa9d03870d642b5d7ab2cf33"
uuid = "ec057cc2-7a8d-4b58-b3b3-92acb9f63b42"
version = "2.12.1"

    [deps.StructUtils.extensions]
    StructUtilsDBInterfaceExt = ["DBInterface", "Tables"]
    StructUtilsDataFramesExt = ["DataFrames"]
    StructUtilsLazilyInitializedFieldsExt = ["LazilyInitializedFields"]
    StructUtilsMeasurementsExt = ["Measurements"]
    StructUtilsStaticArraysCoreExt = ["StaticArraysCore"]
    StructUtilsTablesExt = ["Tables"]

    [deps.StructUtils.weakdeps]
    DBInterface = "a10d1c49-ce27-4219-8d33-6db1a4562965"
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    LazilyInitializedFields = "0e77f7df-68c5-4e49-93ce-4cd80f5598bf"
    Measurements = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
    StaticArraysCore = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
    Tables = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"

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

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.Tracy]]
deps = ["ExprTools", "LibTracyClient_jll", "Libdl"]
git-tree-sha1 = "73e3ff50fd3990874c59fef0f35d10644a1487bc"
uuid = "e689c965-62c8-4b79-b2c5-8359227902fd"
version = "0.1.6"

    [deps.Tracy.extensions]
    TracyProfilerExt = "TracyProfiler_jll"

    [deps.Tracy.weakdeps]
    TracyProfiler_jll = "0c351ed6-8a68-550e-8b79-de6f926da83c"

[[deps.Tricks]]
git-tree-sha1 = "311349fd1c93a31f783f977a71e8b062a57d4101"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.13"

[[deps.URIs]]
deps = ["Serialization"]
git-tree-sha1 = "eb3b85ca904a1d1647b15acc091b113b8874b648"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.7.3"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[deps.Unzip]]
git-tree-sha1 = "ca0969166a028236229f63514992fc073799bb78"
uuid = "41fe7b60-77ed-43a1-b4f0-825fd5a5650d"
version = "0.2.0"

[[deps.Vulkan_Loader_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Wayland_jll", "Xorg_libX11_jll", "Xorg_libXrandr_jll", "xkbcommon_jll"]
git-tree-sha1 = "2f0486047a07670caad3a81a075d2e518acc5c59"
uuid = "a44049a8-05dd-5a78-86c9-5fde0876e88c"
version = "1.3.243+0"

[[deps.Wayland_jll]]
deps = ["Artifacts", "EpollShim_jll", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll"]
git-tree-sha1 = "96478df35bbc2f3e1e791bc7a3d0eeee559e60e9"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.24.0+0"

[[deps.XZ_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e52eca002a11c30a858185efdfb15311e1c7a6bf"
uuid = "ffd25f8a-64ca-5728-b0f7-c24cf3aae800"
version = "5.8.4+0"

[[deps.Xorg_libICE_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "a3ea76ee3f4facd7a64684f9af25310825ee3668"
uuid = "f67eecfb-183a-506d-b269-f58e52b52d7c"
version = "1.1.2+0"

[[deps.Xorg_libSM_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libICE_jll"]
git-tree-sha1 = "9c7ad99c629a44f81e7799eb05ec2746abb5d588"
uuid = "c834827a-8449-5923-a945-d239c165b7dd"
version = "1.2.6+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "ce91b54a5f90c4f27df6950706234b34e49cf79e"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.8.14+0"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "aa1261ebbac3ccc8d16558ae6799524c450ed16b"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.13+0"

[[deps.Xorg_libXcursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libXfixes_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "6c74ca84bbabc18c4547014765d194ff0b4dc9da"
uuid = "935fb764-8cf2-53bf-bb30-45bb1f8bf724"
version = "1.2.4+0"

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

[[deps.Xorg_libXi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libXext_jll", "Xorg_libXfixes_jll"]
git-tree-sha1 = "704274ca960c42049fd9bda089fc4be32af5cdca"
uuid = "a51aa0fd-4e3c-5386-b890-e753decda492"
version = "1.8.5+0"

[[deps.Xorg_libXinerama_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libXext_jll"]
git-tree-sha1 = "0ba01bc7396896a4ace8aab67db31403c71628f4"
uuid = "d1454406-59df-5ea1-beac-c340f2130bc3"
version = "1.1.7+0"

[[deps.Xorg_libXrandr_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libXext_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "6c174ef70c96c76f4c3f4d3cfbe09d018bcd1b53"
uuid = "ec84b674-ba8e-5d96-8ba1-2a689ba10484"
version = "1.5.6+0"

[[deps.Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "a54cf54677c9f6eac0d97e9d757c233b56bc21b9"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.13+0"

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

[[deps.Xorg_libxkbfile_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "ed756a03e95fff88d8f738ebc2849431bdd4fd1a"
uuid = "cc61e674-0454-545c-8b26-ed2c68acab7a"
version = "1.2.0+0"

[[deps.Xorg_xcb_util_cursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_jll", "Xorg_xcb_util_renderutil_jll"]
git-tree-sha1 = "9750dc53819eba4e9a20be42349a6d3b86c7cdf8"
uuid = "e920d4aa-a673-5f3a-b3d7-f755a4d47c43"
version = "0.1.6+0"

[[deps.Xorg_xcb_util_image_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xcb_util_jll"]
git-tree-sha1 = "f4fc02e384b74418679983a97385644b67e1263b"
uuid = "12413925-8142-5f55-bb0e-6d7ca50bb09b"
version = "0.4.1+0"

[[deps.Xorg_xcb_util_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll"]
git-tree-sha1 = "68da27247e7d8d8dafd1fcf0c3654ad6506f5f97"
uuid = "2def613f-5ad1-5310-b15b-b15d46f528f5"
version = "0.4.1+0"

[[deps.Xorg_xcb_util_keysyms_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xcb_util_jll"]
git-tree-sha1 = "44ec54b0e2acd408b0fb361e1e9244c60c9c3dd4"
uuid = "975044d2-76e6-5fbe-bf08-97ce7c6574c7"
version = "0.4.1+0"

[[deps.Xorg_xcb_util_renderutil_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xcb_util_jll"]
git-tree-sha1 = "5b0263b6d080716a02544c55fdff2c8d7f9a16a0"
uuid = "0d47668e-0667-5a69-a72c-f761630bfb7e"
version = "0.3.10+0"

[[deps.Xorg_xcb_util_wm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xcb_util_jll"]
git-tree-sha1 = "f233c83cad1fa0e70b7771e0e21b061a116f2763"
uuid = "c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"
version = "0.4.2+0"

[[deps.Xorg_xkbcomp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxkbfile_jll"]
git-tree-sha1 = "9a5e6e8f1a7c40941465c04840145e527f0d6b4b"
uuid = "35661453-b289-5fab-8a00-3d9160c6a3a4"
version = "1.5.0+0"

[[deps.Xorg_xkeyboard_config_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xkbcomp_jll"]
git-tree-sha1 = "df77b22eb77051b3d0ef30aab979684f7482c66f"
uuid = "33bec58e-1273-512f-9401-5d533626f822"
version = "2.48.0+0"

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

[[deps.eudev_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c3b0e6196d50eab0c5ed34021aaa0bb463489510"
uuid = "35ca27e7-8b34-5b7f-bca9-bdc33f59eb06"
version = "3.2.14+0"

[[deps.fzf_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "b6a34e0e0960190ac2a4363a1bd003504772d631"
uuid = "214eeab7-80f7-51ab-84ad-2988db7cef09"
version = "0.61.1+0"

[[deps.libaom_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "21e05cef1411bfe6b22a1ca8cbdc64a297d4b447"
uuid = "a4ae2306-e953-59d6-aa16-d00cac43593b"
version = "3.15.3+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "cb007192783c56d8249db4cf0e3495001edfe414"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.17.5+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.8.0+1"

[[deps.libdecor_jll]]
deps = ["Artifacts", "Dbus_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pango_jll", "Wayland_jll", "xkbcommon_jll"]
git-tree-sha1 = "9bf7903af251d2050b467f76bdbe57ce541f7f4f"
uuid = "1183f4f0-6f2a-5f1a-908b-139f9cdfea6f"
version = "0.2.2+0"

[[deps.libdrm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libpciaccess_jll"]
git-tree-sha1 = "28e57478e8a160d346a19c28b3fffb9273bcc9c2"
uuid = "8e53e030-5e6c-5a89-a30b-be5b7263a166"
version = "2.4.134+0"

[[deps.libevdev_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "56d643b57b188d30cccc25e331d416d3d358e557"
uuid = "2db6ffa8-e38f-5e21-84af-90c45d0032cc"
version = "1.13.4+0"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "646634dd19587a56ee2f1199563ec056c5f228df"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.4+0"

[[deps.libinput_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "eudev_jll", "libevdev_jll", "mtdev_jll"]
git-tree-sha1 = "91d05d7f4a9f67205bd6cf395e488009fe85b499"
uuid = "36db933b-70db-51c0-b978-0f229ee0e533"
version = "1.28.1+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "1fcd6cf05d23adab0b5ffc496d020537215751dc"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.59+1"

[[deps.libva_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll", "Xorg_libXext_jll", "Xorg_libXfixes_jll", "libdrm_jll"]
git-tree-sha1 = "21cbc8fc2ac0bb182ed461e556d9c062ae6a3164"
uuid = "9a156e7d-b971-5f62-b2c9-67348b8fb97c"
version = "2.24.1+0"

[[deps.libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll"]
git-tree-sha1 = "11e1772e7f3cc987e9d3de991dd4f6b2602663a5"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.8+0"

[[deps.mtdev_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "b4d631fd51f2e9cdd93724ae25b2efc198b059b1"
uuid = "009596ad-96f7-51b1-9f1b-5ce2d5e8a71e"
version = "1.1.7+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.52.0+1"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"

[[deps.tree_sitter_gcn_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "7aea9f731552967bda93cb7cbf6925de65bc38d5"
uuid = "8b5cbfcf-8811-596e-8e87-0e51e05ee4b2"
version = "0.1.0+0"

[[deps.tree_sitter_llvm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "2fb7d0e3a8abf532fa922766ca130bf814df1e70"
uuid = "44208993-ee63-5069-9443-8e43b04a9b30"
version = "1.1.0+0"

[[deps.tree_sitter_ptx_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e6ad264eebe3e34f03bca6b5e811d80e0f4797a2"
uuid = "71e3f6e6-c059-5e7c-a2f2-d560fdad7ce5"
version = "0.1.0+0"

[[deps.tree_sitter_spirv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "7d8c03949bab84b23fe0500d89979e786d54a653"
uuid = "f0e86581-c468-54df-a4de-3266e11a3c86"
version = "0.1.0+0"

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

[[deps.xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "a1fc6507a40bf504527d0d4067d718f8e179b2b8"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "1.13.0+0"
"""

# ╔═╡ Cell order:
# ╟─7ee72db5-ef43-47e4-905e-bba3e4c79a37
# ╠═13178939-2b8f-4ded-8473-361dcb97b310
# ╟─8514be47-a0a8-4e67-ae8c-f3cd7f5e2c31
# ╟─8cd1dde1-6e63-4162-9d73-bae45f4b5484
# ╟─7337e780-9b56-4e6c-be09-e9acd08ac14e
# ╠═e026bf9f-2b52-42f9-a3fd-e43e61c7711a
# ╠═2b88b61c-72f1-4337-a622-61851e2a9186
# ╠═620bab60-ab2f-4b9a-a465-6a05561001a2
# ╠═4a3c3b86-08cf-4a6b-b0a9-bbe2f2f5dd78
# ╠═53c8d9b1-991a-4084-b38b-7a981c6c3dec
# ╠═b8d50454-4ec0-4a71-a603-35114e951188
# ╠═e78c481e-2e2f-41b9-ae60-012ef48d4e4b
# ╠═e2ad7e32-b3e2-4a28-bde2-680fa13a4f15
# ╠═6517c61e-cd76-4877-9eeb-630b268e89ab
# ╠═d48e56ac-a1e4-4482-a357-c107fb67eaa7
# ╠═35804463-5e1f-4933-bce2-48a614d999bb
# ╟─af42ef44-a2e2-425c-92fb-c19bb730cf38
# ╟─17cee903-8ddb-4a06-8944-ad6335f20cac
# ╟─e925df77-8556-4a15-b310-efa6aceac0a2
# ╟─e01f965b-e61e-4aed-a822-53580982cb45
# ╟─0e0a7d57-3cf6-437b-b866-22c93f2fdf4f
# ╠═deb4f8e0-33b8-42aa-8fb3-c0bb8d42fff6
# ╠═529732b0-2b41-4968-b2c4-fc7376bc4317
# ╠═d0ddcbdd-c532-493b-a5b8-6fb70325e949
# ╟─a1c4bd15-01d4-474f-8e40-caa2de869405
# ╠═917b2e43-0dfe-4438-b064-98c215e4edd8
# ╠═30543463-4ec0-4197-a40a-234d90646641
# ╠═84c93d05-4b60-4071-830d-a77b14cffaad
# ╟─1d618830-5f36-4c8f-bc3e-539f1daa2750
# ╠═9019f3b6-9098-43b6-b03d-5b3380b97489
# ╠═fe13f927-d4ff-4a39-a8b0-6a0ce08884d6
# ╟─7f9ea423-c757-4383-8bb0-0abe5a102990
# ╠═1a78113d-1e50-44f6-84e7-cb021dba3d71
# ╠═68d44df6-db4c-4a43-9654-b68d660402e0
# ╠═e58c06bb-e71e-415d-aaa0-2abec87c55f5
# ╠═292a230d-3309-4042-b281-27328cf390a0
# ╠═d2e89515-24e6-4a24-a759-862915e750da
# ╟─a6ad4272-57d3-4400-836c-f332cec48028
# ╠═e62d4c1f-54d7-4b54-b2cb-0d213ed7eed7
# ╠═f510e2d1-1fad-4b2c-97c4-c3bc116e8b31
# ╠═d8acb75e-80dc-43b2-9bae-a5c647ce9170
# ╠═e492178c-120b-47d8-9a4d-e28c95601739
# ╟─814ebe27-9afa-461d-8c26-103c6b69b952
# ╠═c53a452a-cdd2-4976-8627-45147f04356d
# ╟─26e4082e-0b0a-49d0-9332-e0518c6e5acb
# ╟─e21ca5a4-be94-47ee-9d44-cae358c57589
# ╠═12ce43e7-8058-4e48-b805-1dffb2681c61
# ╟─49410069-3a5c-4cb3-92bb-15a972c3e900
# ╟─8717b85a-f56f-4661-9773-52f00f2572ae
# ╟─7761f78b-68f7-46d8-8255-37a44284bb2f
# ╟─96b2cb9a-fc9e-4c46-9cac-e1f6e5ed3d73
# ╠═dd76d7e6-1c71-4032-98db-7e8b202e97cb
# ╠═ea6206c9-c982-42dd-8e5f-75187197ad14
# ╠═7120c2dc-34dc-4aa4-ad91-54f13f9d7860
# ╠═71473ad0-0cb3-4259-9346-eb99fb414be8
# ╠═22edafbe-8d11-4736-8ab6-c9237922db84
# ╠═fdba8aa2-bda3-4e2e-b72a-968044503be4
# ╠═9258219c-34e2-4f7a-b84f-2277eb471d60
# ╠═13a01a94-2fc1-410d-95e0-ab902df05f35
# ╟─4cad2121-380e-46b2-b7ba-d74197066907
# ╟─c402796b-aa6f-47c1-8b67-7b9a4b50cf3a
# ╟─a51685a0-7c17-4957-ad25-a67fe42f1fd4
# ╟─65c9b965-bdf6-4a2d-a2ce-8785380ced1d
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
