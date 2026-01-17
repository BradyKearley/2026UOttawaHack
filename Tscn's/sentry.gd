extends Node

# Performance monitoring
var fps_samples: Array = []  # Short-term rolling window
const FPS_SAMPLE_SIZE = 60  # Track last 60 frames
var fps_minute_samples: Array = []  # Store FPS for the last minute
const LOW_FPS_THRESHOLD = 30  # Report if FPS drops below this
var last_low_fps_report_time: float = 0.0
const LOW_FPS_COOLDOWN = 5.0  # Seconds between lag reports
var last_periodic_fps_report_time: float = 0.0
const PERIODIC_FPS_REPORT_INTERVAL = 30.0  # Report FPS every 30 seconds

# Error tracking
var error_cooldown_dict: Dictionary = {}
const ERROR_COOLDOWN = 10.0  # Seconds between same error reports

func _ready():
	# Initialize Sentry with startup breadcrumb
	SentrySDK.add_breadcrumb(SentryBreadcrumb.create("Game started"))
	SentrySDK.capture_message("Game session started")
	
	# Set up error handling
	var _err = get_tree().connect("node_added", _on_node_added_to_tree)
	
	print("Sentry monitoring initialized")

func _process(delta):
	# Monitor FPS for performance issues
	_track_fps(delta)

func _track_fps(delta):
	var current_fps = Engine.get_frames_per_second()
	
	# Add to rolling window
	fps_samples.append(current_fps)
	if fps_samples.size() > FPS_SAMPLE_SIZE:
		fps_samples.pop_front()
	
	# Add to minute-long history (assuming ~60 FPS, store every second = ~3600 samples for 60 seconds)
	# Store one sample per second
	if fps_minute_samples.size() == 0 or fps_samples.size() >= FPS_SAMPLE_SIZE:
		fps_minute_samples.append(current_fps)
		# Keep only last 60 seconds of data (one sample per second)
		if fps_minute_samples.size() > 60:
			fps_minute_samples.pop_front()
	
	# Calculate average FPS
	if fps_samples.size() >= FPS_SAMPLE_SIZE:
		var avg_fps = 0.0
		for fps in fps_samples:
			avg_fps += fps
		avg_fps /= fps_samples.size()
		
		var current_time = Time.get_ticks_msec() / 1000.0
		
		# Report periodic FPS every 30 seconds
		if current_time - last_periodic_fps_report_time > PERIODIC_FPS_REPORT_INTERVAL:
			last_periodic_fps_report_time = current_time
			report_periodic_fps(avg_fps, current_fps)
		
		# Report if experiencing lag
		if avg_fps < LOW_FPS_THRESHOLD and current_time - last_low_fps_report_time > LOW_FPS_COOLDOWN:
			last_low_fps_report_time = current_time
			report_lag(avg_fps, current_fps)

func report_lag(avg_fps: float, current_fps: float):
	"""Report performance issues to Sentry"""
	SentrySDK.add_breadcrumb(SentryBreadcrumb.create(
		"Performance degradation detected: avg_fps=%.1f, current_fps=%.1f" % [avg_fps, current_fps]
	))
	
	# Capture as a message with warning level
	SentrySDK.capture_message(
		"Game experiencing lag (FPS: %.1f)" % avg_fps
	)
	
	print("Sentry: Lag reported - FPS: %.1f" % avg_fps)

func report_periodic_fps(avg_fps: float, current_fps: float):
	"""Report FPS stats periodically to Sentry with minute-long history"""
	
	# Calculate detailed statistics from minute samples
	var stats = _calculate_fps_stats()
	
	# Create visual ASCII graph
	var graph = _create_fps_graph()
	
	SentrySDK.add_breadcrumb(SentryBreadcrumb.create(
		"Periodic FPS report: avg_fps=%.1f, current_fps=%.1f" % [avg_fps, current_fps]
	))
	
	# Add statistics as breadcrumb
	SentrySDK.add_breadcrumb(SentryBreadcrumb.create(
		"FPS Stats (60s): min=%.1f, max=%.1f, median=%.1f, p95=%.1f" % [stats.min_fps, stats.max_fps, stats.median, stats.p95]
	))
	
	# Add graph as breadcrumb
	SentrySDK.add_breadcrumb(SentryBreadcrumb.create("FPS Graph (last 60s): " + graph))
	
	# Capture as a message with full details
	var message = "FPS Report: avg=%.1f, current=%.1f | min=%.1f, max=%.1f, median=%.1f, p95=%.1f" % [
		avg_fps, current_fps, stats.min_fps, stats.max_fps, stats.median, stats.p95
	]
	SentrySDK.capture_message(message)
	
	print("Sentry: Periodic FPS report - " + message)
	print("  Graph: " + graph)

func _calculate_fps_stats() -> Dictionary:
	"""Calculate detailed statistics from minute FPS samples"""
	var stats = {
		"min_fps": 0.0,
		"max_fps": 0.0,
		"median": 0.0,
		"p95": 0.0,
		"avg": 0.0
	}
	
	if fps_minute_samples.size() == 0:
		return stats
	
	# Calculate min, max, avg
	stats.min_fps = fps_minute_samples[0]
	stats.max_fps = fps_minute_samples[0]
	var sum = 0.0
	
	for fps in fps_minute_samples:
		sum += fps
		if fps < stats.min_fps:
			stats.min_fps = fps
		if fps > stats.max_fps:
			stats.max_fps = fps
	
	stats.avg = sum / fps_minute_samples.size()
	
	# Calculate median and p95
	var sorted_samples = fps_minute_samples.duplicate()
	sorted_samples.sort()
	
	var mid_index = sorted_samples.size() / 2
	stats.median = sorted_samples[mid_index]
	
	var p95_index = int(sorted_samples.size() * 0.95)
	if p95_index >= sorted_samples.size():
		p95_index = sorted_samples.size() - 1
	stats.p95 = sorted_samples[p95_index]
	
	return stats

func _create_fps_graph() -> String:
	"""Create a simple ASCII graph of FPS over the last minute"""
	if fps_minute_samples.size() == 0:
		return "[No data]"
	
	# Use sparkline-style characters
	var graph = ""
	var max_fps = 0.0
	var min_fps = 999.0
	
	# Find range
	for fps in fps_minute_samples:
		if fps > max_fps:
			max_fps = fps
		if fps < min_fps:
			min_fps = fps
	
	# Normalize and create graph
	var range = max_fps - min_fps
	if range == 0:
		range = 1.0
	
	for fps in fps_minute_samples:
		var normalized = (fps - min_fps) / range
		if normalized < 0.2:
			graph += "▁"
		elif normalized < 0.4:
			graph += "▂"
		elif normalized < 0.6:
			graph += "▄"
		elif normalized < 0.8:
			graph += "▆"
		else:
			graph += "█"
	
	return graph

func report_error(error_message: String, context: Dictionary = {}):
	"""Public method to report errors from other scripts"""
	var error_key = error_message.hash()
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Check cooldown to avoid spam
	if error_key in error_cooldown_dict:
		if current_time - error_cooldown_dict[error_key] < ERROR_COOLDOWN:
			return  # Skip reporting
	
	error_cooldown_dict[error_key] = current_time
	
	# Add context as breadcrumbs
	for key in context:
		SentrySDK.add_breadcrumb(SentryBreadcrumb.create("%s: %s" % [key, str(context[key])]))
	
	# Report the error
	SentrySDK.capture_message(error_message)
	print("Sentry: Error reported - %s" % error_message)

func track_event(event_name: String, details: String = ""):
	"""Track game events as breadcrumbs for context"""
	var message = event_name if details.is_empty() else "%s: %s" % [event_name, details]
	SentrySDK.add_breadcrumb(SentryBreadcrumb.create(message))

func _on_node_added_to_tree(node: Node):
	# Connect to any node's script errors if possible
	pass  # Godot handles most errors automatically

func _notification(what):
	if what == NOTIFICATION_CRASH:
		SentrySDK.capture_message("Game crashed")
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		SentrySDK.add_breadcrumb(SentryBreadcrumb.create("Game closing"))
		get_tree().quit()
