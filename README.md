# 2026UOttawaHack

## Sentry Monitoring

This project includes Sentry integration for error tracking and performance monitoring.

### What's Automatically Tracked

- **Performance Issues**: FPS drops below 30 (lag detection)
- **Game Crashes**: Automatic crash reporting
- **Errors**: With cooldown to prevent spam
- **Player Events**:
  - Player initialization
  - Player winded (stamina depleted)
  - Fear/panic triggers (high intensity)
  - Critical BPM levels (180+)

### How to Use Sentry in Your Scripts

```gdscript
# Get reference to Sentry
var sentry = get_tree().get_first_node_in_group("sentry")

# Track game events
sentry.track_event("Boss defeated", "boss_name: Dragon")

# Report errors with context
var context = {"player_pos": position, "health": health}
sentry.report_error("AI pathfinding failed", context)
```

### Sentry Dashboard

View your logs and errors at: https://sentry.io/

Your DSN is configured in [project.godot](project.godot) under `[sentry]`
