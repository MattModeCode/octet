extends Control
## Reusable "Octet ambient background" component: a radial top/near-corner
## glow plus a slow-breathing pink vignette. Matches the shared background
## treatment repeated across the Main Menu / Gameplay HUD / Results /
## Calibration Claude mockups:
##   background: radial-gradient(<extent> at <center>, #1a1520 0%, #0C0A0F 60%);
##   + an overlaid radial-gradient(rgba(255,45,110,.06), transparent 70%)
##     animated via `octetVignette` (opacity .5<->.75, 6s ease-in-out infinite).
##
## Pure display, no class_name (same convention as playfield_view.gd /
## waveform_view.gd) — instanced as a packed scene so the four screens that
## use it don't duplicate the gradient-building code.

## Normalized (0-1) centre of the glow, matching CSS "at X% Y%". Per-screen
## override: main menu uses (0.2, 0.3); gameplay/results/calibration use
## (0.5, 0.0).
@export var glow_center: Vector2 = Vector2(0.5, 0.0)
## Normalized radial extent from glow_center (how far the near colour
## reaches before settling into ink).
@export var glow_extent: Vector2 = Vector2(0.6, 0.55)
@export var vignette_center: Vector2 = Vector2(0.5, 1.0)
@export var vignette_extent: Vector2 = Vector2(0.45, 0.55)
## Main Menu's mockup has only the glow, no breathing vignette overlay
## (unlike Gameplay HUD/Results/Calibration, which all repeat it) — set
## false to skip building/animating it entirely rather than showing an
## invisible-but-still-ticking Tween.
@export var show_vignette: bool = true

## Baked hex — .tscn/.tres parse before DesignTokens autoload exists, and
## this script itself may run before _ready() ordering guarantees the
## autoload is reachable, so the two background hex values are baked here
## (documented, same exception as gameplay.tscn's colour comment block).
const COLOR_GLOW_NEAR: Color = Color(0.101961, 0.082353, 0.12549, 1.0) # #1a1520
const COLOR_INK: Color = Color(0.047, 0.039, 0.059, 1.0)               # #0C0A0F
const COLOR_VIGNETTE_PINK: Color = Color(1.0, 0.176471, 0.431373, 0.06) # #FF2D6E @ 6%

const VIGNETTE_MIN_ALPHA := 0.5
const VIGNETTE_MAX_ALPHA := 0.75
const VIGNETTE_HALF_PERIOD_SEC := 3.0 # full breathe cycle = 6s, matches octetVignette

const TEXTURE_RESOLUTION := 512

@onready var _glow_rect: TextureRect = %GlowRect
@onready var _vignette_rect: TextureRect = %VignetteRect

var _vignette_tween: Tween


func _ready() -> void:
	_glow_rect.texture = _build_radial_texture(glow_center, glow_extent, COLOR_GLOW_NEAR, COLOR_INK, 0.6)
	_vignette_rect.visible = show_vignette
	if show_vignette:
		var transparent_pink := Color(COLOR_VIGNETTE_PINK.r, COLOR_VIGNETTE_PINK.g, COLOR_VIGNETTE_PINK.b, 0.0)
		_vignette_rect.texture = _build_radial_texture(vignette_center, vignette_extent, COLOR_VIGNETTE_PINK, transparent_pink, 0.7)
		_start_vignette_breath()


func _build_radial_texture(center: Vector2, extent: Vector2, near_color: Color, far_color: Color, far_offset: float) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, near_color)
	gradient.add_point(far_offset, far_color)
	if far_offset < 1.0:
		gradient.add_point(1.0, far_color)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = TEXTURE_RESOLUTION
	texture.height = TEXTURE_RESOLUTION
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = center
	texture.fill_to = center + extent
	return texture


func _start_vignette_breath() -> void:
	if _reduced_motion():
		_vignette_rect.modulate.a = (VIGNETTE_MIN_ALPHA + VIGNETTE_MAX_ALPHA) / 2.0
		return
	_vignette_tween = create_tween()
	_vignette_tween.set_loops()
	_vignette_tween.set_trans(Tween.TRANS_SINE)
	_vignette_tween.set_ease(Tween.EASE_IN_OUT)
	_vignette_tween.tween_property(_vignette_rect, "modulate:a", VIGNETTE_MAX_ALPHA, VIGNETTE_HALF_PERIOD_SEC)
	_vignette_tween.tween_property(_vignette_rect, "modulate:a", VIGNETTE_MIN_ALPHA, VIGNETTE_HALF_PERIOD_SEC)


## Defensive lookup, mirroring the pattern already established in
## game/gameplay.gd and ui/main.gd, so this component works standalone
## before every autoload necessarily exists.
func _reduced_motion() -> bool:
	if get_tree() == null or not get_tree().root.has_node("SettingsStore"):
		return false
	if "settings" not in SettingsStore or SettingsStore.settings == null:
		return false
	return "reduced_motion" in SettingsStore.settings and SettingsStore.settings.reduced_motion
