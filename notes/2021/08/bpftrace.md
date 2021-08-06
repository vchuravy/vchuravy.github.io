@def title = "BPFTrace & Julia -- Part 1"
@def hascode = true
@def date = Date(2021, 8, 04)
@def rss = "A short introduction to bpftrace and using it with Julia"
@def tags = ["observability", "internals", "julia", "note"]

# BPFTrace and Julia
\toc

BPFTrace is an observability tool inspired by DTrace for Linux. It uses the
eBPF infrastructure in the Linux kernel to implemented lightweight tracing of
the kernel and applications. This note is written from a Linux perspective, but much of this should hold on systems with DTrace.

The table below is taken from the `bpftrace` man page:

|         | kernel      | userland     |
|---------|-------------|--------------|
| static  | tracepoints | USDT* probes |
| dynamic | kprobes     | uprobes      |

*USDT = user-level statically defined tracing

I will focus on userland for now, since that is the most
useful feature for understanding applications, like Julia.

The big selling point of BPFTrace is that it is lightweight and introduces next to no overhead until tracing is enabled, as well as being able to turn on tracing on a program that is already running.

## Probing functions using `uprobes`

Locate the library directory where `libjulia-internal.so` is located.

```julia-repl
julia> realpath(joinpath(Sys.BINDIR, Base.LIBDIR, "julia"))
"/usr/lib/julia"
```

Using `nm` we can list all of the exported runtime functions of Julia.

```bash
nm -D /usr/lib/julia/libjulia-internal.so
```

All of these functions can be instrumented using a `uprobe`.

There are two kinds of UProbes.

1. `uprobe`: Execute on entry to a function.
2. `uretprobe`: Executed on exit from a function.

As an example we can look for GC related functions:

```bash
nm -D /usr/lib/julia/libjulia-internal.so | grep jl_gc_
0000000000015215 T jl_gc_add_finalizer
0000000000015221 T jl_gc_add_finalizer_th
000000000001522d T jl_gc_add_ptr_finalizer
0000000000015239 T jl_gc_alloc
0000000000015245 T jl_gc_alloc_0w
0000000000015251 T jl_gc_alloc_1w
000000000001525d T jl_gc_alloc_2w
0000000000015269 T jl_gc_alloc_3w
0000000000015275 T jl_gc_allocobj
0000000000015281 T jl_gc_alloc_typed
000000000001528d T jl_gc_big_alloc
...
```

an alternative way to find all valid `uprobe` tracepoints is to use `bpftrace`:

```
sudo bpftrace -l 'uprobe:/usr/lib/julia/libjulia-internal.so:jl_gc_*'
uprobe:/usr/lib/julia/libjulia-internal.so:jl_gc_add_finalizer
uprobe:/usr/lib/julia/libjulia-internal.so:jl_gc_add_finalizer_th
uprobe:/usr/lib/julia/libjulia-internal.so:jl_gc_add_ptr_finalizer
uprobe:/usr/lib/julia/libjulia-internal.so:jl_gc_alloc
uprobe:/usr/lib/julia/libjulia-internal.so:jl_gc_alloc_0w
uprobe:/usr/lib/julia/libjulia-internal.so:jl_gc_alloc_1w
uprobe:/usr/lib/julia/libjulia-internal.so:jl_gc_alloc_2w
uprobe:/usr/lib/julia/libjulia-internal.so:jl_gc_alloc_3w
uprobe:/usr/lib/julia/libjulia-internal.so:jl_gc_alloc_page
uprobe:/usr/lib/julia/libjulia-internal.so:jl_gc_alloc_typed
uprobe:/usr/lib/julia/libjulia-internal.so:jl_gc_allocobj
uprobe:/usr/lib/julia/libjulia-internal.so:jl_gc_big_alloc
...
```

this is very helpful to confirm that `bpftrace` can actually find the function you
want to instrument.


\note{}{
    To understand what each function does it is best to search for the name in the `src` directory of Julia.
}

For now I want to understand a Julia programs allocation behaviour better,
and I know that `jl_gc_alloc` is the primary allocation function.

Looking at the Julia source code:

```c
jl_value_t* jl_gc_alloc(jl_ptls_t ptls, size_t sz, void *ty)
```

I see that it takes the current `ptls`, a size `sz` and a `void* ty` which is the type of the Julia object to allocate. For now the only interesting argument is `sz`.

The function `allocator` is going to run forever and allocate an array of size `N` bytes.

```julia
function allocator(range)
    while true
        N = rand(range)
        buf = Array{UInt8}(undef, N)
    end
end
```

In one terminal I am goint to run my Julia process with:

```bash
julia -L allocator.jl -e "allocator(64:128)"
```
where `allocator.jl` contains the function from above.

Now `bpftrace` has it's own language inspired by `dtrace` and we want to install
a `uprobe` on the function `jl_gc_alloc`.

\note{Paths to shared library}{
    As far as I know `bpftrace` expects the path to the library (or the pid of
    the process to instrument). It accepts either a relative or absolute path.
}

For simple bpftrace programs you can write them directly as part of the command line:

```bash
➜  ~ sudo bpftrace -e "uprobe:/usr/lib/julia/libjulia-internal.so:jl_gc_alloc { @[pid] = hist(arg1); }"
Attaching 1 probe...
c^C

@[2955269]:
[16, 32)             995 |@@@@@@@@@@                                          |
[32, 64)             448 |@@@@                                                |
[64, 128)           1936 |@@@@@@@@@@@@@@@@@@@@                                |
[128, 256)          4891 |@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@|
[256, 512)            10 |                                                    |
[512, 1K)            226 |@@                                                  |
[1K, 2K)               2 |                                                    |
[2K, 4K)               2 |
```

Or you can write a scrip, take the snippet below and write it to a file called `trace_gc_alloc.bt`.

```
#!/usr/bin/env bpftrace

BEGIN
{
    printf("Tracing Julia GC Allocations... Hit Ctrl-C to end.\n");
}

uprobe:/usr/lib/julia/libjulia-internal.so:jl_gc_alloc
{
    @allocations[pid] = hist(arg1);
}
```

and then execute `bpftrace`:

```bash
➜  ~ sudo bpftrace trace_gc_alloc.bt
Attaching 2 probes...
Tracing Julia GC Allocations... Hit Ctrl-C to end.
^C

@allocations[2955269]:
[16, 32)             995 |@@@@@@@@@@@@@                                       |
[32, 64)             448 |@@@@@@                                              |
[64, 128)           1926 |@@@@@@@@@@@@@@@@@@@@@@@@@@                          |
[128, 256)          3711 |@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@|
[256, 512)             8 |                                                    |
[512, 1K)            226 |@@@                                                 |
[1K, 2K)               2 |                                                    |
[2K, 4K)               2 |                                                    |
```

### A note on `ustack`

`bpftrace` exposes the option to collect the stack of the user application when
a probe fires.


```
sudo bpftrace -e "uprobe:/usr/lib/julia/libjulia-internal.so:jl_gc_alloc { @[ustack] = count(); }"
[sudo] password for vchuravy:
Attaching 1 probe...
^C

@[
    jl_gc_alloc+0
    japi1_Dict_16786.clone_1+159
    0x7f993e3a9e32
    0x7f993e3aa04a
    0x7f993e40832d
    0x7f993e38600e
    0x7f993e3877b9
    0x7f993e38a02c
    0x7f993e38a326
    do_call+166
    eval_value+1135
    eval_body+930
    jl_interpret_toplevel_thunk+232
    jl_toplevel_eval_flex+738
    jl_toplevel_eval_flex+1325
    jl_toplevel_eval_in+170
    japi1_eval_user_input_18975.clone_1.clone_2+1074
    japi1_repl_backend_loop_17983.clone_1.clone_2+936
    japi1_start_repl_backend_19196.clone_1+127
    japi1_run_repl_18018.clone_1+25
    julia_YY.874_41531.clone_1+1574
    jfptr_YY.874_41532.clone_1+9
    jl_f__call_latest+71
    julia_run_main_repl_32598.clone_1.clone_2+2249
    julia_exec_options_29068.clone_1.clone_2+23966
    julia__start_34288.clone_1+655
]: 1
@[
    jl_gc_alloc+0
    0x7f993e40850f
    0x7f993e38600e
    0x7f993e3877b9
    0x7f993e38a02c
    0x7f993e38a326
    do_call+166
    eval_value+1135
    eval_body+930
    jl_interpret_toplevel_thunk+232
    jl_toplevel_eval_flex+738
    jl_toplevel_eval_flex+1325
    jl_toplevel_eval_in+170
    japi1_eval_user_input_18975.clone_1.clone_2+1074
    japi1_repl_backend_loop_17983.clone_1.clone_2+936
    japi1_start_repl_backend_19196.clone_1+127
    japi1_run_repl_18018.clone_1+25
    julia_YY.874_41531.clone_1+1574
    jfptr_YY.874_41532.clone_1+9
    jl_f__call_latest+71
    julia_run_main_repl_32598.clone_1.clone_2+2249
    julia_exec_options_29068.clone_1.clone_2+23966
    julia__start_34288.clone_1+655
]: 1
@[
    jl_gc_alloc+0
    julia_YY.readdirYY.22_35563.clone_1.clone_2+316
    julia_tryf_35829.clone_1.clone_2+367
    julia__walkdir_35550.clone_1.clone_2+185
    jfptr__walkdir_35551.clone_1+17
    julia_YY.25_35391.clone_1+124
    start_task+235
]: 1
@[
    jl_gc_alloc+0
    jl_array_grow_end+299
    julia_sortNOT._46922.clone_1.clone_2+164
    julia_YY.readdirYY.22_35563.clone_1.clone_2+339
    julia_tryf_35829.clone_1.clone_2+367
    julia__walkdir_35550.clone_1.clone_2+185
    jfptr__walkdir_35551.clone_1+17
    julia__walkdir_35550.clone_1.clone_2+985
    jfptr__walkdir_35551.clone_1+17
    julia__walkdir_35550.clone_1.clone_2+985
    jfptr__walkdir_35551.clone_1+17
    julia__walkdir_35550.clone_1.clone_2+985
    jfptr__walkdir_35551.clone_1+17
    julia__walkdir_35550.clone_1.clone_2+985
    jfptr__walkdir_35551.clone_1+17
    julia_YY.25_35391.clone_1+124
    start_task+235
]: 1
@[
    jl_gc_alloc+0
    0x7f993e3ab245
    0x7f993e3ab649
    jl_apply_generic+506
    0x7f993e4083cc
    0x7f993e38600e
    0x7f993e3877b9
    0x7f993e38a02c
    0x7f993e38a326
    do_call+166
    eval_value+1135
    eval_body+930
    jl_interpret_toplevel_thunk+232
    jl_toplevel_eval_flex+738
    jl_toplevel_eval_flex+1325
    jl_toplevel_eval_in+170
    japi1_eval_user_input_18975.clone_1.clone_2+1074
    japi1_repl_backend_loop_17983.clone_1.clone_2+936
    japi1_start_repl_backend_19196.clone_1+127
    japi1_run_repl_18018.clone_1+25
    julia_YY.874_41531.clone_1+1574
    jfptr_YY.874_41532.clone_1+9
    jl_f__call_latest+71
    julia_run_main_repl_32598.clone_1.clone_2+2249
    julia_exec_options_29068.clone_1.clone_2+23966
    julia__start_34288.clone_1+655
]: 1
...
```

As you can see there a function pointers in the stack trace whose names are not
resolved, these a JIT-compiled user functions, and BPFTrace currently doesn't know
how to symbolize them. There is an [initial design proposal](https://dxuuu.xyz/stack-symbolize.html)
that might mitigate that in the future.

## Coming up next

I am planning to write at least two more notes on using BPFTrace and Julia, the
next will focus on how to use the USDT tracepoints added in Julia 1.8 and the one
after that on how to use UProbes.jl to instrument Julia applications themselves.
