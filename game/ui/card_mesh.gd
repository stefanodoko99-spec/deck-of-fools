class_name CardMesh
extends Control
## A card face drawn as a fine grid of triangles instead of a single quad. The card
## shader tilts cards by moving their corners; a single quad then bends its picture
## along the diagonal, which shows on a big card. A grid keeps straight lines straight,
## so the collection's inspect card can tilt much further.

const COLS := 10
const ROWS := 14

var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()

var _mesh: ArrayMesh


func _init(face_size: Vector2) -> void:
	size = face_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for row in ROWS:
		for col in COLS:
			var a := Vector2(float(col) / COLS, float(row) / ROWS)
			var b := Vector2(float(col + 1) / COLS, float(row + 1) / ROWS)
			for corner: Vector2 in [a, Vector2(b.x, a.y), b, a, b, Vector2(a.x, b.y)]:
				uvs.append(corner)
				points.append(corner * face_size)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _draw() -> void:
	if texture != null:
		draw_mesh(_mesh, texture)
