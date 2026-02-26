extends Control
class_name TerminalAppStub

@export var app_title: String = "APP"
@export_multiline var body_text: String = ""
@export var primary_label: String = ""
@export var primary_intermission_only: bool = false
@export var locked_reason: String = "Action available during intermission only."

var controller: Node = null
var _is_intermission: bool = false

@onready var title_label: Label = %Title
@onready var lock_banner: Label = %LockBanner
@onready var body: RichTextLabel = %Body
@onready var primary_btn: Button = %Primary

func set_controller(c: Node) -> void:
	controller = c

func set_intermission_active(v: bool) -> void:
	_is_intermission = v
	_refresh_lock_state()

func refresh() -> void:
	title_label.text = app_title
	body.text = body_text
	_refresh_lock_state()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	primary_btn.pressed.connect(_on_primary_pressed)
	refresh()

func _refresh_lock_state() -> void:
	var locked := primary_intermission_only and not _is_intermission
	lock_banner.visible = locked
	lock_banner.text = locked_reason if locked else ""
	primary_btn.visible = (primary_label != "")
	primary_btn.text = primary_label
	primary_btn.disabled = locked or (primary_label == "")

func _on_primary_pressed() -> void:
	# stub: no-op (keep silent to avoid log spam)
	pass