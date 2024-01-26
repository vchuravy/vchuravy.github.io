### A Pluto.jl notebook ###
# v0.19.37

using Markdown
using InteractiveUtils

# ╔═╡ 2204e792-fc25-462d-b002-31ea1d09f7a0
function f1(cond, v)
	x = Ref{Int}(0)
	if cond
		x[] = v
	else
		return -1
	end
	if v > 5
		return x[] 
	end
	return -2
end

# ╔═╡ e4163cf6-4e0f-4fb4-af1e-a6c7529c7e41
f1(true, 4)

# ╔═╡ 6a1556b2-bbe9-11ee-1b16-151b1d98396d
(ir, rt) = only(Base.code_ircode(
					f1, (Bool,Int),
					optimize_until = "compact 1"))

# ╔═╡ 200e2edf-74be-40c4-bc75-1a9d6b024f48
const CC = Core.Compiler

# ╔═╡ 05252405-1f7d-40ff-965c-995b46a8324b
begin
	defs = Int[
		2
	]
	uses = Int[
		4, 7
	]
end

# ╔═╡ 6d8d3244-88ff-45bf-be1d-2f5a4611307d
ir.cfg

# ╔═╡ 1307f6f4-1de6-4ea8-bc58-2bcb824b5ddd
CC.compute_live_ins(ir.cfg, sort(defs), uses)

# ╔═╡ Cell order:
# ╠═e4163cf6-4e0f-4fb4-af1e-a6c7529c7e41
# ╠═2204e792-fc25-462d-b002-31ea1d09f7a0
# ╠═6a1556b2-bbe9-11ee-1b16-151b1d98396d
# ╠═200e2edf-74be-40c4-bc75-1a9d6b024f48
# ╠═05252405-1f7d-40ff-965c-995b46a8324b
# ╠═6d8d3244-88ff-45bf-be1d-2f5a4611307d
# ╠═1307f6f4-1de6-4ea8-bc58-2bcb824b5ddd
