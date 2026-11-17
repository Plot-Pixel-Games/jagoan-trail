extends Node2D

@onready var animated_sprite: AnimatedSprite2D = $VisualPivot/AnimatedSprite2D
@onready var visual_pivot: Node2D = $VisualPivot
@onready var crash_timer: Timer = $CrashTimer

@export_group("Movement")
@export var max_speed: float = 500.0
@export var acceleration: float = 150.0
@export var braking: float = 300.0
@export var friction: float = 100.0

@export_group("Jump")
@export var jump_strength: float = 300.0
@export var gravity: float = 1500.0

@export_group("Tilt")
@export var max_tilt_angle: float = 45.0
@export var tilt_speed: float = 60.0
@export var ground_fall_angle: float = 60.0
@export var ground_tilt_acceleration: float = 100.0
@export var ground_tilt_max_speed: float = 100.0
@export var ground_tilt_friction: float = 180.0

@export_group("Landing")
@export var max_landing_tilt: float = 40.0
@export var landing_recovery_speed: float = 200.0

@export_group("Vertical Movement")
@export var vertical_speed: float = 100.0
@export var vertical_range_up: float = 100.0
@export var vertical_range_down: float = 100.0

var initial_y: float = 0.0
var speed: float = 0.0
var jump_height: float = 0.0
var current_vertical_direction: int = 0
var current_animation: String = ""
var vertical_velocity: float = 0.0
var ground_tilt_velocity: float = 0.0
var current_tilt: float = 0.0
var target_tilt: float = 0.0
var is_airborne: bool = false
var is_crashed: bool = false
var is_landing_recovery: bool = false

var sprite_base_position: Vector2

func _ready() -> void:
	sprite_base_position = animated_sprite.position
	initial_y = position.y
	
	animated_sprite.animation_finished.connect(_on_animation_finished)
	crash_timer.timeout.connect(_on_crash_timer_timeout)

func handle_movement(delta: float) -> void:
	if is_crashed: return
		
#	MOVE CONTROL #####################
	if Input.is_action_pressed("accelerate"):
		speed += acceleration * delta

	elif Input.is_action_pressed("brake"):
		speed -= braking * delta

	else:
		speed -= friction * delta

	speed = clampf(speed, 0.0, max_speed)

func handle_vertical_movement(delta: float) -> void:
	if is_crashed: return

	var direction = Input.get_axis("move_up", "move_down")
	position.y += direction * vertical_speed * delta
	position.y = clampf(
		position.y,
		initial_y - vertical_range_up,
		initial_y + vertical_range_down
	)
	
	current_vertical_direction = direction

func handle_jump(delta: float) -> void:
	if is_crashed: return
	
# Memulai lompatan
	if Input.is_action_just_pressed("jump") and not is_airborne and speed > 0:
		is_airborne = true
		vertical_velocity = jump_strength

# Menghitung gerakan vertikal
	if is_airborne:
		vertical_velocity -= gravity * delta
		jump_height += vertical_velocity * delta
		
		# Mendarat
		if jump_height <= 0:
			jump_height = 0
			vertical_velocity = 0
			is_airborne = false
			handle_landing()

func update_jump_visual() -> void:
	animated_sprite.position.y = sprite_base_position.y - jump_height

func handle_tilt(delta: float) -> void:
	if is_crashed or is_landing_recovery: return
	
	# Kondisi ketika berada di udara
	if is_airborne:
		if Input.is_action_pressed("tilt_back"):
			current_tilt = move_toward(
				current_tilt,
				-deg_to_rad(max_tilt_angle),
				deg_to_rad(tilt_speed) * delta
			)
		elif Input.is_action_pressed("tilt_forward"):
			current_tilt = move_toward(
				current_tilt,
				deg_to_rad(max_tilt_angle),
				deg_to_rad(tilt_speed) * delta
			)
	
	# Kondisi ketika berada di darat
	else:
		if Input.is_action_pressed("tilt_back"):
			ground_tilt_velocity += ground_tilt_acceleration * delta
			ground_tilt_velocity = minf(
				ground_tilt_velocity,
				ground_tilt_max_speed
			)
			
		else:
			ground_tilt_velocity = move_toward(
				ground_tilt_velocity,
				0.0,
				ground_tilt_friction * delta
			)
			
		current_tilt -= deg_to_rad(ground_tilt_velocity) * delta
			
		if abs(rad_to_deg(current_tilt)) >= ground_fall_angle:
			trigger_crash()
			return
			
		if not Input.is_action_pressed("tilt_back"):
			current_tilt = move_toward(
				current_tilt,
				0.0,
				deg_to_rad(tilt_speed) * delta
		)

	visual_pivot.rotation = current_tilt
	
	
func handle_landing() -> void:
	var landing_angle = abs(rad_to_deg(current_tilt))
	if landing_angle <= max_landing_tilt: is_landing_recovery = true
	else: trigger_crash()

func handle_landing_recovery(delta: float) -> void:
	if is_crashed or not is_landing_recovery: return

	current_tilt = move_toward(
		current_tilt,
		0.0,
		deg_to_rad(landing_recovery_speed) * delta
	)

	visual_pivot.rotation = current_tilt
	if is_zero_approx(current_tilt):
		current_tilt = 0.0
		visual_pivot.rotation = 0.0
		is_landing_recovery = false

func _on_animation_finished() -> void:
	if animated_sprite.animation == "crash":
		crash_timer.start()

func _on_crash_timer_timeout() -> void:
	reset_player()


func reset_player() -> void:
	# Reset movement
	speed = 0.0

	# Reset jump
	jump_height = 0.0
	vertical_velocity = 0.0
	is_airborne = false

	# Reset tilt
	current_tilt = 0.0
	visual_pivot.rotation = 0.0

	# Reset state
	is_crashed = false
	is_landing_recovery = false

	# Reset visual
	animated_sprite.position = sprite_base_position
	animated_sprite.modulate.a = 1.0
	animated_sprite.play("default")
	
	start_blinking()

func start_blinking() -> void:
	var tween = create_tween()
	tween.set_loops(8)

	tween.tween_property(animated_sprite, "modulate:a", 0.2, 0.1)
	tween.tween_property(animated_sprite, "modulate:a", 1.0, 0.1)

func trigger_crash() -> void:
	if is_crashed: return

	is_crashed = true
	speed = 0.0
	current_tilt = 0.0
	visual_pivot.rotation = 0.0
	ground_tilt_velocity = 0.0
	animated_sprite.play("crash")
	
func handle_animation() -> void:
	var target_animation = ""

	# Priority 1: Crash
	if is_crashed:
		target_animation = "crash"

	# Priority 2 & 3: Vertical movement
	elif current_vertical_direction < 0:
		target_animation = "lean_left"

	elif current_vertical_direction > 0:
		target_animation = "lean_right"

	# Priority 4: Normal movement
	elif speed > 0:
		target_animation = "default"

	# Priority 5: Idle
	else:
		target_animation = ""

	# Jangan memainkan ulang animasi yang sama
	if target_animation == current_animation:
		return

	current_animation = target_animation

	if target_animation == "":
		animated_sprite.stop()
	else:
		animated_sprite.play(target_animation)

func play_movement_animation(animation_name: String) -> void:	
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)

func _physics_process(delta: float) -> void:
	handle_movement(delta)
	handle_vertical_movement(delta)
	handle_jump(delta)
	update_jump_visual()
	handle_tilt(delta)
	handle_landing_recovery(delta)
	handle_animation()
