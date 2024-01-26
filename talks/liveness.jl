### A Pluto.jl notebook ###
# v0.19.37

using Markdown
using InteractiveUtils

# ╔═╡ 200e2edf-74be-40c4-bc75-1a9d6b024f48
const CC = Core.Compiler

# ╔═╡ 1307f6f4-1de6-4ea8-bc58-2bcb824b5ddd


# ╔═╡ 09b192cf-0c8c-44d9-b23b-7f3d522753e7
begin
	struct DefUse
		defs::Vector{Int}
		uses::Vector{Int}
	end
	DefUse() = DefUse(Int[], Int[])
end

# ╔═╡ 9c6de8e4-5577-4c6f-bf42-1f40be5049d7
begin
	import .CC: InsertHere, SSAValue, IncrementalCompact, NewInstruction, NoCallInfo, IRCode,
            is_known_call, simple_walk, widenconst, LazyDomtree, isexpr, non_dce_finish!,
            simple_dce!, complete, argextype, argument_datatype, SPCSet, SSADefUse, SSAUse,
            IntermediaryCollector, userefs, UseRefIterator, UseRef

Base.iterate(compact::IncrementalCompact, state=nothing) = CC.iterate(compact, state)
Base.iterate(idset::Core.Compiler.IdSet, state...) = CC.iterate(idset, state...)
Base.iterate(useref::UseRefIterator, state...) = CC.iterate(useref, state...)

Base.getindex(compact::IncrementalCompact, idx) = CC.getindex(compact, idx)
Base.getindex(useref::UseRef) = CC.getindex(useref)

Base.length(idset::Core.Compiler.IdSet) = CC.length(idset)
end

# ╔═╡ 519754f6-3cc4-4d38-8bf8-420c0e11c3ff
isinteresting(T::Type) = T <: Base.Ref

# ╔═╡ 2018d269-3e60-4c02-9d55-feb64eb3f113
function find_defuse!(ir)
	compact = IncrementalCompact(ir)
	defuses = Dict{Union{CC.SSAValue, CC.Argument}, DefUse}()

	for (i, T) in enumerate(ir.argtypes)
		if isinteresting(widenconst(T))
			defuses[CC.Argument(i)] = DefUse([1], Int[])
		end
	end
	
	compact = IncrementalCompact(ir)

	# XXX: SROA uses simple_walk + IntermediaryCollector

	for ((old_idx, idx), stmt) in compact
        if !(stmt isa Expr)
            continue
        end
        inst = compact[SSAValue(idx)]

		for op in CC.userefs(stmt)
			val = op[]
			if isa(val, CC.SSAValue) || isa(val, CC.Argument)
				defuse = get(defuses, val, nothing)
				if defuse !== nothing
					push!(defuse.uses, idx)
				end
			end
		end

		# any call that returns our value is considered a def
		if isinteresting(widenconst(inst[:type]))
			if is_known_call(stmt, setfield!, compact)
				val = stmt.args[4]
			else
				val = SSAValue(idx)
			end
			defuse = get!(()->DefUse(), defuses, val)
			push!(defuse.defs, idx)
		end
	end
	
	defuses
end

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

# ╔═╡ 6f3f2f32-0d66-4b7f-a701-803376967472
defuses = find_defuse!(CC.copy(ir))

# ╔═╡ 6d8d3244-88ff-45bf-be1d-2f5a4611307d
ir.cfg

# ╔═╡ 156456d5-7a66-4b8b-88f4-f5083e98ea9e
[CC.compute_live_ins(ir.cfg, sort(defuse.defs), defuse.uses) for (idx, defuse) in defuses]

# ╔═╡ Cell order:
# ╠═e4163cf6-4e0f-4fb4-af1e-a6c7529c7e41
# ╠═200e2edf-74be-40c4-bc75-1a9d6b024f48
# ╠═1307f6f4-1de6-4ea8-bc58-2bcb824b5ddd
# ╠═09b192cf-0c8c-44d9-b23b-7f3d522753e7
# ╠═9c6de8e4-5577-4c6f-bf42-1f40be5049d7
# ╠═519754f6-3cc4-4d38-8bf8-420c0e11c3ff
# ╠═2018d269-3e60-4c02-9d55-feb64eb3f113
# ╠═6f3f2f32-0d66-4b7f-a701-803376967472
# ╠═2204e792-fc25-462d-b002-31ea1d09f7a0
# ╠═6a1556b2-bbe9-11ee-1b16-151b1d98396d
# ╠═6d8d3244-88ff-45bf-be1d-2f5a4611307d
# ╠═156456d5-7a66-4b8b-88f4-f5083e98ea9e
