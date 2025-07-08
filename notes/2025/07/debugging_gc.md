@def title = "How I debug issues with Julia GC"
@def hascode = true
@def hascomments = true
@def date = Date(2025, 7, 8)
@def rss = "How I debug issues with Julia GC"
@def tags = ["compiler", "gc", "julia", "note"]

# How I debug issues with Julia GC
\toc

## Testing the reproducer

### Memory constraints

```sh
systemd-run --scope -p MemoryMax=1G --user ~/src/julia-1.11/julia --project=. mwe.jl
```


## Building Julia

## Debugging the issue under rr

### Recording

!!! note 
    Chaos-mode

```sh
rr record ~/src/julia-1.11/julia --project=. mwe.jl
```

```
rr: Saving execution to trace directory `/home/vchuravy/.local/share/rr/julia-33'.
GC error (probable corruption)
Allocations: 475477084 (Pool: 475474415; Big: 2669); GC: 914
<?#0x7fdfa490baa0::(nil)>

thread 0 ptr queue:
~~~~~~~~~~ ptr queue top ~~~~~~~~~~
Base.BitSet(bits=Array{UInt64, 1}(dims=(35,), mem=Memory{UInt64}(69, 0x7fdf94338020)[0x4000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000001000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000010, 0x0000000000000000, 0x0000008000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000080000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000008, 0x0000008000000000, 0x0000000000000000, 0x0000000000000010, 0x0000000000000000, 0x0000000000000000, 0x0000000000001000, 0x0001804000000000, 0x0000000000000000, 0x0000000000100000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000]), offset=0)
==========
Base.BitSet(bits=Array{UInt64, 1}(dims=(35,), mem=Memory{UInt64}(41, 0x7fdfa5eb9ce0)[0x0000008000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000080000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000008, 0x0000008000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000]), offset=0)
==========
Base.BitSet(bits=Array{UInt64, 1}(dims=(0,), mem=Memory{UInt64}(4, 0x7fdfdc0380a0)[0x0001000000000000, 0x0000000000000800, 0x0000000000000001, 0x00007fdf93077050]), offset=-1152921504606846976)
==========
Base.BitSet(bits=Array{UInt64, 1}(dims=(2,), mem=Memory{UInt64}(4, 0x7fdfdc51c5e0)[0x0000000000000008, 0x0000008000000000, 0x0000000080000000, 0x00007fdf97e44090]), offset=33)
==========
Base.BitSet(bits=Array{UInt64, 1}(dims=(0,), mem=Memory{UInt64}(4, 0x7fdfa8226ba0)[0x0010000000000000, 0x3fec28f5c28f5c29, 0x00007fdf94d4f290, 0x40c3880000000000]), offset=-1152921504606846976)
==========
Base.BitSet(bits=Array{UInt64, 1}(dims=(1,), mem=Memory{UInt64}(4, 0x7fdfdc0fd8a0)[0x0000000000000008, 0x0000000000000010, 0x0000000000008000, 0x0000000000000000]), offset=33)
==========
Base.BitSet(bits=Array{UInt64, 1}(dims=(0,), mem=Memory{UInt64}(4, 0x7fdfdc51c6a0)[0x0000000000800000, 0x0800000000000000, 0x0000000004000000, 0x00007fdf97e44250]), offset=-1152921504606846976)
==========
Base.BitSet(bits=Array{UInt64, 1}(dims=(0,), mem=Memory{UInt64}(4, 0x7fdfdc039c60)[0x0000080000000000, 0x1000000000000000, 0x00007fdfdc704090, 0x00007fdfdc704070]), offset=-1152921504606846976)
==========
Base.BitSet(bits=Array{UInt64, 1}(dims=(0,), mem=Memory{UInt64}(4, 0x7fdfa82652a0)[0x0080000000000000, 0x00007fdf913e1370, 0x0000000000000000, 0x0000000000000000]), offset=-1152921504606846976)
==========
Base.BitSet(bits=Array{UInt64, 1}(dims=(1,), mem=Memory{UInt64}(4, 0x7fdfa82c1420)[0x0000008000000000, 0x00007fdf94c3ec90, 0x0000000000000000, 0x0000000000000000]), offset=34)
==========
Base.BitSet(bits=Array{UInt64, 1}(dims=(1,), mem=Memory{UInt64}(4, 0x7fdfa82b6b60)[0x0000000000000008, 0x3fec28f5c28f5c29, 0x00007fdf97dee8d0, 0x40c3880000000000]), offset=33)
==========

!!! ERROR in jl_ -- ABORTING !!!
==========
~~~~~~~~~~ ptr queue bottom ~~~~~~~~~~

[78883] signal 6 (-6): Aborted
in expression starting at /home/vchuravy/src/snippets/julia-base/58907/mwe.jl:33
unknown function (ip: 0x7fdfe89a974c)
gsignal at /usr/lib/libc.so.6 (unknown line)
abort at /usr/lib/libc.so.6 (unknown line)
gc_dump_queue_and_abort at /home/vchuravy/src/julia-1.11/src/gc.c:2073
gc_mark_outrefs at /home/vchuravy/src/julia-1.11/src/gc.c:2777 [inlined]
gc_mark_loop_serial_ at /home/vchuravy/src/julia-1.11/src/gc.c:2938
gc_mark_loop_serial at /home/vchuravy/src/julia-1.11/src/gc.c:2961
gc_mark_loop at /home/vchuravy/src/julia-1.11/src/gc.c:3143
_jl_gc_collect at /home/vchuravy/src/julia-1.11/src/gc.c:3532
ijl_gc_collect at /home/vchuravy/src/julia-1.11/src/gc.c:3893
maybe_collect at /home/vchuravy/src/julia-1.11/src/gc.c:926
jl_gc_pool_alloc_inner at /home/vchuravy/src/julia-1.11/src/gc.c:1319
jl_gc_pool_alloc_noinline at /home/vchuravy/src/julia-1.11/src/gc.c:1386
jl_gc_alloc_ at /home/vchuravy/src/julia-1.11/src/julia_internal.h:523
jl_gc_alloc at /home/vchuravy/src/julia-1.11/src/gc.c:3946
_new_genericmemory_ at /home/vchuravy/src/julia-1.11/src/genericmemory.c:56
jl_alloc_genericmemory at /home/vchuravy/src/julia-1.11/src/genericmemory.c:99
GenericMemory at ./boot.jl:516 [inlined]
Array at ./boot.jl:578 [inlined]
BitSet at ./bitset.jl:19 [inlined]
myempty at /home/vchuravy/.julia/packages/SparseConnectivityTracer/XQsYR/src/patterns.jl:73 [inlined]
myempty at /home/vchuravy/.julia/packages/SparseConnectivityTracer/XQsYR/src/patterns.jl:180 [inlined]
myempty at /home/vchuravy/.julia/packages/SparseConnectivityTracer/XQsYR/src/tracers.jl:123 [inlined]
gradient_tracer_1_to_1 at /home/vchuravy/.julia/packages/SparseConnectivityTracer/XQsYR/src/overloads/gradient_tracer.jl:7 [inlined]
gradient_tracer_2_to_1 at /home/vchuravy/.julia/packages/SparseConnectivityTracer/XQsYR/src/overloads/gradient_tracer.jl:68
* at /home/vchuravy/.julia/packages/SparseConnectivityTracer/XQsYR/src/overloads/gradient_tracer.jl:135 [inlined]
component_mass_fluxes! at /home/vchuravy/.julia/packages/JutulDarcy/y1cFJ/src/blackoil/flux.jl:60 [inlined]
face_flux! at /home/vchuravy/.julia/packages/JutulDarcy/y1cFJ/src/flux.jl:6 [inlined]
face_flux at /home/vchuravy/.julia/packages/Jutul/00WMN/src/conservation/conservation.jl:569 [inlined]
flux at /home/vchuravy/.julia/packages/Jutul/00WMN/src/conservation/flux.jl:206
update_equation_in_entity! at /home/vchuravy/.julia/packages/Jutul/00WMN/src/conservation/flux.jl:211
update_equation_for_entity! at /home/vchuravy/.julia/packages/Jutul/00WMN/src/equations.jl:554 [inlined]
update_equation! at /home/vchuravy/.julia/packages/Jutul/00WMN/src/equations.jl:529
unknown function (ip: 0x7fdfc5d400a3)
_jl_invoke at /home/vchuravy/src/julia-1.11/src/gf.c:2929
ijl_apply_generic at /home/vchuravy/src/julia-1.11/src/gf.c:3125
update_equations! at /home/vchuravy/.julia/packages/Jutul/00WMN/src/models.jl:726
update_equations! at /home/vchuravy/.julia/packages/Jutul/00WMN/src/models.jl:721
unknown function (ip: 0x7fdfc5d3bee1)
_jl_invoke at /home/vchuravy/src/julia-1.11/src/gf.c:2929
ijl_apply_generic at /home/vchuravy/src/julia-1.11/src/gf.c:3125
#update_equations!#657 at /home/vchuravy/.julia/packages/Jutul/00WMN/src/multimodel/model.jl:584
unknown function (ip: 0x7fdfc5d3ad95)
_jl_invoke at /home/vchuravy/src/julia-1.11/src/gf.c:2929
ijl_apply_generic at /home/vchuravy/src/julia-1.11/src/gf.c:3125
update_equations! at /home/vchuravy/.julia/packages/Jutul/00WMN/src/multimodel/model.jl:582
#update_equations_and_apply_forces!#658 at /home/vchuravy/.julia/packages/Jutul/00WMN/src/multimodel/model.jl:590
update_equations_and_apply_forces! at /home/vchuravy/.julia/packages/Jutul/00WMN/src/multimodel/model.jl:588 [inlined]
macro expansion at ./timing.jl:421 [inlined]
#update_state_dependents!#87 at /home/vchuravy/.julia/packages/Jutul/00WMN/src/models.jl:693
update_state_dependents! at /home/vchuravy/.julia/packages/Jutul/00WMN/src/models.jl:688 [inlined]
#model_residual#515 at /home/vchuravy/.julia/packages/Jutul/00WMN/src/simulator/helper.jl:198
model_residual at /home/vchuravy/.julia/packages/Jutul/00WMN/src/simulator/helper.jl:155
unknown function (ip: 0x7fdfc5d0bd52)
_jl_invoke at /home/vchuravy/src/julia-1.11/src/gf.c:2929
ijl_apply_generic at /home/vchuravy/src/julia-1.11/src/gf.c:3125
evaluate_residual_and_jacobian_for_state_pair at /home/vchuravy/.julia/packages/Jutul/00WMN/src/ad/AdjointsDI/adjoints.jl:331
unknown function (ip: 0x7fdfc5ca771d)
_jl_invoke at /home/vchuravy/src/julia-1.11/src/gf.c:2929
ijl_apply_generic at /home/vchuravy/src/julia-1.11/src/gf.c:3125
evaluate at /home/vchuravy/.julia/packages/Jutul/00WMN/src/ad/AdjointsDI/adjoints.jl:268
AdjointObjectiveHelper at /home/vchuravy/.julia/packages/Jutul/00WMN/src/ad/AdjointsDI/adjoints.jl:274
trace_function at /home/vchuravy/.julia/packages/SparseConnectivityTracer/XQsYR/src/trace_functions.jl:48 [inlined]
_local_jacobian_sparsity at /home/vchuravy/.julia/packages/SparseConnectivityTracer/XQsYR/src/trace_functions.jl:96
jacobian_sparsity at /home/vchuravy/.julia/packages/SparseConnectivityTracer/XQsYR/src/adtypes_interface.jl:149 [inlined]
jacobian_sparsity_with_contexts at /home/vchuravy/.julia/packages/DifferentiationInterface/alBlj/ext/DifferentiationInterfaceSparseConnectivityTracerExt/DifferentiationInterfaceSparseConnectivityTracerExt.jl:39 [inlined]
_prepare_sparse_jacobian_aux at /home/vchuravy/.julia/packages/DifferentiationInterface/alBlj/ext/DifferentiationInterfaceSparseMatrixColoringsExt/jacobian.jl:70
unknown function (ip: 0x7fdfc5ca6dce)
_jl_invoke at /home/vchuravy/src/julia-1.11/src/gf.c:2929
ijl_apply_generic at /home/vchuravy/src/julia-1.11/src/gf.c:3125
prepare_jacobian_nokwarg at /home/vchuravy/.julia/packages/DifferentiationInterface/alBlj/ext/DifferentiationInterfaceSparseMatrixColoringsExt/jacobian.jl:49
#prepare_jacobian#47 at /home/vchuravy/.julia/packages/DifferentiationInterface/alBlj/src/first_order/jacobian.jl:12 [inlined]
prepare_jacobian at /home/vchuravy/.julia/packages/DifferentiationInterface/alBlj/src/first_order/jacobian.jl:9
jl_fptr_args at /home/vchuravy/src/julia-1.11/src/gf.c:2590
_jl_invoke at /home/vchuravy/src/julia-1.11/src/gf.c:2929
ijl_apply_generic at /home/vchuravy/src/julia-1.11/src/gf.c:3125
F at /home/vchuravy/src/snippets/julia-base/58907/mwe.jl:32
RedirectStdStream at ./stream.jl:1464
top-level scope at /home/vchuravy/src/snippets/julia-base/58907/mwe.jl:34
jl_fptr_args at /home/vchuravy/src/julia-1.11/src/gf.c:2590
_jl_invoke at /home/vchuravy/src/julia-1.11/src/gf.c:2948
ijl_invoke at /home/vchuravy/src/julia-1.11/src/gf.c:2955
jl_toplevel_eval_flex at /home/vchuravy/src/julia-1.11/src/toplevel.c:934
jl_toplevel_eval_flex at /home/vchuravy/src/julia-1.11/src/toplevel.c:886
ijl_toplevel_eval at /home/vchuravy/src/julia-1.11/src/toplevel.c:952
ijl_toplevel_eval_in at /home/vchuravy/src/julia-1.11/src/toplevel.c:994
eval at ./boot.jl:430 [inlined]
include_string at ./loading.jl:2734
jl_fptr_args at /home/vchuravy/src/julia-1.11/src/gf.c:2590
_jl_invoke at /home/vchuravy/src/julia-1.11/src/gf.c:2929
ijl_apply_generic at /home/vchuravy/src/julia-1.11/src/gf.c:3125
_include at ./loading.jl:2794
include at ./Base.jl:562
jfptr_include_47309 at /home/vchuravy/src/julia-1.11/usr/lib/julia/sys-debug.so (unknown line)
_jl_invoke at /home/vchuravy/src/julia-1.11/src/gf.c:2929
ijl_apply_generic at /home/vchuravy/src/julia-1.11/src/gf.c:3125
exec_options at ./client.jl:323
_start at ./client.jl:531
jfptr__start_73994 at /home/vchuravy/src/julia-1.11/usr/lib/julia/sys-debug.so (unknown line)
_jl_invoke at /home/vchuravy/src/julia-1.11/src/gf.c:2929
ijl_apply_generic at /home/vchuravy/src/julia-1.11/src/gf.c:3125
jl_apply at /home/vchuravy/src/julia-1.11/src/julia.h:2157
true_main at /home/vchuravy/src/julia-1.11/src/jlapi.c:900
jl_repl_entrypoint at /home/vchuravy/src/julia-1.11/src/jlapi.c:1059
jl_load_repl at /home/vchuravy/src/julia-1.11/cli/loader_lib.c:595
main at /home/vchuravy/src/julia-1.11/cli/loader_exe.c:58
unknown function (ip: 0x7fdfe89396b4)
__libc_start_main at /usr/lib/libc.so.6 (unknown line)
_start at /home/vchuravy/src/julia-1.11/julia (unknown line)
Allocations: 475477084 (Pool: 475474415; Big: 2669); GC: 914
fish: Job 1, 'rr record ~/src/julia-1.11/juli…' terminated by signal SIGABRT (Abort)
```

### Inspecting

```sh
rr ps
PID	PPID	EXIT	CMD
78883	--	-6	/home/vchuravy/src/julia-1.11/julia --project=. mwe.jl
78884	78883	0	(forked without exec)
```

## Replaying

```sh
rr replay -p 78883 -e
```

```
__pthread_kill_implementation (threadid=<optimized out>, signo=signo@entry=6, no_tid=no_tid@entry=0) at pthread_kill.c:44
44	      return INTERNAL_SYSCALL_ERROR_P (ret) ? INTERNAL_SYSCALL_ERRNO (ret) : 0;
(rr) 
```

```
(rr) bt
#0  __pthread_kill_implementation (threadid=<optimized out>, signo=signo@entry=6, no_tid=no_tid@entry=0) at pthread_kill.c:44
#1  0x00007fdfe89a9813 in __pthread_kill_internal (threadid=<optimized out>, signo=6) at pthread_kill.c:89
#2  0x00007fdfe894fdc0 in __GI_raise (sig=6) at ../sysdeps/posix/raise.c:26
#3  0x00007fdfe7ee9a2b in sigdie_handler (sig=6, info=0x7ffdce647630, context=0x7ffdce647500) at /home/vchuravy/src/julia-1.11/src/signals-unix.c:249
#4  <signal handler called>
#5  __pthread_kill_implementation (threadid=<optimized out>, signo=signo@entry=6, no_tid=no_tid@entry=0) at pthread_kill.c:44
#6  0x00007fdfe89a9813 in __pthread_kill_internal (threadid=<optimized out>, signo=6) at pthread_kill.c:89
#7  0x00007fdfe894fdc0 in __GI_raise (sig=sig@entry=6) at ../sysdeps/posix/raise.c:26
#8  0x00007fdfe893757a in __GI_abort () at abort.c:73
#9  0x00007fdfe7ecfefe in gc_dump_queue_and_abort (ptls=0x555d13f1c340, vt=0x7fdfa490baa0) at /home/vchuravy/src/julia-1.11/src/gc.c:2073
#10 0x00007fdfe7ed2af9 in gc_mark_outrefs (ptls=0x555d13f1c340, mq=0x555d13f1d1c0, _new_obj=0x7fdfa0c8eea0, meta_updated=0) at /home/vchuravy/src/julia-1.11/src/gc.c:2777
#11 gc_mark_loop_serial_ (ptls=0x555d13f1c340, mq=0x555d13f1d1c0) at /home/vchuravy/src/julia-1.11/src/gc.c:2938
#12 0x00007fdfe7ed369a in gc_mark_loop_serial (ptls=0x555d13f1c340) at /home/vchuravy/src/julia-1.11/src/gc.c:2961
#13 0x00007fdfe7ed5575 in gc_mark_loop (ptls=0x555d13f1c340) at /home/vchuravy/src/julia-1.11/src/gc.c:3143
#14 0x00007fdfe7ed80bd in _jl_gc_collect (ptls=0x555d13f1c340, collection=JL_GC_AUTO) at /home/vchuravy/src/julia-1.11/src/gc.c:3532
#15 0x00007fdfe7ed9231 in ijl_gc_collect (collection=JL_GC_AUTO) at /home/vchuravy/src/julia-1.11/src/gc.c:3893
#16 0x00007fdfe7ecc8d0 in maybe_collect (ptls=0x555d13f1c340) at /home/vchuravy/src/julia-1.11/src/gc.c:926
#17 0x00007fdfe7ecdd0c in jl_gc_pool_alloc_inner (ptls=0x555d13f1c340, pool_offset=944, osize=64) at /home/vchuravy/src/julia-1.11/src/gc.c:1319
#18 0x00007fdfe7ece13e in jl_gc_pool_alloc_noinline (ptls=0x555d13f1c340, pool_offset=944, osize=64) at /home/vchuravy/src/julia-1.11/src/gc.c:1386
#19 0x00007fdfe7ec9c42 in jl_gc_alloc_ (ptls=0x555d13f1c340, sz=48, ty=0x7fdfd625d930 <jl_system_image_data+55750192>) at /home/vchuravy/src/julia-1.11/src/julia_internal.h:523
#20 0x00007fdfe7ed9441 in jl_gc_alloc (ptls=0x555d13f1c340, sz=48, ty=0x7fdfd625d930 <jl_system_image_data+55750192>) at /home/vchuravy/src/julia-1.11/src/gc.c:3946
#21 0x00007fdfe7e87090 in _new_genericmemory_ (mtype=0x7fdfd625d930 <jl_system_image_data+55750192>, nel=4, isunion=0 '\000', zeroinit=0 '\000', elsz=8) at /home/vchuravy/src/julia-1.11/src/genericmemory.c:56
#22 0x00007fdfe7e87344 in jl_alloc_genericmemory (mtype=0x7fdfd625d930 <jl_system_image_data+55750192>, nel=4) at /home/vchuravy/src/julia-1.11/src/genericmemory.c:99
#23 0x00007fdfc5caf23f in GenericMemory () at boot.jl:516
#24 Array () at boot.jl:578
#25 BitSet () at bitset.jl:19
#26 myempty () at /home/vchuravy/.julia/packages/SparseConnectivityTracer/XQsYR/src/patterns.jl:73
```

```
(rr) f 9
#9  0x00007fdfe7ecfefe in gc_dump_queue_and_abort (ptls=0x555d13f1c340, vt=0x7fdfa490baa0) at /home/vchuravy/src/julia-1.11/src/gc.c:2073
2073	    abort();
(rr) list
2068	            jl_(new_obj);
2069	            jl_safe_printf("==========\n");
2070	        }
2071	        jl_safe_printf("~~~~~~~~~~ ptr queue bottom ~~~~~~~~~~\n");
2072	    }
2073	    abort();
2074	}
```

https://github.com/JuliaLang/julia/blob/5be469270edb6dcfd980f68b926f3a995c60f49c/src/gc.c#L2055-L2074

```
(rr) f 10
#10 0x00007fdfe7ed2af9 in gc_mark_outrefs (ptls=0x555d13f1c340, mq=0x555d13f1d1c0,
    _new_obj=0x7fdfa0c8eea0, meta_updated=0)
    at /home/vchuravy/src/julia-1.11/src/gc.c:2777
2777	                gc_dump_queue_and_abort(ptls, vt);
(rr) list
2772	            return;
2773	        }
2774	        else {
2775	            jl_datatype_t *vt = (jl_datatype_t *)vtag;
2776	            if (__unlikely(!jl_is_datatype(vt) || vt->smalltag))
2777	                gc_dump_queue_and_abort(ptls, vt);
2778	        }
2779	        jl_datatype_t *vt = (jl_datatype_t *)vtag;
2780	        if (vt->name == jl_genericmemory_typename) {
2781	            jl_genericmemory_t *m = (jl_genericmemory_t*)new_obj;
```


```
(rr) p vt
$1 = (jl_datatype_t *) 0x7fdfa490baa0
```

Looks reasonable enough as a value, but the GC determines that it is corrupted and not a correct Julia object.

Now we can use `rr` magic and use `break gc.c:2777` `reverse-continue` to execute to this spot.

```
(rr) break gc.c:2777
Breakpoint 1 at 0x7fdfe7ed2ae0: gc.c:2777. (3 locations)
(rr) rc
Continuing.

Thread 1 hit Breakpoint 1.1, gc_mark_outrefs (ptls=0x555d13f1c340, mq=0x555d13f1d1c0, _new_obj=0x7fdfa0c8eea0, meta_updated=0) at /home/vchuravy/src/julia-1.11/src/gc.c:2777
2777	                gc_dump_queue_and_abort(ptls, vt);
```

https://github.com/JuliaLang/julia/blob/5be469270edb6dcfd980f68b926f3a995c60f49c/src/gc.c#L2775-L2778

We are in the main functio of the GC where we look at an object `new_obj` and want to mark all of it's field and enqueue them.

For that we have to obtain the type-tag of the object:

```
    jl_value_t *new_obj = (jl_value_t *)_new_obj;
    mark_obj: {
        jl_taggedvalue_t *o = jl_astaggedvalue(new_obj);
        uintptr_t vtag = o->header & ~(uintptr_t)0xf;
```

https://github.com/JuliaLang/julia/blob/5be469270edb6dcfd980f68b926f3a995c60f49c/src/gc.c#L2640-L2643

Two options:

1. The tag itself got corrupted
2. The parent got a corrupted reference

```
(rr) p o
$4 = (jl_taggedvalue_t *) 0x7fdfa490ba88
```

```
(rr) watch *(uintptr_t*)0x7fdfa490ba88
Hardware watchpoint 2: *(uintptr_t*)0x7fdfa490ba88
```

We are now watching the memory address of the tag for any updates. This should at least tell us where this object got last updated/allocated.

```
(rr) up
#1  gc_mark_loop_serial_ (ptls=0x555d13f1c340, mq=0x555d13f1d1c0) at /home/vchuravy/src/julia-1.11/src/gc.c:2938
2938	        gc_mark_outrefs(ptls, mq, new_obj, 0);
(rr) list
2933	        void *new_obj = (void *)gc_ptr_queue_pop(&ptls->mark_queue);
2934	        // No more objects to mark
2935	        if (__unlikely(new_obj == NULL)) {
2936	            return;
2937	        }
2938	        gc_mark_outrefs(ptls, mq, new_obj, 0);
2939	    }
2940	}
```

Here we see one of the complexities of working in the GC. We are getting the item from the mark queue. So we don't know who the parent of this object is.

```
(rr) rc
Continuing.

Thread 1 hit Hardware watchpoint 2: *(uintptr_t*)0x7fdfa490ba88

Old value = 140598515382953
New value = 140598515382952
0x00007fdfe7ed0341 in gc_try_setmark_tag (o=0x7fdfa490ba88, mark_mode=1 '\001')
    at /home/vchuravy/src/julia-1.11/src/gc.c:826
826	    tag = jl_atomic_exchange_relaxed((_Atomic(uintptr_t)*)&o->header, tag);
(rr) bt 3
#0  0x00007fdfe7ed0341 in gc_try_setmark_tag (o=0x7fdfa490ba88, mark_mode=1 '\001') at /home/vchuravy/src/julia-1.11/src/gc.c:826
#1  gc_mark_obj8 (ptls=0x555d13f1c340, obj8_parent=0x7fdfa0c8eea0 "", obj8_begin=0x7fdfa082a390 "\a", obj8_end=0x7fdfa082a391 "", nptr=13) at /home/vchuravy/src/julia-1.11/src/gc.c:2121
#2  0x00007fdfe7ed32d1 in gc_mark_outrefs (ptls=0x555d13f1c340, mq=0x555d13f1d1c0, _new_obj=0x7fdfa0c8eea0, meta_updated=0) at /home/vchuravy/src/julia-1.11/src/gc.c:2882
```

So now we are on the other side of the queue. The call to `gc_mark_obj8` is marking a parent objects and enqueue all it's children. 


```
(rr) f 1
#1  gc_mark_obj8 (ptls=0x555d13f1c340, obj8_parent=0x7fdfa0c8eea0 "", obj8_begin=0x7fdfa082a390 "\a", obj8_end=0x7fdfa082a391 "", nptr=13) at /home/vchuravy/src/julia-1.11/src/gc.c:2121
```

```
(rr) p jl_((jl_value_t*)obj8_parent)
StaticArraysCore.MArray{Tuple{3}, SparseConnectivityTracer.Dual{Float64, SparseConnectivityTracer.GradientTracer{SparseConnectivityTracer.IndexSetGradientPattern{Int64, Base.BitSet}}}, 1, 3}(data=(SparseConnectivityTracer.Dual{Float64, SparseConnectivityTracer.GradientTracer{SparseConnectivityTracer.IndexSetGradientPattern{Int64, Base.BitSet}}}(primal=-0.0000000000000000, tracer=SparseConnectivityTracer.GradientTracer{SparseConnectivityTracer.IndexSetGradientPattern{Int64, Base.BitSet}}(pattern=SparseConnectivityTracer.IndexSetGradientPattern{Int64, Base.BitSet}(gradient=Base.BitSet(bits=Array{UInt64, 1}(dims=(0,), mem=Memory{UInt64}(4, 0x7fdfdc51c6a0)[0x0000000000800000, 0x0800000000000000, 0x0000000004000000, 0x00007fdf97e44250]), offset=-1152921504606846976)), isempty=true)), SparseConnectivityTracer.Dual{Float64, SparseConnectivityTracer.GradientTracer{SparseConnectivityTracer.IndexSetGradientPattern{Int64, Base.BitSet}}}(primal=-0.18969603708245975, tracer=SparseConnectivityTracer.GradientTracer{SparseConnectivityTracer.IndexSetGradientPattern{Int64, Base.BitSet}}(pattern=SparseConnectivityTracer.IndexSetGradientPattern{Int64, Base.BitSet}(gradient=The program being debugged received signal SIGSEGV, Segmentation fault
while in a function called from GDB.  GDB has restored the context
to what it was before the call.  To change this behavior use
"set unwind-on-signal off".  Evaluation of the expression containing
the function (jl_) will be abandoned.
```

So the parent in question is an `MArray` and somehow the gradient object got corrupted. There are other "weird" things, like `offset=-1152921504606846976`

```
(rr) p slot
$5 = (jl_value_t **) 0x7fdfa0c8eed8
```

```
(rr) p new_obj
$6 = (jl_value_t *) 0x7fdfa490ba90
```

`new_obj` is the object we are watching (whose tag is at `0x7fdfa490ba88`)

```
(rr) p/x 0x7fdfa490ba90 - 8
$8 = 0x7fdfa490ba88
```

So let's watch the slot as well to see when that got set.

```
(rr) watch *(jl_value_t **) 0x7fdfa0c8eed8
Hardware watchpoint 5: *(jl_value_t **) 0x7fdfa0c8eed8
(rr) rc
Continuing.

Thread 1 hit Hardware watchpoint 4: *(uintptr_t*)0x7fdfa490ba88

Old value = 140598515382952
New value = 140599331917648
0x00007fdfe7ece6d5 in gc_sweep_page (s=0x7ffdce64b110, p=0x555d13f1c690, allocd=0x555d1c492a60, buffered=0x555d13f1d1a8, pg=0x555d16141e60, osize=32) at /home/vchuravy/src/julia-1.11/src/gc.c:1508
1508	                *pfl = v;
(rr)
```

Okay so the GC itself is corrupting our tag during sweeping. I wonder what was there previously?

```
(rr) p jl_(140599331917648)
Base.BitSet
$9 = void
```

Okay it's a `BitSet`. Now we have a conundrum. The GC is sweeping this object, that means that during marking we didn't find it. And then later
it materializes "out-of-thin" air. This feels like someone did *unsafe* shenanigans.

Let's see when the field for the MArray got set.

```
(rr) rc
Continuing.

Thread 1 hit Hardware watchpoint 5: *(jl_value_t **) 0x7fdfa0c8eed8

Old value = (jl_value_t *) 0x7fdfa490ba90
New value = (jl_value_t *) 0x7fdf987aaad0
0x00007fdfc5d3d867 in MArray () at /home/vchuravy/.julia/packages/StaticArraysCore/7xxEJ/src/StaticArraysCore.jl:187
187	        new{S,T,N,L}(x)
```

```
#0  0x00007fdfc5d3d867 in MArray () at /home/vchuravy/.julia/packages/StaticArraysCore/7xxEJ/src/StaticArraysCore.jl:187
#1  macro expansion () at /home/vchuravy/.julia/packages/StaticArrays/LSPcF/src/deque.jl:193
#2  _setindex () at /home/vchuravy/.julia/packages/StaticArrays/LSPcF/src/deque.jl:186
#3  setindex () at /home/vchuravy/.julia/packages/StaticArrays/LSPcF/src/deque.jl:185
#4  component_mass_fluxes! () at /home/vchuravy/.julia/packages/JutulDarcy/y1cFJ/src/blackoil/flux.jl:82
#5  face_flux! () at /home/vchuravy/.julia/packages/JutulDarcy/y1cFJ/src/flux.jl:6
#6  face_flux () at /home/vchuravy/.julia/packages/Jutul/00WMN/src/conservation/conservation.jl:569
#7  julia_flux_32276 (ld=...) at /home/vchuravy/.julia/packages/Jutul/00WMN/src/conservation/flux.jl:206
#8  0x00007fdfc5d3e52b in julia_update_equation_in_entity!_32254 (eq_buf=..., self_cell=292, state=..., state0=..., eq=..., model=...,
    Δt=<error reading variable: Value cannot be represented as integer of 8 bytes.>, ldisc=...) at /home/vchuravy/.julia/packages/Jutul/00WMN/src/conservation/flux.jl:208
#9  0x00007fdfc5d3fe0f in update_equation_for_entity! () at /home/vchuravy/.julia/packages/Jutul/00WMN/src/equations.jl:554
#10 julia_update_equation!_32217 (eq_s=..., eq=..., storage=..., model=..., dt=<optimized out>) at /home/vchuravy/.julia/packages/Jutul/00WMN/src/equations.jl:529
#11 0x00007fdfc5d400a4 in jfptr_update_equation!_32218 ()
#12 0x00007fdfe7e53b62 in _jl_invoke (F=0x7fdfb60d5ed0 <jl_system_image_data+2952848>, args=0x7ffdce64a778, nargs=5, mfunc=0x7fdfa81b5810, world=26886) at /home/vchuravy/src/julia-1.11/src/gf.c:2929
#13 0x00007fdfe7e546c2 in ijl_apply_generic (F=0x7fdfb60d5ed0 <jl_system_image_data+2952848>, args=0x7ffdce64a778, nargs=5) at /home/vchuravy/src/julia-1.11/src/gf.c:3125
```

Hm not that helpful. We can check that both objects are valid at that time.

```
(rr) p jl_(0x7fdf987aaad0)
Base.BitSet(bits=Array{UInt64, 1}(dims=(30,), mem=Memory{UInt64}(86, 0x7fdfa0cee2a0)[0x0000000000008000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000020000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000200000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0080000000000000, 0x0000000000000003, 0x0000002000000000, 0x0000000000000001, 0x00000000000000d5, 0x00000000000000d6, 0x0000000000800000, 0x0004000000790000, 0x4000000790000004, 0x0000000000000000, 0x0000000000010000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x3c80000020000000, 0x0000000002000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000001000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0004000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000040000000, 0x0000000000000000, 0x0000000000000000, 0x0000004000000000, 0x0000000000000000, 0x0000000000100e01, 0x0000002000000000, 0x0000000200000000, 0x0000000000008000, 0x000000000000006a, 0x0000000000000068, 0x0000000000000069, 0x0000000000000067, 0x0000000000000068, 0x0000000000000066, 0x0000000000000067, 0x0000000000000065, 0x0000000000000066, 0x0000000000000064, 0x0000000000000065, 0x0000000000000063, 0x0000000000000064, 0x0000000000000062, 0x0000000000000063, 0x0000000000000061, 0x0000000000000062, 0x0000000000000060, 0x0000000000000061, 0x000000000000005f, 0x0000000000000060, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x00007fdfdf209e00]), offset=8)
$10 = void
(rr) p jl_(0x7fdfa490ba90)
Base.BitSet(bits=Array{UInt64, 1}(dims=(25,), mem=Memory{UInt64}(50, 0x7fdf92d09a60)[0x00007fdf90c39310, 0x00007fdf90c39330, 0x00007fdf90c39350, 0x00007fdf90c4d2f0, 0x00007fdfd57a7e70, 0x00007fdf90c43cf0, 0x00007fdf90c39130, 0x00007fdf90c39950, 0x00007fdf90c393f0, 0x0000010000000000, 0x0000000800000000, 0x00000003c8000002, 0x0000048000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000006000000, 0x0000000000008000, 0x0000008000000000, 0x0000000000000001, 0x00007fdf90c39bf0, 0x00007fdf90c39c10, 0x00007fdf90c39c30, 0x00007fdf90c39c50, 0x0000000000000009, 0x0000000000000003, 0x0000000000000002, 0x0000000000000002, 0x0000000000000001, 0x0000000000000000]), offset=13)
```



```
(rr) rc
Continuing.

Thread 1 hit Hardware watchpoint 4: *(uintptr_t*)0x7fdfa490ba88

Old value = 140599331917648
New value = 140598515382952
0x00007fdfc5caec52 in BitSet () at bitset.jl:21
warning: 21	bitset.jl: No such file or directory
(rr) bt
#0  0x00007fdfc5caec52 in BitSet () at bitset.jl:21
#1  copy () at bitset.jl:48
#2  julia_union_23886 (s=..., sets...=...) at bitset.jl:295
#3  0x00007fdfc5caf32f in gradient_tracer_2_to_1_inner () at /home/vchuravy/.julia/packages/SparseConnectivityTracer/XQsYR/src/overloads/gradient_tracer.jl:99
#4  gradient_tracer_2_to_1_inner () at /home/vchuravy/.julia/packages/SparseConnectivityTracer/XQsYR/src/overloads/gradient_tracer.jl:80
#5  julia_gradient_tracer_2_to_1_23881 (tx=..., ty=..., is_der1_arg1_zero=<optimized out>, is_der1_arg2_zero=<optimized out>)
    at /home/vchuravy/.julia/packages/SparseConnectivityTracer/XQsYR/src/overloads/gradient_tracer.jl:70
#6  0x00007fdfc5d3d4f3 in * () at /home/vchuravy/.julia/packages/SparseConnectivityTracer/XQsYR/src/overloads/gradient_tracer.jl:135
#7  * () at operators.jl:596
#8  component_mass_fluxes! () at /home/vchuravy/.julia/packages/JutulDarcy/y1cFJ/src/blackoil/flux.jl:60
#9  face_flux! () at /home/vchuravy/.julia/packages/JutulDarcy/y1cFJ/src/flux.jl:6
#10 face_flux () at /home/vchuravy/.julia/packages/Jutul/00WMN/src/conservation/conservation.jl:569
```

So that's where we allocate the BitSet for the first time.

{{ addcomments }}
