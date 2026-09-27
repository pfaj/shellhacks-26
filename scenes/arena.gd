class_name Arena
extends RefCounted

const LOCAL_FILL := 0.84
const PEER_SCALE := 0.82
const LOCAL_BOTTOM_CUT := 0.05
const REMOTE_GAP := 0.38
const CONTENT_WIDTH_RATIO := 0.643
const BG_VERTICAL := "res://assets/branding/Shellhacks Background_BG Vertical.svg"
const BG_HORIZONTAL := "res://assets/branding/Shellhacks Background_BG Horizontal.svg"


static func background_path(wide: bool) -> String:
	return BG_HORIZONTAL if wide else BG_VERTICAL


static func layout(stage_size: Vector2, local: Fighter, remote: Fighter) -> void:
	var center := stage_size.x * 0.5
	var local_art := minf(stage_size.y * LOCAL_FILL, stage_size.x * 0.98 / CONTENT_WIDTH_RATIO)
	local.set_art_height(local_art)
	var local_y := stage_size.y + local_art * LOCAL_BOTTOM_CUT
	local.place(Vector2(center, local_y))
	var remote_art := local_art * PEER_SCALE
	remote.set_art_height(remote_art)
	remote.place(Vector2(center, local_y - local_art * REMOTE_GAP))
