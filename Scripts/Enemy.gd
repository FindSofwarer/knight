extends CharacterBody2D

# Durumlar için enum tanımla
enum State { IDLE, RUN, JUMP, ATTACK, HURT, DEAD }

# Düşman türleri için enum tanımla
enum EnemyType { FAST, SLOW, BOSS }

# Inspector'dan ayarlanabilir değişkenler
@export var enemy_type: EnemyType = EnemyType.SLOW  # Inspector'dan seçilebilir

@export_group("Enemy Settings")
@export var fast_speed: float = 200.0
@export var slow_speed: float = 80.0
@export var boss_speed: float = 120.0

@export var fast_health: int = 3
@export var slow_health: int = 5
@export var boss_health: int = 10

@export var fast_damage: int = 1
@export var slow_damage: int = 2
@export var boss_damage: int = 3


@export var attack_range: float = 50.0
@export var gravity: float = 980.0  # Yerçekimi
@export var patrol_range: float = 100.0  # Patrol mesafesi
@export var detection_range: float = 150.0  # Oyuncuyu görme mesafesi

@export var hitArea: Area2D = null
@export var hitColl: CollisionShape2D = null

# Animasyonlar
@export var sprite: AnimatedSprite2D = null
@export var ayri_atak_animasyonlari: bool = false

@export_group("Health Bar")
@export var bar_y: float = -12.0
@export var bar_x: float = -12.0
@export var health_bar: TextureProgressBar = null
var show_health_bar_timer: Timer = null

# Durum Değişkenleri
var current_state: State = State.IDLE
var is_dead: bool = false
var is_attacking: bool = false
var target = null  # Oyuncu veya başka bir hedef
var speed: float = 0.0
var health: int = 0
var damage: int = 0
var patrol_direction: Vector2 = Vector2.RIGHT  # Patrol yönü
var start_position: Vector2  # Patrol başlangıç pozisyonu
var hitColStartPosX: float = 0  # HitColl'ın başlangıç pozisyonu

func _ready():
	# Düşman türüne göre ayarları uygula
	match enemy_type:
		EnemyType.FAST:
			speed = fast_speed
			health = fast_health
			damage = fast_damage
		EnemyType.SLOW:
			speed = slow_speed
			health = slow_health
			damage = slow_damage
		EnemyType.BOSS:
			speed = boss_speed
			health = boss_health
			damage = boss_damage
	
	# Patrol başlangıç pozisyonunu kaydet
	start_position = global_position
	hitColStartPosX = hitColl.position.x
	
	# Timer oluştur ve ayarla
	show_health_bar_timer = Timer.new()
	show_health_bar_timer.wait_time = 2.0  # Can barını 2 saniye göster
	show_health_bar_timer.one_shot = true  # Timer sadece bir kere çalışsın
	show_health_bar_timer.connect("timeout", Callable(self, "_on_show_health_bar_timeout"))
	add_child(show_health_bar_timer)
	
	# Başlangıçta can barını gizle
	health_bar.visible = false
	health_bar.max_value=health
	health_bar.value=health
	
	
	# Hedefi oyuncu olarak ayarla
	target = get_tree().get_nodes_in_group("Player")[0]
	# Başlangıçta Idle animasyonunu oynat
	sprite.play("Idle")

func _physics_process(delta):
	if is_dead:
		return
	
	# Yerçekimi uygula
	velocity.y += gravity * delta
	
	# Düşman türüne göre davranışı belirle
	match enemy_type:
		EnemyType.FAST:
			behavior_all(delta)
		EnemyType.SLOW:
			behavior_all(delta)
		EnemyType.BOSS:
			pass
	
	if health_bar.visible:
		health_bar.global_position = global_position + Vector2(bar_x*scale.x, bar_y*scale.y)  # Düşmanın üzerinde konumlandır
	
	# Hareketi uygula
	move_and_slide()

func behavior_all(delta):
	if is_attacking or current_state == State.HURT:
		return  # Saldırı veya hasar alma sırasında hareket etme    
	if target:
		# Oyuncu görüş mesafesinde mi kontrol et
		if global_position.distance_to(target.global_position) < detection_range:
			# Oyuncuyu takip et
			var direction = (target.global_position - global_position).normalized()
			var distance_to_target = global_position.distance_to(target.global_position)
			
			if distance_to_target > attack_range*scale.x:  # Oyuncuya doğru hareket et
				velocity.x = direction.x * speed
			else:
				# Oyuncuya çok yaklaştı, dur
				velocity.x = 0
			
			update_attack_area_position()
			
			# Oyuncu saldırı menzilindeyse COMBAT moduna geç
			if distance_to_target < detection_range*scale.x*0.8:
				if !CameraManager.active_actors.has(self):
					CameraManager.active_actors.append(self)
					CameraManager.transition_to_mode(CameraManager.CameraMode.COMBAT, 0.5)
			else:
				# Oyuncu saldırı menzilinden çıktıysa DEFAULT moduna geç
				if CameraManager.active_actors.has(self):
					CameraManager.active_actors.erase(self)
					CameraManager.transition_to_mode(CameraManager.CameraMode.DEFAULT, 0.5)
			
			# Yürüme animasyonunu oynat
			if velocity.x != 0:
				sprite.play("Walk")
				sprite.flip_h = velocity.x < 0  # Yönüne göre sprite'ı çevir
			else:
				sprite.play("Idle")
			
			# Saldırı kontrolü
			if distance_to_target <= attack_range*scale.x:
				if !is_attacking and target.health > 0:
					attack()  # Saldırı yap
		else:
			# Patrol davranışı
			patrol(delta)


func patrol(delta):
	if CameraManager.active_actors.has(self):
		CameraManager.active_actors.erase(self)
		CameraManager.transition_to_mode(CameraManager.CameraMode.DEFAULT, 0.5)
	
	velocity.x = patrol_direction.x * speed
	
	# Patrol mesafesini kontrol et
	if global_position.distance_to(start_position) > patrol_range*scale.x:
		patrol_direction *= -1  # Yönü tersine çevir
		start_position = global_position  # Yeni başlangıç pozisyonunu güncelle
	
	# Yürüme animasyonunu oynat
	if velocity.x != 0:
		sprite.play("Walk")
		sprite.flip_h = velocity.x < 0  # Yönüne göre sprite'ı çevir
	else:
		sprite.play("Idle")

func attack():
	if is_attacking:
		return
	
	is_attacking = true  # Saldırı başladı
	set_state(State.ATTACK)
	show_health_bar()  # Can barını göster
	if(!ayri_atak_animasyonlari):
		# Attack1 animasyonunu oynat
		sprite.play("Attack1")
		await sprite.animation_finished  # Attack1 animasyonu bitene kadar bekle
	
		# Eğer hasar alındıysa saldırıyı kes
		if current_state == State.HURT:
			is_attacking = false
			return
	
		# Attack2 animasyonunu oynat
		sprite.play("Attack2")
		if(enemy_type==EnemyType.SLOW):
			CameraManager.add_screen_shake(0.5)  # Attack2 animasyonu sırasında ekran titremesi
		await sprite.animation_finished  # Attack2 animasyonu bitene kadar bekle
	else:
		sprite.play("Attack1" if randf() > 0.5 else "Attack2")
		await sprite.animation_finished  # Attack1 animasyonu bitene kadar bekle
	
	# Eğer hasar alındıysa saldırıyı kes
	if current_state == State.HURT:
		is_attacking = false
		return
	
	# Düşmana hasar ver
	var bodies = hitArea.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("Player"):
			body.take_damage(damage)
	
	is_attacking = false  # Saldırı bitti
	set_state(State.IDLE)  # Saldırı bittiğinde Idle animasyonuna dön
	
	  # Saldırı bittikten sonra tekrar saldırı yapmak için koşulları kontrol et
	if is_player_in_attack_range() and target.health > 0:
		attack()  # Tekrar saldırı yap

func check_player_in_range():
	# Saldırı sırasında oyuncu alandan çıkarsa listeden çıkar
	while is_attacking:
		if !is_player_in_attack_range():
			if CameraManager.active_actors.has(self):
				CameraManager.active_actors.erase(self)
				CameraManager.transition_to_mode(CameraManager.CameraMode.DEFAULT, 0.5)
		await get_tree().process_frame  # Bir frame bekle

func is_player_in_attack_range() -> bool:
	if target:
		return global_position.distance_to(target.global_position) <= attack_range*scale.x
	return false

func take_damage(amount: int):
	if is_dead:
		return
	
	health -= amount
	health_bar.value = health  # Can barını güncelle
	show_health_bar()  # Can barını göster
	
	if health <= 0:
		die()
	else:
		set_state(State.HURT)
		sprite.play("Hurt")
		await sprite.animation_finished
	
		# Hasar alma animasyonu bittikten sonra durumu güncelle
		if is_on_floor():
			set_state(State.IDLE)
		else:
			set_state(State.JUMP)

func update_attack_area_position():
	if sprite.flip_h:  # Sola bakıyorsa
		hitColl.position.x = -hitColStartPosX
	else:  # Sağa bakıyorsa
		hitColl.position.x = hitColStartPosX

func set_state(new_state: State):
	if current_state == new_state:
		return
	
	# Exit current state
	match current_state:
		State.ATTACK:
			is_attacking = false
		State.HURT:
			pass  # Hasar alma durumundan çıkarken yapılacak bir şey yok
	
	# Enter new state
	current_state = new_state
	match new_state:
		State.IDLE:
			sprite.play("Idle")
		State.RUN:
			sprite.play("Run")
		State.JUMP:
			sprite.play("Jump")
		State.ATTACK:
			sprite.play("Attack1")
		State.HURT:
			sprite.play("Hurt")
		State.DEAD:
			sprite.play("Dead")

func die():
	is_dead = true
	health_bar.visible=false
	if CameraManager.active_actors.has(self):
		CameraManager.active_actors.erase(self)
		CameraManager.transition_to_mode(CameraManager.CameraMode.DEFAULT, 0.5)
	if(enemy_type==EnemyType.SLOW):
		CameraManager.add_screen_shake(0.5)  # Attack2 animasyonu sırasında ekran titremesi
	sprite.play("Die")
	await sprite.animation_finished  # Ölüm animasyonu bitene kadar bekle
	queue_free()  # Düşmanı sahneden kaldır,

# Can barını göster
func show_health_bar():
	health_bar.visible = true
	show_health_bar_timer.start()  # Timer'ı başlat

# Timer bittiğinde can barını gizle
func _on_show_health_bar_timeout():
	health_bar.visible = false
