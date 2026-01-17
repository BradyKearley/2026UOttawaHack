# Example: How to use Sentry tracking in your game scripts
extends Node

# Get reference to Sentry singleton
var sentry: Node = null

func _ready():
	# Get Sentry node
	sentry = get_tree().get_first_node_in_group("sentry")
	if not sentry:
		print("Warning: Sentry not found!")
		return
	
	# Example 1: Track important game events
	sentry.track_event("Level loaded", "level_1")
	
	# Example 2: Report an error with context
	var context = {
		"player_health": 50,
		"enemy_count": 5,
		"level": "dungeon_1"
	}
	sentry.report_error("Failed to load asset", context)
	
	# Example 3: Track custom events
	sentry.track_event("Boss fight started")
	sentry.track_event("Player died", "cause: monster")
	sentry.track_event("Achievement unlocked", "speedrun_master")

# Sentry automatically tracks:
# - FPS drops below 30 (lag detection)
# - Game crashes
# - Errors with cooldown to prevent spam
