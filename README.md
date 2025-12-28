useless lua🤮
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

## Technical Details

**What gets traced:**
- All hooks called through `hook.Call()` system
- Any hook registered with `hook.Add()` (Lua or engine-level)
- GameMode functions (GM:Think, GM:PlayerTick, etc.)
- Nested hook calls with depth tracking

**What doesn't get traced:**
- Direct function calls that bypass `hook.Call()`
- Code executed before tracer initialization
- Functions called outside the hook system

**How it works:**
The tracer intercepts `hook.Call()` at runtime, so ANY hook that goes through the hook system gets traced - whether it's Lua-based or engine-level doesn't matter. The key is that it must use `hook.Call()`.

## Example Output
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 STATISTICS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Hooks: 22 │ Calls: 10000

 SLOWEST (avg)
 1. OnSpawnMenuOpen
    5.56ms avg | 9.97ms max | 3 calls
 2. OnSpawnMenuClose
    2.27ms avg | 2.88ms max | 3 calls
```

## Export Format
JSON structure:
```json
{
  "timestamp": 1735459200,
  "date": "2024-12-29 14:30:00",
  "threshold": 1.0,
  "entry_count": 1000,
  "stat_count": 45,
  "stats": {
    "HookName": {
      "calls": 5000,
      "total_time": 250.5,
      "avg_time": 0.0501,
      "max_time": 2.3,
      "min_time": 0.01
    }
  },
  "data": [
    {
      "name": "HookName",
      "duration": 0.05,
      "time": 12345.678,
      "depth": 0,
      "slow": false
    }
  ]
}
```

**Fields:**
- `timestamp`: Unix timestamp of export
- `date`: Human-readable date in `YYYY-MM-DD HH:MM:SS` format
- `threshold`: Slowness threshold in milliseconds
- `entry_count`: Total number of recorded hook calls
- `stat_count`: Number of unique hooks tracked
- `stats`: Per-hook statistics (calls, times in ms)
- `data`: Array of individual hook call records
