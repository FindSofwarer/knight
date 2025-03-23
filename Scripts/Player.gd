extends CharacterBody2D

enum State { IDLE, RUN, JUMP, ATTACK, ROLL, SLIDE, HEAL, HURT, DEAD }

#SİNYAL UI İÇİN
signal health_changed(new_health: int, max_health: int)  # Can değiştiğinde sinyal gönder
# Köye girildiğinde tetiklenecek sinyal
signal entered_village(village_name: String)


# Can ve Hasar Ayarları
@export_group("Can ve Hasar Ayarları")
@export var max_health: int = 100  # Maksimum can
@export var health: int = 0  # Mevcut can
@export var normal_damage: int = 20
var isDead: bool = false  # Ölüm Kontrolü

# Hareket Ayarları
@export_group("Hareket Ayarları")
@export var max_speed := 400.0
@export_range(0, 2000) var acceleration := 2000.0
@export var friction := 2000.0
@export var jump_force := 300.0
@export var gravity := 980.0
@export var roll_speed := 400.0  # Roll sırasında uygulanacak hız
@export_range(0, 1) var slide_deceleration := 0.9  # Slide sırasında yavaşlama oranı

#Işık ayarları
@export_group("Işık Ayarları")
@export var characterLight: PointLight2D = null
@export var target_energy: float = 1.5  # Hedef enerji değeri
@export var light_transition_speed: float = 1.0  # Geçiş hızı

# Atak Ayarları
@export_group("Atak Ayarları")
@export var attack_horizontal_damping := 3.0  # Havada saldırı sırasında yatay hızın korunma oranı

# Durum Değişkenleri
var current_state: State = State.IDLE
var is_attacking := false
var is_rolling := false
var is_sliding := false

@onready var sprite: AnimatedSprite2D = $"Player-Sprite"
@onready var hitArea: Area2D = $HitArea
@onready var hitColl: CollisionShape2D = $HitArea/HitShape

func _ready():
	health=max_health
	set_state(State.IDLE)
	CameraManager.active_actors.append(self)

func _process(delta):
	if isDead:  # Karakter öldüyse başka bir duruma geçme
		return
	
	characterLight.energy=lerp(characterLight.energy,target_energy, delta*light_transition_speed)
	
	if current_state == State.HURT and not sprite.is_playing():
		if is_on_floor():
			set_state(State.IDLE)
		else:
			set_state(State.JUMP)

func _physics_process(delta):
	if isDead:  # Karakter öldüyse fizik işlemlerini durdur
		return
	
	# Area2D'nin konumunu güncelle
	update_attack_area_position()
	
	# Yerçekimi uygula
	velocity.y += gravity * delta
	
	# Durumu işle
	handle_state(delta)
	
	# Hareketi uygula
	move_and_slide()

func handle_state(delta):
	match current_state:
		State.IDLE:
			state_idle(delta)
		State.RUN:
			state_run(delta)
		State.JUMP:
			state_jump(delta)
		State.ATTACK:
			state_attack(delta)
		State.ROLL:
			state_roll(delta)
		State.SLIDE:
			state_slide(delta)
		State.HURT:
			state_hurt(delta)
		State.HEAL:
			state_heal(delta)  # HEAL durumunu işle

func state_idle(delta):
	apply_friction(delta)
	handle_airborne()
	
	if Input.get_axis("move_left", "move_right") != 0:
		set_state(State.RUN)
	elif Input.is_action_just_pressed("jump"):
		jump()

func state_run(delta):
	var input = Input.get_axis("move_left", "move_right")
	accelerate(input, delta)
	sprite.flip_h = input < 0 if input != 0 else sprite.flip_h
	
	if input == 0:
		set_state(State.IDLE)
	elif Input.is_action_just_pressed("jump"):
		jump()

func state_jump(delta):
	var input = Input.get_axis("move_left", "move_right")
	accelerate(input, delta)
	
	if is_on_floor():
		set_state(State.IDLE)


func state_heal(delta):
	# HEAL animasyonu oynat
	if not sprite.is_playing():  # Animasyon başlamadıysa başlat
		sprite.play("Heal")
	
# Animasyonun bitmesini bekle
	if sprite.animation == "Heal" and sprite.frame == sprite.sprite_frames.get_frame_count("Heal") - 1:
		if is_on_floor():
			set_state(State.IDLE)  # Animasyon bittiğinde IDLE durumuna geç
		else:
			set_state(State.JUMP)  # Havadaysa JUMP durumuna geç


func state_attack(delta):
	# Saldırı sırasında ekran titreşimi tetikle
	CameraManager.add_screen_shake(0.05)
	# Havada saldırı sırasında yatay hızı tamamen sıfırlamak yerine yavaşça azalt
	velocity.x = lerp(velocity.x, 0.0, attack_horizontal_damping * delta)
	
	# Yerçekimi uygula
	velocity.y += gravity * delta
	
	# Saldırı animasyonu bitene kadar bekle
	if not sprite.is_playing():
		set_state(State.IDLE if is_on_floor() else State.JUMP)

func state_roll(delta):
	# Roll sırasında yüzün dönük olduğu yönde hız uygula
	velocity.x = roll_speed * (-1 if sprite.flip_h else 1)
	
	# Roll animasyonu bittiğinde durumu sonlandır
	if not sprite.is_playing():
		end_roll()

func state_slide(delta):
	# Slide sırasında yavaşla
	velocity.x = lerp(velocity.x, 0.0, slide_deceleration * delta)
	
	# Slide animasyonu bittiğinde hıza göre RUN veya IDLE durumuna geç
	if not sprite.is_playing():
		if abs(velocity.x) > 50:  # Hız yeterince büyükse RUN'a geç
			set_state(State.RUN)
		else:  # Hız çok düşükse IDLE'a geç
			set_state(State.IDLE)

func attack():
	if is_attacking:
		return
	
	is_attacking = true  # Saldırı başladı
	
	# Düşmana hasar ver
	var bodies = hitArea.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("Enemy"):
			body.take_damage(normal_damage)
	
	# Saldırı animasyonu bitene kadar bekle
	await get_tree().create_timer(0.5).timeout  # Örnek: 0.5 saniye bekle
	is_attacking = false  # Saldırı bitti

func update_attack_area_position():
	if sprite.flip_h:  # Sola bakıyorsa
		hitColl.position = Vector2(-30, 10)
	else:  # Sağa bakıyorsa
		hitColl.position = Vector2(30, 10)

func set_state(new_state: State):
	if current_state == new_state:
		return
	
	# Exit current state
	match current_state:
		State.ATTACK:
			is_attacking = false
		State.ROLL:
			is_rolling = false
		State.SLIDE:
			is_sliding = false
	
	# Enter new state
	current_state = new_state
	match new_state:
		State.IDLE:
			sprite.play("Idle")
		State.RUN:
			sprite.play("Run")
		State.JUMP:
			sprite.play("Jump")
			velocity.y = -jump_force
		State.ATTACK:
			sprite.play("Attack1" if randf() > 0.5 else "Attack2")
			attack()
		State.ROLL:
			sprite.play("Roll")
			is_rolling = true
		State.SLIDE:
			sprite.play("Slide")
			is_sliding = true
		State.HURT:
			sprite.play("Hurt")  # Hasar alma animasyonunu başlat
		State.DEAD:
			sprite.play("Dead")  # Ölüm animasyonunu başlat
		State.HEAL:
			sprite.play("Heal")  # HEAL animasyonunu başlat

func accelerate(input: float, delta: float):
	var target_speed = input * max_speed
	velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)

func apply_friction(delta: float):
	velocity.x = move_toward(velocity.x, 0, friction * delta)

func jump():
	if is_on_floor() and current_state != State.JUMP:
		set_state(State.JUMP)

func handle_airborne():
	if not is_on_floor():
		if current_state != State.JUMP:
			set_state(State.JUMP)

func take_damage(amount: int):
	
	health -= amount
	health = max(health, 0)  # Canı sıfırın altına düşürme
	emit_signal("health_changed", health, max_health)  # Sinyal gönder
	# Hasar alma animasyonunu başlat
	if health > 0:  # Karakter hala canlıysa
		set_state(State.HURT)  # Hasar alma durumuna geç
	else:
		die()  # Can sıfırlandığında ölüm fonksiyonunu çağır

func light_change(target_energy: float, duration: float):
	self.target_energy = target_energy
	light_transition_speed = 1.0 / duration  # Süreye göre hızı ayarla

func end_roll():
	if is_on_floor():
		set_state(State.IDLE)
	else:
		set_state(State.JUMP)

func die():
	set_state(State.DEAD)  # Ölüm durumuna geç
	CameraManager.transition_to_mode(CameraManager.CameraMode.DEAD, 3)
	velocity.x = 0
	isDead = true

func state_hurt(delta):
	# Hasar alma sırasında yavaşla
	velocity.x = lerp(velocity.x, 0.0, delta * 5.0)  # 5.0 yavaşlama hızı
	velocity.y += gravity * delta  # Yerçekimi uygula

func heal(amount: int):
	if isDead:  # Karakter öldüyse iyileştirme yapma
		return
	
	velocity.x=0
	health += amount
	health = min(health, max_health)  # Canı maksimum canı aşmayacak şekilde sınırla
	emit_signal("health_changed", health, max_health)  # Can değişikliğini UI'a bildir
	set_state(State.HEAL)  # HEAL durumuna geç

func _unhandled_input(event):
	if isDead:  # Karakter öldüyse girişleri işleme
		return
	
	if current_state in [State.ATTACK, State.ROLL, State.SLIDE, State.HEAL]:
		return
	
	if event.is_action_pressed("attack"):
		set_state(State.ATTACK)
	elif event.is_action_pressed("action"):
		if abs(velocity.x) < 180 or abs(velocity.y) > 0:
			set_state(State.ROLL)
		else:
			set_state(State.SLIDE)
	elif event.is_action_pressed("heal"):
		heal(10)

func enter_village(village_name: String):
	# Köye girildiğinde sinyali tetikle
	emit_signal("entered_village", village_name)
