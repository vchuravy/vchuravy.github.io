@def title = "Persistent Code Caching In GPUCompiler.jl"
@def hascode = true
@def hascomments = true
@def date = Date(2024, 6, 28)
@def rss = "Persistent Code Caching In GPUCompiler.jl"
@def tags = ["compiler", "gpu", "julia", "note"]

# Persistent Code Caching in GPUCompiler.jl
\toc

After multiple prior attempts [we just landed](https://github.com/JuliaGPU/GPUCompiler.jl/pull/557) the last
piece of the puzzle for persistent code caching for GPU codes in Julia.

There are two components to the persistent code caching infrastructure:

1. Inference caching for GPU kernels.
2. Disk caching for generated LLVM IR/object files. 

## TL;DR -- Just the numbers

We evaluated the effectiveness on two computational fluid dynamics codes.

### WaterLily TGV example

The full example is shown below as a blueprint to follow for your own examples.

| Backend | Precompilation| Disk Cache | What | Time | 
| ------ | ------- |  ----- | ----- |   --- |
| CPU |  ✗  |  |  First execution | 5.32s (80% compilation) |
| CPU |  ✗  |  |  Second execution | 0.85s |
| CPU |  ✓  |  |  First execution | 2.48s (65% compilation) |
| CPU |  ✓  |  |  Second execution | 0.9s |
| CUDA  |  ✗ | ✗  |  First execution | 11.07s (70% compilation) |
| CUDA  |  ✗ | ✗ |  Second execution | 0.02s |
| CUDA  |  ✓ | ✗  |  First execution | 6.38s (46% compilation) |
| CUDA |  ✓  | ✗ |  Second execution | 0.02s |
| CUDA  |  ✓ | ✓  |  First execution | 2.70s (97% compilation) |
| CUDA |  ✓  | ✓ |  Second execution | 0.02s |

Here caching is effective, but there is still more to be gained, and
more investigation is needed for why the first execution takes 2.7s,
most of it in Julia host compilation.

Disk caching is effective since it seems to remove almost all "GPUCompiler"
e.g. non-native compilation time.

#### Benchmark script

```julia
using WaterLilyTGV
import CUDA

@assert CUDA.functional()

# First execution
vortex = TGV(T=Float32, mem=CUDA.CuArray)
@time sim_step!(vortex, 1, max_steps=1)

# Second execution
vortex = TGV(T=Float32, mem=CUDA.CuArray)
@time sim_step!(vortex, 1, max_steps=1)
```

### `ClimaOcean.jl`: Near Global Ocean

Using the [example](https://github.com/CliMA/ClimaOcean.jl/blob/9b947bbece78d7226a1a6440606190fbc697391b/examples/near_global_omip_simulation.jl)  while mimizing the computational costs.

#### Julia 1.10.4
| Backend | Precompilation| Disk Cache | What | Time (s) | 
| ------ | ------- |  ----- | ----- |   --- |
| CUDA |  ✓    | NA | Initialization  | 69    |
| CUDA |  ✓    | NA | Time step 1    | 0.438 |
| CUDA |  ✓    | NA | Time step 2    | 1.245 |
| CUDA |  ✓    | NA | Time step 3    | 4.993 |
| CUDA |  ✓    | NA |  Time step 4   | 0.017 |

#### Julia 1.11.0-beta2

| Backend | Precompilation| Disk Cache | What | Time | 
| ------ | ------- |  ----- | ----- |   --- |
| CPU |  ✗  |  | Initialization | 422s |
| CPU |  ✗  |  |  Time step 1 | 75s  |
| CPU |  ✗  |  |  Time step 2 | 21s |
| CPU |  ✗  |  |  Time step 3 | 75s  |
| CPU |  ✗  |  |  Time step 4 | 0.008s |
| CPU |  ✓  |  |  Initialization | 52s  |
| CPU |  ✓  |  |  Time step 1 | 0.021s |
| CPU |  ✓  |  |  Time step 2 | 0.290s |
| CPU |  ✓  |  |  Time step 3 | 0.014s |
| CPU |  ✓  |  |  Time step 4 | 0.008s |
| CUDA  |  ✗ | ✗  | Initialization  | 596s |
| CUDA  |  ✗ | ✗ |   Time step 1 | 75s |
| CUDA  |  ✗ | ✗ |   Time step 2 | 34s |
| CUDA  |  ✗ | ✗ |   Time step 3 | 99s |
| CUDA  |  ✗ | ✗ |   Time step 4 | 0.017s |
| CUDA  |  ✓ | ✗  |  Initialization | 44s  |
| CUDA |  ✓  | ✗ |  Time step 1 | 0.339s |
| CUDA |  ✓  | ✗ |  Time step 2 | 1.171s |
| CUDA |  ✓  | ✗ |  Time step 3 | 3.659s |
| CUDA |  ✓  | ✗ |  Time step 4 | 0.018s |
| CUDA  |  ✓ | ✓  |  Initialization |12s |
| CUDA |  ✓  | ✓ |  Time step 1 | 0.023s |
| CUDA |  ✓  | ✓ |  Time step 2 | 0.207s |
| CUDA |  ✓  | ✓ |  Time step 3 | 0.029s |
| CUDA |  ✓  | ✓ |  Time step 4 | 0.017s |

## Using Waterlily TGV example

Using [`WaterLily.jl`](https://github.com/weymouth/WaterLily.jl) and in
particular their **3D Taylor Green Vortex** we can set up a small Julia application. The application uses [package extensions](https://pkgdocs.julialang.org/v1.9/creating-packages/#Conditional-loading-of-code-in-packages-(Extensions)) and [`PrecompileTools.jl`](https://github.com/JuliaLang/PrecompileTools.jl) for
automatic caching of needed functionality and handling of GPU dependencies.

#### `src/WaterLilyTGV.jl`end
```julia
module WaterLilyTGV

using PrecompileTools
@recompile_invalidations begin
    using WaterLily
end

export TGV, sim_step!

import WaterLily: sim_step!

function TGV(; pow=6, Re=1e5, T=Float64, mem=Array)
    # Define vortex size, velocity, viscosity
    L = 2^pow; U = 1; ν = U*L/Re
    # Taylor-Green-Vortex initial velocity field
    function uλ(i,xyz)
        x,y,z = @. (xyz-1.5)*π/L               # scaled coordinates
        i==1 && return -U*sin(x)*cos(y)*cos(z) # u_x
        i==2 && return  U*cos(x)*sin(y)*cos(z) # u_y
        return 0.                              # u_z
    end
    # Initialize simulation
    return Simulation((L, L, L), (0, 0, 0), L; U, uλ, ν, T, mem)
end

@setup_workload let
    @compile_workload begin
        let vortex = TGV(T=Float32)
            sim_step!(vortex, 1, pow=1, max_steps=1)
        end
        let vortex = TGV(T=Float64)
            sim_step!(vortex, 1, pow=1, max_steps=1)
        end
    end
end

end # module WaterLilyTGV
```

#### `ext/CUDAExt.jl`

```julia
module CUDAExt

using PrecompileTools
@recompile_invalidations begin
    using WaterLilyTGV
    import CUDA
end

# TODO: How does Preferences work for this?
@setup_workload let
    if CUDA.functional()
        @compile_workload begin
            let vortex = TGV(T=Float32, mem=CUDA.CuArray)
                sim_step!(vortex, 1, max_steps=1)
            end
            let vortex = TGV(T=Float64, mem=CUDA.CuArray)
                sim_step!(vortex, 1, max_steps=1)
            end
        end
    end
end

end
```

#### `Project.toml`
```julia
name = "WaterLilyTGV"
uuid = "ff377938-d05a-4d40-b5b0-1f78a12130ea"
authors = ["Valentin Churavy"]
version = "0.1.0"

[deps]
PrecompileTools = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
WaterLily = "ed894a53-35f9-47f1-b17f-85db9237eebd"

[weakdeps]
CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"

[extensions]
CUDAExt = "CUDA"

[compat]
CUDA = "5.4.2"
PrecompileTools = "1.2.1"
WaterLily = "1.1.0"
```


## Persistent Inference Caching

** To Be Written **

## Disk Caching

** To Be Written **

{{ addcomments }}
