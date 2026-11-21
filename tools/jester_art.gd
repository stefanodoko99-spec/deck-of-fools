extends SceneTree
## Convert an illustration into Jester card art: optional crop of a few pixels off
## each edge, shrink to at most 640 px wide, save as lossy WebP.
## Usage: godot --headless --script tools/jester_art.gd -- <in.png|jpg|webp> <out.webp> [margin]

const MAX_WIDTH := 640


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: -- <in> <out.webp> [margin]")
		quit(1)
		return
	var img := Image.load_from_file(args[0])
	if img == null or img.is_empty():
		push_error("could not read " + args[0])
		quit(1)
		return
	var margin := int(args[2]) if args.size() > 2 else 0
	if margin > 0:
		img = img.get_region(Rect2i(margin, margin, img.get_width() - 2 * margin, img.get_height() - 2 * margin))
	if img.get_width() > MAX_WIDTH:
		img.resize(MAX_WIDTH, roundi(img.get_height() * MAX_WIDTH / float(img.get_width())), Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGB8)
	var err := img.save_webp(args[1], true, 0.9)
	print("%s: %dx%d (%s)" % [args[1].get_file(), img.get_width(), img.get_height(), "ok" if err == OK else error_string(err)])
	quit(0 if err == OK else 1)
