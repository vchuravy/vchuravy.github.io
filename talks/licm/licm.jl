### A Pluto.jl notebook ###
# v0.19.30

#> [frontmatter]
#> title = "Manual LICM in Julia"
#> date = "2024-10-29"
#> license = "MIT"
#> 
#>     [[frontmatter.author]]
#>     name = "Valentin Churavy"
#>     url = "https://vchuravy.dev"

using Markdown
using InteractiveUtils

# ╔═╡ 650e532e-7686-11ee-0674-dd9416ef104e
# ╠═╡ show_logs = false
begin
	import Pkg
	Pkg.add(url="https://github.com/vchuravy/Loops.jl")
	Pkg.add(url="https://github.com/vchuravy/ShowCode.jl")
	using Loops
	using ShowCode
	import Core.Compiler
end

# ╔═╡ 279d08aa-ac9a-46d3-a8eb-8ea0ad6a4cf5
versioninfo()

# ╔═╡ 37c87261-b14d-41fa-a6dc-518f01c10bf1
md"""
# LICM

!!! note
    This notebook requires 1.10

Developing a LICM pass for Julia's high-level IR.
This notebook is walking-through performing LICM
using Loops.jl

On the function:

```julia
function f1(A, x)
    acc = zero(eltype(A))
    for a in A
        acc += sin(x) * a
    end
    return acc
end
```

!!! note
    Terminology used here is consistent with https://llvm.org/docs/LoopTerminology.html#terminology

### Acknowledgements :
- Takafumi Arakaki's work:
  - ShowCode.jl
  - https://nbviewer.org/gist/tkf/d4734be24d2694a3afd669f8f50e6b0f/00_notebook.ipynb
  - https://github.com/JuliaLang/julia/pull/45305
"""

# ╔═╡ 12f7c5d6-5f26-4aa6-a4b5-830d51b66597
struct CFGDot <: ShowCode.Implementations.AbstractLazyDot
    ir::Core.Compiler.IRCode
    include_code::Bool
end

# ╔═╡ 2b28dea4-a53f-4391-9dad-21e754074c15
function f1(A, x)
    acc = zero(eltype(A))
    for a in A
        acc += sin(x) * a
    end
    return acc
end

# ╔═╡ c19a3e6b-27ec-4661-b228-34cdff0e7ed4
md"""
### First steps

Using `Base.code_ircode` we can optain the IR in the right format,
after SSA conversion.

IRCode contains a CFG and we can also construct a dom-tree from it.

Using the dom-tree we can find loops in the IR itself

"""

# ╔═╡ 90a65de3-8bef-42e5-ab60-665279113cb6
(ir, rt) = only(Base.code_ircode(
					f1, (Vector{Float64}, Float64),
					optimize_until = "compact 1"))

# ╔═╡ 4ad1978c-3c95-4ab7-be67-a1fbba1d174f
function Base.summary(io::IO, d::CFGDot)
    print(io, "CFG for $(ir.argtypes)")
end


# ╔═╡ fdeeb2d8-043b-4e14-8f6e-a365311f621a
begin
	import ShowCode.Implementations: escape_dot_label, print_bb_stmts_for_dot_label
	
function ShowCode.Implementations.print_dot(io::IO, dot::CFGDot)
   	ir=dot.ir
	include_code=dot.include_code

    function bblabel(i)
        inst = ir.stmts.inst[ir.cfg.blocks[i].stmts[end]]
        if inst isa Core.ReturnNode
            if isdefined(inst, :val)
                return "#$(i)⏎"
            else
                return "#$(i)⚠"
            end
        end
        return string("#", i)
    end

    graphname = summary(dot)
    print(io, "digraph \"")
    escape_dot_label(io, graphname)
    println(io, "\" {")
    indented(args...) = print(io, "    ", args...)
    indented("label=\"")
    escape_dot_label(io, graphname)
    println(io, "\";")
    for (i, bb) in enumerate(ir.cfg.blocks)
        indented(i, " [shape=record")

        # Print code
        if include_code
            print(io, ", label=\"{$(bblabel(i)):\\l")
        else
            print(io, ", label=\"{$(bblabel(i))}\", tooltip=\"")
        end
        print_bb_stmts_for_dot_label(io, ir, bb)
        if include_code
            print(io, "}\"")
        else
            print(io, '"')
        end
        println(io, "];")

        # Print edges
        term = ir.stmts[bb.stmts[end]][:inst]
            if term isa Expr && term.head === :enter
                attr = "label = \" E\""
            elseif term isa Expr && term.head === :leave
                attr = "label = \" L\""
            else
                attr = ""
            end
            for s in bb.succs
                attr2 = i == s ? "dir = back " : ""
                indented(i, " -> ", s, " [", attr2, attr, "]", ";\n")
            end
    end
    println(io, '}')
end


end #begin

# ╔═╡ 90cce8dc-5806-46ac-9611-70754a429bc7
ir.cfg

# ╔═╡ 48d67b63-3f3a-4dea-b19b-4ab67faf23c0
domtree = Core.Compiler.construct_domtree(ir.cfg.blocks)

# ╔═╡ c43b82b6-c03a-48ee-9728-704687346226
loops = Loops.construct_loopinfo(ir, domtree)

# ╔═╡ 8247d1bd-b4a9-49dc-976d-7df4c7fdf503
header, LI = first(loops)

# ╔═╡ 9b5e7ad5-526d-4ff8-a8ec-dc2ba734a2d4
md"""
## Step 1: Insert pre-header
"""

# ╔═╡ 982d9412-7af0-457c-a669-b1a2dca79249
CFGDot(ir, true)

# ╔═╡ 09e695c1-1b44-4207-a045-9198b2e7988c
md"""
We insert a pre-header by splitting the header at the first instructions.

Since this is the first statement of the BB, it creates a pre-header with a single
passthrough goto statements

We will put loop-invariant code into the pre-header. Thus, we delete the edges from the latches to the pre-header and change them to the header.

Taking care to renumber the PhiNodes so that previous entering blocks are now the pre-header.

"""

# ╔═╡ 05a0272a-ceec-4a64-b6d7-842f774fb870
function insert_preheader!(ir, LI)
	header = LI.header
	preds = ir.cfg.blocks[header].preds
	entering = filter(BB->BB ∉ LI.blocks, preds)
	
	# split the header
	split = first(ir.cfg.blocks[header].stmts)
	info = Loops.allocate_goto_sequence!(ir, [split => 0])

	map!(BB->info.bbchangemap[BB], entering, entering)
	
	preheader = header
	header = info.bbchangemap[header]
	
	on_phi_label(i) = i ∈ entering ? preheader : i

	for stmt in ir.cfg.blocks[header].stmts
		inst = ir.stmts[stmt][:inst]
		if inst isa Core.Compiler.PhiNode
            edges = inst.edges::Vector{Int32}
            for i in 1:length(edges)
                edges[i] = on_phi_label(edges[i])
            end
		else
			continue
		end
	end

	# TODO: should we mutate LI instead?
	blocks = map(BB->info.bbchangemap[BB], LI.blocks)
	latches = map(BB->info.bbchangemap[BB], LI.latches)

	for latch in latches
		Core.Compiler.cfg_delete_edge!(ir.cfg, latch, preheader)
		Core.Compiler.cfg_insert_edge!(ir.cfg, latch, header)
		stmt = ir.stmts[last(ir.cfg.blocks[4].stmts)]
		Core.Compiler.setindex!(stmt, Core.Compiler.GotoNode(header), :inst)
	end

	Compiler.verify_ir(ir)
	
	return preheader, Loops.LoopInfo(header, latches, blocks)
end

# ╔═╡ 681f22ec-b14c-400c-9b3c-7686ec83f332
begin
	ir1 = Compiler.copy(ir)
	preheader, LI1 = insert_preheader!(ir1, LI)
	CFGDot(ir1, true)
end

# ╔═╡ 4b6bc13e-8d77-4705-87fb-3b4dbcda52a6
md"""
Now we want to move the invariant statements into the pre-header.

An invariant statement is a statement that depends only statements outside the loop,
or other invariant statements, and is EFFECT_FREE. It may throw which is why we move
them to the pre-header.
"""

# ╔═╡ 9eed2c82-27d0-48da-8bef-8fabc67a01f2
begin
	import Core.Compiler: Argument, GlobalRef, QuoteNode, SSAValue

function invariant_stmt(ir, LI, invariant_stmts, stmt)
    if stmt isa Expr
        return invariant_expr(ir, LI, invariant_stmts, stmt)
    end
    return invariant(ir, LI, invariant_stmts, stmt)
end

function invariant(ir, LI, invariant_stmts, stmt)
    if stmt isa Argument || stmt isa GlobalRef || stmt isa QuoteNode || stmt isa Bool
        return true
	elseif stmt isa SSAValue
        id = stmt.id
        bb = Core.Compiler.block_for_inst(ir.cfg, id)
        if bb ∉ LI.blocks
            return true
        end
        return id ∈ invariant_stmts 
    end
    return false
end

function invariant_expr(ir, LI, invariant_stmts, stmt)
    invar = true
	# Due to us being outside the compiler... Iteration over compiler structs
	# doesn't work.
	state = Core.Compiler.iterate(Core.Compiler.userefs(stmt))
	while state !== nothing
		useref, next  = state

		invar &= invariant(ir, LI, invariant_stmts, Core.Compiler.getindex(useref))
		
		state = Core.Compiler.iterate(Core.Compiler.userefs(stmt), next)
	end
    # for useref in Core.Compiler.userefs(stmt)
    #     invar &= invariant(ir, loop, invariant_stmts, useref[])
    # end
    return invar
end

function invariant_stmts(ir, LI)
	stmts = Int[]
	for BB in LI.blocks
		for stmt in ir.cfg.blocks[BB].stmts
			# Okay to throw
			if (ir.stmts[stmt][:flag] & Compiler.IR_FLAG_EFFECT_FREE) != 0
				# Check if stmt is invariant
				if invariant_stmt(ir, LI, stmts, ir.stmts[stmt][:inst])
					push!(stmts, stmt)
				end
			end
		end
	end
	return stmts
end
	
end

# ╔═╡ d73365c1-4d08-4572-81d0-2c122829a609
function move_invariant!(ir, preheader, LI)
	insertion_point = last(ir.cfg.blocks[preheader].stmts)
	stmts = invariant_stmts(ir, LI)
	inserter = Core.Compiler.InsertBefore(ir, SSAValue(insertion_point))
	for stmt in stmts
		invariant = ir.stmts[stmt]
		new_stmt = inserter(Core.Compiler.NewInstruction(ir.stmts[stmt]))
		Core.Compiler.setindex!(
			ir.stmts, new_stmt, stmt)
	end
	ir = Core.Compiler.compact!(ir)
end

# ╔═╡ 65f9150f-3adc-4a23-80a2-e1fa7cf24bb2
begin
	ir2 = Compiler.copy(ir1)
	ir2 = move_invariant!(ir2, preheader, LI1)
	CFGDot(ir2, true)
end

# ╔═╡ 8542b4d9-a85d-44c4-a114-b3abde005630
md"""
We move the statement by inserting the copy of the original instruction and referring this SSA register from the original instruction. `compact!` cleans it up:
"""

# ╔═╡ Cell order:
# ╠═279d08aa-ac9a-46d3-a8eb-8ea0ad6a4cf5
# ╟─37c87261-b14d-41fa-a6dc-518f01c10bf1
# ╟─650e532e-7686-11ee-0674-dd9416ef104e
# ╟─12f7c5d6-5f26-4aa6-a4b5-830d51b66597
# ╟─4ad1978c-3c95-4ab7-be67-a1fbba1d174f
# ╟─fdeeb2d8-043b-4e14-8f6e-a365311f621a
# ╠═2b28dea4-a53f-4391-9dad-21e754074c15
# ╟─c19a3e6b-27ec-4661-b228-34cdff0e7ed4
# ╠═90a65de3-8bef-42e5-ab60-665279113cb6
# ╠═90cce8dc-5806-46ac-9611-70754a429bc7
# ╠═48d67b63-3f3a-4dea-b19b-4ab67faf23c0
# ╠═c43b82b6-c03a-48ee-9728-704687346226
# ╠═8247d1bd-b4a9-49dc-976d-7df4c7fdf503
# ╟─9b5e7ad5-526d-4ff8-a8ec-dc2ba734a2d4
# ╠═982d9412-7af0-457c-a669-b1a2dca79249
# ╟─09e695c1-1b44-4207-a045-9198b2e7988c
# ╠═681f22ec-b14c-400c-9b3c-7686ec83f332
# ╠═05a0272a-ceec-4a64-b6d7-842f774fb870
# ╟─4b6bc13e-8d77-4705-87fb-3b4dbcda52a6
# ╠═9eed2c82-27d0-48da-8bef-8fabc67a01f2
# ╠═d73365c1-4d08-4572-81d0-2c122829a609
# ╠═65f9150f-3adc-4a23-80a2-e1fa7cf24bb2
# ╟─8542b4d9-a85d-44c4-a114-b3abde005630
