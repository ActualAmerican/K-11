extends Sprite2D
class_name AlphaOutline

@export var outline_color: Color = Color(1, 1, 1, 0.9)
@export var outline_size: float = 3.5
@export var outline_softness: float = 0.6
@export var pulse_speed: float = 1.6
@export var pulse_amount: float = 0.35

var _mat: ShaderMaterial = null


func _ready() -> void:
	_ensure_material()


func _process(_delta: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("outline_color", outline_color)
		_mat.set_shader_parameter("outline_size", outline_size)
		_mat.set_shader_parameter("outline_softness", outline_softness)
		_mat.set_shader_parameter("pulse_speed", pulse_speed)
		_mat.set_shader_parameter("pulse_amount", pulse_amount)


func _ensure_material() -> void:
	if _mat != null:
		return

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 0.9);
uniform float outline_size = 1.5;
uniform float outline_softness = 0.6;
uniform float pulse_speed = 1.6;
uniform float pulse_amount = 0.35;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float a = tex.a;
	vec2 px = TEXTURE_PIXEL_SIZE * outline_size;

	float max_a = 0.0;
	max_a = max(max_a, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	max_a = max(max_a, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
	max_a = max(max_a, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	max_a = max(max_a, texture(TEXTURE, UV + vec2(0.0, -px.y)).a);
	max_a = max(max_a, texture(TEXTURE, UV + vec2(px.x, px.y)).a);
	max_a = max(max_a, texture(TEXTURE, UV + vec2(-px.x, px.y)).a);
	max_a = max(max_a, texture(TEXTURE, UV + vec2(px.x, -px.y)).a);
	max_a = max(max_a, texture(TEXTURE, UV + vec2(-px.x, -px.y)).a);

	float edge = max_a - a;
	float t = smoothstep(0.0, max(outline_softness, 0.001), edge);
	if (t <= 0.0 || a > 0.01) {
		COLOR = vec4(0.0);
	} else {
		float glow = 1.0 + pulse_amount * sin(TIME * pulse_speed * 6.2831853);
		COLOR = outline_color * t * glow;
	}
}
"""

	_mat = ShaderMaterial.new()
	_mat.shader = shader
	material = _mat
