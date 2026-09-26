class_name WallVisual extends Node2D
## Muri con estrusione (faccia superiore illuminata, bordo d'ombra)
## che li trasformano da carta in oggetti con altezza.

const EXT := Vector2(14.0, -14.0)
const WALL_FRONT := Color(0.15, 0.18, 0.25)
const WALL_TOP := Color(0.24, 0.28, 0.38)
const WALL_EDGE := Color(0.09, 0.10, 0.16)
const WALL_HL := Color(0.35, 0.42, 0.60)
const WALL_SH := Color(0.055, 0.065, 0.10)


static func instance(rect: Rect2) -> Node2D:
    var n := Node2D.new()
    n.position = rect.position
    var sz := rect.size

    var front := Polygon2D.new()
    front.polygon = PackedVector2Array([Vector2.ZERO, Vector2(sz.x, 0), sz, Vector2(0, sz.y)])
    front.color = WALL_FRONT
    front.name = "Front"
    n.add_child(front)

    var top := Polygon2D.new()
    top.polygon = PackedVector2Array([
        EXT, Vector2(sz.x, 0) + EXT, sz + EXT, Vector2(0, sz.y) + EXT])
    top.color = WALL_TOP
    top.name = "Top"
    n.add_child(top)

    var edge := Polygon2D.new()
    edge.polygon = PackedVector2Array([
        Vector2(0, sz.y), Vector2.ZERO, EXT, EXT + Vector2(0, sz.y)])
    edge.color = WALL_EDGE
    edge.name = "Edge"
    n.add_child(edge)

    # Bordo luminoso sulla faccia superiore (lato luce).
    var hl := Line2D.new()
    hl.points = PackedVector2Array([EXT, sz + EXT])
    hl.default_color = WALL_HL
    hl.width = 1.6
    hl.name = "HL"
    n.add_child(hl)
    # Ombra sul bordo inferiore della faccia anteriore.
    var sh := Line2D.new()
    sh.points = PackedVector2Array([Vector2.ZERO, Vector2(sz.x, 0)])
    sh.default_color = WALL_SH
    sh.width = 1.4
    sh.name = "Shadow"
    n.add_child(sh)
    # Ombra verticale sul bordo sinistro.
    var vs := Line2D.new()
    vs.points = PackedVector2Array([Vector2.ZERO, Vector2(0, sz.y)])
    vs.default_color = WALL_SH
    vs.width = 1.0
    vs.name = "VShadow"
    n.add_child(vs)

    # Collisore sulla faccia anteriore (si cammina contro il muro).
    var sb := StaticBody2D.new()
    sb.name = "Collider"
    sb.position = sz * 0.5
    var cs := CollisionShape2D.new()
    var box := RectangleShape2D.new()
    box.size = sz
    cs.shape = box
    sb.add_child(cs)
    n.add_child(sb)
    return n


static func shadow_instance(rect: Rect2) -> Node2D:
    var n := Node2D.new()
    n.position = rect.position
    var rings := [Vector2(0.0, 0.0), Vector2(4.0, 4.0), Vector2(9.0, 9.0), Vector2(15.0, 15.0)]
    var alphas := PackedFloat32Array([0.75, 0.45, 0.22, 0.08])
    var i := 0
    for off in rings:
        var r := Rect2(-off.x, -off.y, rect.size.x + off.x * 2, rect.size.y + off.y * 2)
        var p := Polygon2D.new()
        p.polygon = PackedVector2Array([Vector2.ZERO, Vector2(r.size.x, 0), r.size, Vector2(0, r.size.y)])
        p.color = Color(0.04, 0.05, 0.09, alphas[i])
        p.name = "ShadowRing" if i == 0 else "ShadowRing%d" % i
        n.add_child(p)
        i += 1
    var hl := Polygon2D.new()
    hl.polygon = PackedVector2Array([Vector2.ZERO, Vector2(rect.size.x, 0), Vector2(rect.size.x, 2.0), Vector2(0, 2.0)])
    hl.color = Color(0.10, 0.12, 0.18, 0.5)
    hl.name = "ShadowHL"
    n.add_child(hl)
    return n
