@def title = "Cross-Compiling with JuliaC"
@def hascode = true
@def hascomments = true
@def date = Date(2026, 4, 5)
@def rss = "Cross-Compiling with JuliaC"
@def tags = ["compiler", "cross-compiling", "julia", "note"]

# Cross-Compiling with JuliaC
\toc

## Goal
To use [JuliaC.jl](https://github.com/JuliaLang/JuliaC.jl) to compile an application from x86_64 for aarch64. 

## Prerequisites 

I am using Archlinux for this and currently the method of cross compilation only works on Linux.


!!! note
    Julia currently does **not** have native cross-compilation capabilities (ignoring [GPUCompiler.jl](https://github.com/JuliaGPU/GPUCompiler.jl) for now.). So we must execute the compiler in an *emulated* target environment.

I had to install:

- `aarch64-linux-gnu-glibc`
- `aarch64-linux-gnu-gcc`
- `qemu-user`
- `qemu-user-binfmt`

!!! note
    It would be fantastic if we could use `jll`s to obtain an environment suitable for cross-compilation.

### Julia
We also need a Julia build for `aarch64`, you can get one from [https://julialang.org/downloads/manual-downloads/](https://julialang.org/downloads/manual-downloads/)

## The meat and potatoes

### Project
```toml
[deps]
JuliaC = "acedd4c2-ced6-4a15-accc-2607eb759ba2"

[compat]
JuliaC = "0.3"
```

### `cross_compiling.jl`
```julia
const julia_aarch64 = `julia-1.12.5/bin/julia`

qemu_aarch64() = `qemu-aarch64`

function run_aarch64(cmd)
    qemu = addenv(qemu_aarch64(), 
        "QEMU_LD_PREFIX" =>"/usr/aarch64-linux-gnu/",
        "JULIA_CC" => "aarch64-linux-gnu-gcc",
    )
    run(`$(qemu) $(cmd)`)
end

run_aarch64(`$(julia_aarch64) -e "using InteractiveUtils; versioninfo()"`)
run_aarch64(`$(julia_aarch64) --project=. -e "import Pkg; Pkg.instantiate(); Pkg.precompile()"`)


juliac(args) = run_aarch64(`$(julia_aarch64) --project=. -e "using JuliaC; JuliaC.main(ARGS)" -- $(args)`)
cc(app) = juliac(`--output-exe app --bundle build_aarch64 --trim=unsafe-warn --experimental $(app)`)

cc(ARGS[0])
```

## Running it:

```bash
julia +1.12 --project=. crosscompiling.jl TestApp
```

```bash
file build_aarch64/bin/app 
build_aarch64/bin/app: ELF 64-bit LSB pie executable, ARM aarch64, version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux-aarch64.so.1, BuildID[sha1]=9b424857d2614c45cf0dec8fd97d99443e4a54c9, for GNU/Linux 3.7.0, with debug_info, not stripped
```

```bash
QEMU_LD_PREFIX=/usr/aarch64-linux-gnu/ ./build_aarch64/bin/app
LEDCube AppTest starting...
Connecting to LEDCube server at 127.0.0.1:2017
```

{{ addcomments }}
