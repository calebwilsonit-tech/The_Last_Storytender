class_name Iso
extends RefCounted
## 2:1 isometric projection helpers. Gameplay "grid" coords are (x, y) tiles;
## screen coords are what Node2D positions use.

const TILE_W := 64.0
const TILE_H := 32.0

static func to_screen(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * TILE_W * 0.5, (cell.x + cell.y) * TILE_H * 0.5)

static func to_grid(p: Vector2) -> Vector2:
	var gx := p.x / TILE_W + p.y / TILE_H
	var gy := p.y / TILE_H - p.x / TILE_W
	return Vector2(gx, gy)

## Diamond footprint of one tile centered on `center`, scaled by `s`.
static func diamond(center: Vector2, s := 1.0) -> PackedVector2Array:
	var hw := TILE_W * 0.5 * s
	var hh := TILE_H * 0.5 * s
	return PackedVector2Array([
		center + Vector2(0, -hh), center + Vector2(hw, 0),
		center + Vector2(0, hh), center + Vector2(-hw, 0)])
