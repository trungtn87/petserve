extends SceneTree

# Explicit opt-in integration check: one real AI request; consumes provider quota.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--live"):
		print("Add -- --live to send one real AI request.")
		quit(0)
		return
	var lab: Control = load("res://tools/image_lab/image_lab.tscn").instantiate()
	root.add_child(lab)
	lab._prepare()
	if lab.request == null:
		push_error(lab.status.text)
		quit(1)
		return
	await lab._render()
	print(lab.status.text)
	if lab.last_path.is_empty():
		quit(1)
		return
	lab.target.select(1)
	lab._refresh()
	lab._add_gene()
	lab._prepare()
	if lab.request == null:
		push_error(lab.status.text)
		quit(1)
		return
	print("LIVE stage 1 + stage 2 UI prompt preparation: PASS")
	quit(0)
