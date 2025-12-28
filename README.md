# HookTracer

Lightweight performance profiler for Garry's Mod hooks with real-time monitoring and statistical analysis.

## Features

- **Real-time profiling** - Track hook execution time and frequency
- **Live monitoring** - See slow hooks as they happen
- **Smart detection** - Automatic identification of performance issues
- **Memory efficient** - Object pooling and optimized data structures
- **Color-coded output** - Visual severity indicators in console
- **JSON export** - Detailed reports for external analysis

## Installation

Drop `hooktracer.lua` into `lua/autorun/client/`

## Quick Start
```
tr_start          // Begin profiling
tr_stats          // View statistics
tr_issues         // Check for problems
tr_stop           // Stop profiling
```

## Commands

| Command | Description |
|---------|-------------|
| `tr_start` | Start tracing hooks |
| `tr_stop` | Stop tracing |
| `tr_stats` | Display performance statistics |
| `tr_issues` | Show detected performance problems |
| `tr_export` | Export data to JSON |
| `tr_clear` | Clear all collected data |
| `tr_threshold <ms>` | Set slow hook threshold (default: 1ms) |
| `tr_live` | Toggle live slow hook monitoring |
| `tr_unhook` | Restore original hook system |

## Performance Indicators

**Severity Levels:**
- 🔴 **HIGH** - Hooks averaging >5ms (critical)
- 🟠 **MEDIUM** - Hooks called >1000 times or with 10x spikes
- 🟢 **OK** - Normal performance

## Technical Details

**What gets traced:**
- All hooks called via `hook.Call()`
- Custom hooks added with `hook.Add()`
- GameMode functions (GM:*)

**What doesn't get traced:**
- Engine-level C++ hooks (Think, CreateMove, etc.)
- Direct function calls bypassing hook system
- Hooks added after tracer starts (until re-initialization)

## Example Output
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 HOOK TRACER STATISTICS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Tracked Hooks: 45 │ Total Calls: 8234

▼ SLOWEST HOOKS (by average)
 1. HUDPaint
    2.34ms avg │ 8.91ms max │ 312 calls
 2. PlayerTick
    0.89ms avg │ 2.10ms max │ 1450 calls
```

## Export Format

JSON structure:
```json
{
  "entries": [...],
  "stats": {...},
  "timestamp": 1735459200,
  "date": "Sun Dec 29 2024",
  "threshold": 1.0,
  "entry_count": 1000,
  "stat_count": 45
}
```
