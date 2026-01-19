extends Label

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	text = "Time: " + str(snapped(Global.time,0.1))


func _on_timer_timeout() -> void:
	Global.time +=0.1
