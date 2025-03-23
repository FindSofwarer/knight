extends Camera2D

# Kamera Ayarları
@export var edge_padding := Vector2(150, 100)  # Kenar boşlukları
@export var dynamic_zoom_speed := 3.5  # Zoom geçiş hızı
@export var max_rotation := 0.08  # Kamera rotasyonu (radyan cinsinden)
@export var rotation_response := 0.15  # Rotasyon tepkisi
@export var screen_border_margin := 50.0  # Ekran kenarı takip sınırı
@export var bottom_margin := 50
var target_zoom: Vector2 = Vector2.ONE  # Hedef zoom değeri
var transition_speed: float = 1.0  # Geçiş hızı

# Kamera Modları
enum CameraMode { DEFAULT, COMBAT, VILLAGE, CINEMATIC, DEAD }
var current_mode: CameraMode = CameraMode.DEFAULT

# Mod Parametreleri
@export var mode_params = {
	CameraMode.DEFAULT: {"zoom": 2.9, "smoothing": 8.0},  # Normal yakınlık
	CameraMode.COMBAT: {"zoom": 3.1, "smoothing": 12.0},  # Savaşta daha yakın
	CameraMode.VILLAGE: {"zoom": 2.6, "smoothing": 6.0},  # Diyalogda biraz daha uzak
	CameraMode.CINEMATIC: {"zoom": 2.75, "smoothing": 6.0},  # Sinematikte daha geniş bir görünüm
	CameraMode.DEAD: {"zoom": 2.2, "smoothing": 15.0}  # Ölümde en uzak
}

# Aktörler ve Efektler
var active_actors: Array = []  # Kamera tarafından takip edilecek aktörler
var screen_shake_timer: float = 0.0  # Ekran titreşimi süresi
var base_rotation := 0.0  # Temel kamera rotasyonu
var _current_target: Vector2 = Vector2.ZERO  # Geçerli hedef pozisyon
var cinematic_target: Node2D = null  # Sinematik modda odaklanılacak hedef

func _ready():
	# Kamera başlangıç ayarları
	zoom = Vector2(mode_params[CameraMode.DEFAULT]["zoom"], mode_params[CameraMode.DEFAULT]["zoom"])

func _process(delta):
	# Geçersiz aktörleri temizle
	clean_up_active_actors()
	
	# Aktör yoksa işlem yapma
	if active_actors.is_empty() and current_mode != CameraMode.CINEMATIC:
		return
	
	# Pozisyon güncelleme
	var target_position = calculate_smart_position()
	position = lerp(position, target_position, delta * mode_params[current_mode]["smoothing"])
	
	# Zoom güncelleme
	var target_zoom = calculate_smart_zoom()
	zoom = zoom.lerp(target_zoom, delta * transition_speed)
	#Camera Mevcut Pozisyon
	var camera_position = position
	# ParallaxBackground'un Scroll Offset'ini güncelle
		
		
	# Ekran titreşimi
	handle_screen_shake(delta)
	
	# Rotasyon efekti
	apply_velocity_rotation(delta)

func apply_velocity_rotation(delta: float):
	if active_actors.size() > 0 and active_actors[0].has_method("get_velocity"):
		var velocity = active_actors[0].get_velocity()
		var target_rotation = clamp(velocity.x * 0.0003, -max_rotation, max_rotation)  # Daha yumuşak rotasyon
		rotation = lerp(rotation, base_rotation + target_rotation, delta * rotation_response)

func calculate_smart_position() -> Vector2:
	# Sinematik modda ise, cinematic_target'e odaklan
	if current_mode == CameraMode.CINEMATIC and cinematic_target:
		return cinematic_target.global_position
	
	# DEFAULT modda veya tek aktör varsa, direkt aktörün pozisyonunu al
	if current_mode != CameraMode.COMBAT || active_actors.size() == 1:
		var actor_position = active_actors[0].global_position
		# Ekranın altına doğru offset ekle (örneğin, 100 piksel)
		var screen_bottom_offset = Vector2(0, bottom_margin)
		return actor_position - screen_bottom_offset
	
	# COMBAT modunda tüm aktörlerin ortalamasını al
	var avg_pos = get_actors_center()
	
	# Ekran kenarı takip optimizasyonu
	var viewport = get_viewport()
	var bounds = get_actors_bounds()  # bounds değişkenini burada tanımla
	var screen_size = viewport.get_visible_rect().size
	var screen_center = viewport.get_camera_2d().get_screen_center_position()
	var dir_to_edge = (avg_pos - screen_center).normalized()
	var edge_threshold = screen_size * 0.4 / zoom.x  # Zoom seviyesine göre ayarla
	
	# Karakter ekran kenarına yaklaştığında erken tepki
	if abs(avg_pos.x - screen_center.x) > edge_threshold.x || abs(avg_pos.y - screen_center.y) > edge_threshold.y:
		return avg_pos + dir_to_edge * screen_border_margin
	
	# Yeni: Aktörlerin görünürlüğünü garanti altına al
	if current_mode == CameraMode.COMBAT || active_actors.size() > 1:
		var camera_extents = screen_size / (2 * zoom.x)
		var visible_rect = Rect2(avg_pos - camera_extents, camera_extents * 2)
		if !visible_rect.encloses(bounds):
			return bounds.get_center()
	
	# Ekranın altına doğru offset ekle (örneğin, 100 piksel)
	var screen_bottom_offset = Vector2(0, bottom_margin)
	return avg_pos
	
func calculate_smart_zoom() -> Vector2:
	# Sinematik modda ise, sabit zoom kullan
	if current_mode == CameraMode.CINEMATIC:
		return Vector2(mode_params[CameraMode.CINEMATIC]["zoom"], mode_params[CameraMode.CINEMATIC]["zoom"])
	
	if current_mode == CameraMode.VILLAGE:
		return Vector2(mode_params[CameraMode.VILLAGE]["zoom"], mode_params[CameraMode.VILLAGE]["zoom"])
	
	
	# DEFAULT modda veya tek aktör varsa, sabit zoom kullan
	if current_mode != CameraMode.COMBAT || active_actors.size() == 1:
		return Vector2(mode_params[current_mode]["zoom"], mode_params[current_mode]["zoom"])
	
	# COMBAT modunda tüm aktörleri çerçeve içinde tutacak şekilde zoom ayarla
	var bounds = get_actors_bounds()
	var screen_size = get_viewport_rect().size
	
		# Dinamik padding: En büyük aktör boyutunun %50'si
	var max_actor_size = max(bounds.size.x, bounds.size.y)
	var dynamic_padding = Vector2(max_actor_size * 0.5, max_actor_size * 0.5)
	
	# Zoom hesaplama formülü
	var required_width = bounds.size.x + dynamic_padding.x * 2
	var required_height = bounds.size.y + dynamic_padding.y * 2
	
	var zoom_x = screen_size.x / required_width
	var zoom_y = screen_size.y / required_height
	
	# Zoom sınırları (COMBAT modunda mode_params'teki zoom değerini kullan)
	var combat_zoom = mode_params[CameraMode.COMBAT]["zoom"]
	var min_zoom = combat_zoom * 0.5  # Minimum zoom (örneğin, %80'i)
	var max_zoom = combat_zoom * 1.5  # Maksimum zoom (örneğin, %120'si)
	
	var final_zoom = Vector2(
		clamp(min(zoom_x, zoom_y), min_zoom, max_zoom),
		clamp(min(zoom_x, zoom_y), min_zoom, max_zoom)
	)
	
	
	return final_zoom

func get_actors_center() -> Vector2:
	var center = Vector2.ZERO
	for actor in active_actors:
		center += actor.global_position
	return center / active_actors.size()

func get_actors_bounds() -> Rect2:
	var bounds = Rect2()
	for actor in active_actors:
		# Aktörün gerçek boyutlarını al (CollisionShape2D veya Sprite2D üzerinden)
		var actor_size = Vector2.ZERO
		if actor.has_node("CollisionShape2D"):
			var shape = actor.get_node("CollisionShape2D").shape
			actor_size = shape.extents * 2
		elif actor.has_node("Sprite2D"):
			var sprite = actor.get_node("Sprite2D")
			actor_size = sprite.get_rect().size * sprite.scale
		
		# Pozisyonu merkez olarak alıp boyutları ekleyerek genişlet
		var actor_rect = Rect2(actor.global_position - actor_size/2, actor_size)
		if bounds == Rect2():
			bounds = actor_rect
		else:
			bounds = bounds.merge(actor_rect)
	
	return bounds

func clean_up_active_actors():
	active_actors = active_actors.filter(func(a): 
		return is_instance_valid(a) && a.is_inside_tree()
	)

func handle_screen_shake(delta):
	if screen_shake_timer > 0:
		screen_shake_timer -= delta
		var intensity = screen_shake_timer * 15.0
		offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
	else:
		offset = Vector2.ZERO

func transition_to_mode(mode: CameraMode, duration: float = 1.0):
	current_mode = mode
	# Hedef zoom değerini ayarla
	target_zoom = Vector2(mode_params[current_mode]["zoom"], mode_params[current_mode]["zoom"])
	# Geçiş hızını ayarla (duration'a göre)
	transition_speed = 1.0 / duration  # Süreye göre hızı ayarla

func add_screen_shake(duration: float = 0.3):
	screen_shake_timer = duration

func set_active_actors(actors: Array):
	active_actors = actors
	if current_mode != CameraMode.COMBAT:
		active_actors = [actors[0]]  # DEFAULT modda sadece ana karakter

func clear_active_actors():
	active_actors = []

# Sinematik modu başlat
func start_cinematic_mode(target: CharacterBody2D, duration: float = 1.0):
	cinematic_target = target
	transition_to_mode(CameraMode.CINEMATIC, duration)	

# Sinematik modu bitir
func stop_cinematic_mode(duration: float = 1.0):
	cinematic_target = null
	transition_to_mode(CameraMode.DEFAULT, duration)
