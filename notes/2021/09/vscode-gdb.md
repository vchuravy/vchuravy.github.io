@def title = "Using GDB & VSCode to debug Julia code on Windows"
@def hascode = true
@def hascomments = true
@def date = Date(2021, 9, 12)
@def rss = "Debugging Julia code on Windows using VSCode and GDB "
@def tags = ["debugging", "gdb", "julia", "vscode", "note"]

# Using GDB & VSCode to debug Julia code on Windows
\toc

One of the most annoying tasks for me is debugging code on Windows. I have been using Linux as my primary system for a long time now, and no of my customary tools (most notably [rr](https://rr-project.org/)) work or work reliably.

Nonetheless I regularly need to debug Windows specific issues that crop up when either working
on the Julia compiler or other tools like [Enzyme](https://enzyme.mit.edu). As it often does it this adventure started out with CI only failing on Windows, and to make matters worse it looked like an ABI mismatch...

In any case I wanted to setup a better environment for me to debug in, instead of grasping in the dark.

\note{}{
    While this content is written for Windows most of it outside the setup should work under Linux or MacOS as well.
}

## Setup

I noticed that my preferred editor of choice (VSCode) had [setup instructions](https://code.visualstudio.com/docs/cpp/config-mingw) for Mingw-w64 that promised GDB integration.

After [downloading MSYS2](https://www.msys2.org/) and
using the MSYS2 console to install the mingw-w64 toolchain:

```sh
pacman -Syu
pacman -Su
pacman -S --needed base-devel mingw-w64-x86_64-toolchain
```

and adding `C:\msys64\mingw64\bin` to my `PATH` environment variable. It seemed that I had GDB available.

## First test

```sh
gdb --args julia -g2 -e "ccall(:jl_breakpoint, Cvoid, (Any,), :success)"
```

The command above start `julia` under `gdb` with extended debug information turned on `-g2` and then executes the statement `ccall(:jl_breakpoint, Cvoid, (Any,), :success)` which is a foreign call to a Julia runtime function called `jl_breakpoint` that we can use to set inspect variables from within GDB.

This and other useful information you can find in the [Julia Developer Documentation](https://docs.julialang.org/en/v1/devdocs/debuggingtips/).

Running the command will drop you into the GDB REPL, where we want to set a breakpoint (`b` shorthand) and then run (`r` shortand) the program.

```
(gdb) b jl_breakpoint
Function "jl_breakpoint" not defined.
Make breakpoint pending on future shared library load? (y or [n]) y
Breakpoint 1 (jl_breakpoint) pending.
(gdb) r
Starting program: C:\Users\vchuravy\AppData\Local\Programs\Julia-1.6.2\bin\julia.exe -g2 -e "ccall(:jl_breakpoint, Cvoid, (Any,), :success)"
```

Shortly thereafter we will hit our breakpoint:

```
Thread 1 hit Breakpoint 1, 0x0000000002687730 in jl_breakpoint (v=0xe6d3d38) at /cygdrive/c/buildbot/worker/package_win64/build/cli/trampolines/trampolines_x86_64.S:19
warning: Source file is more recent than executable.
(gdb)
```

If you print a backtrace (`bt` shorthand) from this location you will notice that the stacktrace is incomplete:

```
(gdb) bt
#0  0x00000000026c7730 in jl_breakpoint (v=0xe723d38) at /cygdrive/c/buildbot/worker/package_win64/build/cli/trampolines/trampolines_x86_64.S:19
#1  0x0000000061090899 in ?? ()
Backtrace stopped: previous frame inner to this frame (corrupt stack?)
```

This is because GDB is unable to find Julia's debug information. We will need to set the environment variable `ENABLE_GDBLISTENER=1` to inform Julia that it needs to notify GDB of the debug information.

```
$env:ENABLE_GDBLISTENER = 1
```

Retracing our steps we now get:

```
(gdb) bt
#0  0x0000000002657730 in jl_breakpoint (v=0x1d583d38) at /cygdrive/c/buildbot/worker/package_win64/build/cli/trampolines/trampolines_x86_64.S:19
#1  0x0000000061090899 in japi1_top-level scope_13 () at none:1
#2  0x00000000026ff5c0 in jl_toplevel_eval_flex (m=m@entry=0xf5a4eb0 <jl_system_image_data+1601136>, e=<optimized out>, fast=<optimized out>, fast@entry=1, expanded=expanded@entry=0)
    at /cygdrive/c/buildbot/worker/package_win64/build/src/toplevel.c:871
#3  0x00000000026ffdc2 in jl_toplevel_eval_flex (m=0xf5a4eb0 <jl_system_image_data+1601136>, m@entry=0xc813f10, e=0x192328b0, e@entry=0x7ffc07040003, fast=fast@entry=1, expanded=expanded@entry=0)
    at /cygdrive/c/buildbot/worker/package_win64/build/src/toplevel.c:825
#4  0x0000000002700d10 in jl_toplevel_eval (v=0x7ffc07040003, m=0xc813f10) at /cygdrive/c/buildbot/worker/package_win64/build/cli/trampolines/trampolines_x86_64.S:19
#5  jl_toplevel_eval_in (m=0xc813f10, ex=0x7ffc07040003) at /cygdrive/c/buildbot/worker/package_win64/build/src/toplevel.c:929
#6  0x000000000f242f34 in eval () at boot.jl:360
#7  julia_exec_options_25396 () at client.jl:261
#8  0x000000000ed7a9a0 in julia__start_39744 () at client.jl:485
#9  0x000000000ed7ab2f in jfptr.start_39745.clone_1 () at client.jl:288
```

Which is much more helpful. Calling the function `jl_` we can print out the Julia value of `v`.

```
(gdb) c jl_(v)
:success
Value can't be converted to integer.
```

## Configuring VSCode

### Getting the Julia source code

In order to be able to step through the Julia runtime it helps to have the source code locally available.
Make sure to 

```bash
git clone https://github.com/JuliaLang/julia
git -C julia checkout v1.6.2
```

Make sure that you checkout the tag of your installed Julia version.

\note{}{
    Currently the pre-built Julia doesn't have debug symbols available and building Julia on
    windows is a whole different adventure.
}

### `launch.json`

My `launch.json` looks like this
```json
{
    // Use IntelliSense to learn about possible attributes.
    // Hover to view descriptions of existing attributes.
    // For more information, visit: https://go.microsoft.com/fwlink/?linkid=830387
    "version": "0.2.0",
    "configurations": [
        {
            "name": "(gdb) Launch",
            "type": "cppdbg",
            "request": "launch",
            "program": "C:\\Users\\vchuravy\\AppData\\Local\\Programs\\Julia-1.6.2\\bin\\julia.exe",
            "args": ["--project=.", "${file}"],
            "stopAtEntry": false,
            "cwd": "${workspaceFolder}",
            "environment": [
                {"name":"ENABLE_GDBLISTENER", "value":"1"},
            ],
            "externalConsole": false,
            "MIMode": "gdb",
            "miDebuggerPath": "gdb",
            "setupCommands": [
                {
                    "description": "Enable pretty-printing for gdb",
                    "text": "-enable-pretty-printing",
                    "ignoreFailures": true
                }
            ],
            "symbolOptions": {
                "searchMicrosoftSymbolServer": true,
                "cachePath": "%TEMP%\\symcache",
            },
            "sourceFileMap": {
                "/cygdrive/c/buildbot/worker/package_win64/build/src" : "C:\\Users\\vchuravy\\dev\\julia\\src"
            }
        },
    ]
}
```

The two important settings are `environment` to include the `ENABLE_GDBLISTENER` and the `sourceFileMap` that maps
the paths on the buildserver to a local checkout.

{{ addcomments }}
