class_name Look
extends Resource

@export_group("Color Grading")
@export_range(0.0, 1.0) var grade_amount := 0.32
@export_range(0.0, 2.0) var saturation := 1.05
@export_range(0.0, 0.2) var grain := 0.012
@export_range(0.0, 0.05) var chroma := 0.012
@export_range(0.0, 1.0) var vignette := 0.35

@export_group("Tonemap & Glow")
@export_range(0.2, 3.0) var exposure := 0.78
@export_range(0.5, 2.0) var agx_contrast := 1.18
@export_range(0.0, 2.0) var glow_intensity := 0.3
@export_range(0.0, 2.0) var glow_strength := 1.1
@export_range(0.5, 2.0) var glow_threshold := 1.15

@export_group("Light Shafts")
@export_range(0.0, 2.0) var ray_amount := 0.16
@export_range(0.5, 1.5) var ray_threshold := 1.0

@export_group("Lights")
@export var sun_energy := Vector2(0.45, 1.1)
@export_range(0.0, 1.0) var sun_height := 0.25
@export var lantern_color := Color(1.0, 0.68, 0.36)
@export var lantern_energy := Vector2(4.5, 6.5)
@export var girl_light_energy := Vector2(0.5, 0.8)

@export_group("Colors")
@export var trunk_tint := Color(0.42, 0.38, 0.4)
@export var cloak := Color(0.86, 0.28, 0.2)
@export var hood := Color(0.93, 0.36, 0.25)
@export var rope := Color(0.62, 0.62, 0.66)
@export var leaf_fall := Color(0.3, 0.42, 0.2)
@export var leaf_tint := Color(0.45, 0.6, 0.36)

@export_group("Weather")
@export_range(0, 4000) var rain_max := 1600
@export var rain_color := Color(0.75, 0.8, 0.9, 0.35)
@export_range(0.0, 4.0) var flash_exposure := 1.6
@export_range(0.0, 3.0) var wind_sway := 1.0
