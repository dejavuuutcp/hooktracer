useless lua🤮
# HookTracer
A lightweight profiler for Garry’s Mod Lua hooks.
Tracks which hooks are called, how often, and how long they take to run.
## Notes
- **Only hooks executed via `hook.Call` are traced.**
Hooks added with `hook.Add` are not automatically profiled unless the event itself is fired through `hook.Call`.
- Engine-level hooks like `Think` or `CreateMove` are called internally in C++ and won’t appear in reports.
## Commands
hooktracer_start - start tracing
hooktracer_stop - stop tracing
hooktracer_stats - show collected stats
hooktracer_problems - slow/frequent hooks
hooktracer_export - export JSON
hooktracer_clear - clear data
hooktracer_threshold - set slow hook threshold [ms]
hooktracer_live - show slow hooks live in consol
## Usage
1. Place `hooktracer.lua` in `lua/autorun/`.
2. Run in console:
hooktracer_start
hooktracer_stats
hooktracer_problems
3. To save report:
4. hooktracer_export
