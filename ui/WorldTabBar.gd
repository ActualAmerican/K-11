extends Node2D

@export var active_tab: String = ""
@export var highlight_color: Color = Color(1, 1, 1, 0.25)

var _tabs: Array[Area2D] = []
var _highlights: Dictionary = {}
var _enabled: bool = true


func _ready() -> void:
	for child in get_children():
		if child is Area2D:
			var tab := child as Area2D
			_tabs.append(tab)
			tab.input_event.connect(_on_tab_input_event.bind(tab))
			var highlight := tab.get_node_or_null("Highlight")
			if highlight is Polygon2D:
				var poly := highlight as Polygon2D
				_highlights[tab] = poly
				poly.visible = false
				poly.color = highlight_color
				_sync_highlight_polygon(tab, poly)

	if active_tab == "":
		if _tabs.size() > 0:
			_set_active_tab(_tab_name(_tabs[0]))
	else:
		_set_active_tab(active_tab)


func _on_tab_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, tab: Area2D) -> void:
	if not _enabled:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_set_active_tab(_tab_name(tab))


func _tab_name(tab: Area2D) -> String:
	var name := tab.name
	if name.begins_with("Tab_"):
		return name.substr(4, name.length() - 4)
	return name


func _set_active_tab(tab_name: String) -> void:
	active_tab = tab_name
	for tab in _tabs:
		var highlight: Polygon2D = _highlights.get(tab) as Polygon2D
		if highlight != null:
			highlight.visible = _tab_name(tab) == tab_name
	print("[K11] TAB -> %s" % tab_name)


func _sync_highlight_polygon(tab: Area2D, poly: Polygon2D) -> void:
	var shape_node := tab.get_node_or_null("CollisionShape2D")
	if shape_node is CollisionShape2D:
		var shape := (shape_node as CollisionShape2D).shape
		if shape is RectangleShape2D:
			var rect := shape as RectangleShape2D
			var extents := rect.size * 0.5
			poly.polygon = PackedVector2Array([
				Vector2(-extents.x, -extents.y),
				Vector2(extents.x, -extents.y),
				Vector2(extents.x, extents.y),
				Vector2(-extents.x, extents.y),
			])

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
