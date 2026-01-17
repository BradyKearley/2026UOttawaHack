# Sentry Integration Summary

## Files Modified

### 1. Tscn's/sentry.gd (Enhanced)

**Features Added:**

- Automatic FPS/lag monitoring (reports when FPS drops below 30)
- Error tracking with cooldown to prevent spam
- Public API for other scripts to use
- Tracks game lifecycle events (startup, shutdown, crashes)

**Public Methods:**

```gdscript
report_error(error_message: String, context: Dictionary = {})
track_event(event_name: String, details: String = "")
```

### 2. Tscn's/Player.gd (Enhanced)

**Tracking Added:**

- Player initialization
- Player winded events (stamina depleted)
- Fear/panic triggers when intensity > 0.5
- Critical BPM levels (when reaching 180+)

### 3. monster.gd (Enhanced)

**Tracking Added:**

- Monster initialization
- When monster hears player sounds

### 4. Tscn's/map.tscn (Modified)

**Change:**

- Added "sentry" group to Sentry node for easy discovery

### 5. README.md (Updated)

- Added documentation on Sentry features
- Usage examples
- Link to Sentry dashboard

## What Gets Automatically Tracked

### Performance Issues

- FPS drops below 30 (averaged over 60 frames)
- Reports every 5 seconds max to avoid spam
- Includes both average and current FPS

### Player Events

- Player initialization
- Stamina depletion (winded)
- Fear triggers > 0.5 intensity
- BPM reaching critical levels (180+)
- Includes context: BPM, stamina, monster proximity modifier

### Monster Events

- Monster initialization
- Sound detection with strength and distance

### Errors

- Manual error reporting from any script
- 10-second cooldown per unique error
- Support for context dictionary

## How to Use in Your Code

### Track Custom Events

```gdscript
var sentry = get_tree().get_first_node_in_group("sentry")
if sentry:
    sentry.track_event("Boss defeated", "time: 5:32")
    sentry.track_event("Achievement unlocked")
```

### Report Errors with Context

```gdscript
if not asset_loaded:
    var context = {
        "asset_path": "res://models/boss.glb",
        "player_level": 5,
        "memory_usage": OS.get_static_memory_usage()
    }
    sentry.report_error("Failed to load boss asset", context)
```

## Viewing Your Data

1. Go to https://sentry.io/
2. Sign in to your account
3. View errors, performance issues, and breadcrumbs
4. DSN is configured in project.godot under [sentry] section

## Benefits

- **Debug Production Issues**: See what actually happens when players play
- **Performance Monitoring**: Know when/where the game lags
- **Player Behavior**: Understand how players trigger panic states
- **Monster AI**: Track when AI detects and responds to sounds
- **Context-Rich**: Each error includes breadcrumbs of what led to it
