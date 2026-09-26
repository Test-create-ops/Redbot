class_name Art
extends Object
## Fabbriche visive. Tutto il disegno del gioco passa da qui.

const Colors = preload("res://scripts/colors.gd")
const FloorVisual = preload("res://scripts/floor_visual.gd")
const WallVisual = preload("res://scripts/wall_visual.gd")
const RobotVisual = preload("res://scripts/robot_visual.gd")
const SentinelVisual = preload("res://scripts/sentinel_visual.gd")
const RelicVisual = preload("res://scripts/relic_visual.gd")


static func build_floor(size: Vector2) -> Node2D:
    var n := Node2D.new()
    n.name = "Floor"
    var f := FloorVisual.new()
    f.size = size
    n.add_child(f)
    return n


static func build_walls(walls: Array, shadows: Array) -> Node2D:
    var n := Node2D.new()
    n.name = "Walls"
    for r in walls:
        n.add_child(WallVisual.instance(Rect2(r.position, r.size)))
    var sh := Node2D.new()
    sh.name = "Shadows"
    for r in shadows:
        sh.add_child(WallVisual.shadow_instance(Rect2(r.position, r.size)))
    n.add_child(sh)
    return n


static func draw_robot() -> Node2D:
    var r := RobotVisual.new()
    r.name = "Visual"
    return r


static func draw_sentinel() -> Node2D:
    var s := SentinelVisual.new()
    s.name = "Visual"
    return s


static func draw_relic() -> Node2D:
    var r := RelicVisual.new()
    r.name = "Visual"
    return r
