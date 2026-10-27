extends Control

var game: GarageWarsGame
var font: Font = ThemeDB.fallback_font
var bold: FontVariation
const INK := Color("18272a")
const CREAM := Color("f6eed8")
const LIME := Color("daff68")
const ORANGE := Color("ffbe67")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bold = FontVariation.new()
	bold.base_font = font
	bold.variation_embolden = 1.0

func text(at: Vector2, words: String, size: int = 18, color: Color = CREAM, heavy: bool = false) -> void:
	draw_string(bold if heavy else font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func paragraph(at: Vector2, words: String, width: float, size: int = 16, color: Color = CREAM) -> float:
	var line := ""
	var y := at.y
	for word in words.split(" "):
		if font.get_string_size(line + word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			text(Vector2(at.x, y), line, size, color)
			y += size * 1.45
			line = ""
		line += word + " "
	text(Vector2(at.x, y), line, size, color)
	return y

func panel(rect: Rect2, accent: Color = LIME) -> void:
	draw_rect(Rect2(rect.position + Vector2(5, 5), rect.size), Color(0.03, 0.05, 0.05, 0.4))
	draw_rect(rect, Color(0.065, 0.11, 0.12, 0.94))
	draw_rect(Rect2(rect.position, Vector2(4, rect.size.y)), accent)

func bar(rect: Rect2, fraction: float, color: Color) -> void:
	draw_rect(rect.grow(2), INK)
	draw_rect(rect, Color("3b4644"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(fraction, 0, 1), rect.size.y)), color)

func _draw() -> void:
	if game == null or game.player == null:
		return
	var canvas := get_viewport_rect().size
	draw_set_transform(Vector2.ZERO, 0, Vector2(canvas.x / 1280, canvas.y / 720))
	var player := game.player
	var powered := player.form.is_dale()
	panel(Rect2(18, 6, 252, 102), LIME)
	panel(Rect2(933, 7, 326, 131), LIME)
	text(Vector2(28, 27), "MACK & MAYHEM PRESENTS", 11, LIME, true)
	text(Vector2(26, 72), "DALE420", 43, CREAM, true)
	text(Vector2(28, 94), "GARAGE WARS / M A C K E B Y", 12, Color("d9d8bf"))
	var mode := "DALE420" if powered else "ERIK"
	text(Vector2(945, 32), mode + " / HP", 16, LIME if powered else CREAM, true)
	text(Vector2(1151, 32), "%03d / 100" % ceili(player.hp), 15, CREAM, true)
	bar(Rect2(945, 43, 303, 17), player.hp / game.config.max_hp, LIME)
	var status := "FAMILJEPRESS"
	var fraction := player.form.meter / game.config.fury_threshold
	var color := ORANGE
	match player.form.mode:
		AwakeningState.Mode.AWAKENING:
			status = "DALE420 VAKNAR!"
			fraction = 1.0
			color = LIME
		AwakeningState.Mode.DALE420:
			status = "KUNG FU • %.1f S" % player.form.remaining
			fraction = player.form.remaining / game.config.transformation_seconds
			color = LIME
		AwakeningState.Mode.RECOVERY:
			status = "ERIK • ÅTERHÄMTNING %.0f S" % player.form.remaining
			fraction = player.form.remaining / game.config.recovery_seconds
			color = Color("88bcc6")
		_:
			if player.form.encounter_spent:
				status = "ERIK • VÄNTA TILL NÄSTA KONFRONTATION"
	text(Vector2(945, 83), status, 12, color, true)
	bar(Rect2(945, 93, 303, 9), fraction, color)
	text(Vector2(945, 126), "JOINTS %d  /  LUFTGEVÄR %s  /  BEVIS %s" % [player.inventory.joints, "JA" if player.inventory.air_rifle else "—", "JA" if player.inventory.crumb_evidence else "—"], 11, CREAM)
	panel(Rect2(26, 145, 342, 222))
	text(Vector2(44, 169), "DALE420 — THE AWAKENING", 12, LIME, true)
	var objective := game.objective()
	var title_y := paragraph(Vector2(44, 199), objective.title, 302, 21, CREAM)
	paragraph(Vector2(44, title_y + 29), objective.detail, 300, 14, Color("ced4c5"))
	var destination: Vector3 = objective.target
	var distance := player.global_position.distance_to(destination)
	text(Vector2(45, 352), "%02d / 10  •  %.0f M TILL MÅL" % [game.mission + 1, distance], 11, ORANGE, true)
	if game.mission == game.Mission.BOSS:
		panel(Rect2(444, 24, 392, 70), ORANGE)
		text(Vector2(461, 47), "LOTUSMICKE / MACKOR & MAKT", 15, ORANGE, true)
		bar(Rect2(461, 61, 350, 13), game.family[3].hp / game.family[3].max_hp, Color("f4775f"))
		text(Vector2(462, 87), "%d / %d" % [ceili(game.family[3].hp), game.family[3].max_hp], 10, CREAM)
	elif powered:
		panel(Rect2(482, 26, 306, 68), LIME)
		text(Vector2(501, 52), "DALE420 • KUNG FU-GUD*", 20, LIME, true)
		text(Vector2(501, 76), "*enligt Erik. Samma kropp. Mer attityd.", 12, CREAM)
	panel(Rect2(18, 616, 405, 98), LIME)
	text(Vector2(28, 638), "WASD GÅ/KÖR  •  SHIFT SPRING  •  ← → KAMERA", 11, CREAM)
	text(Vector2(28, 658), "J KOMBO   K SPARK   MELLANSLAG UNDVIK/KONTRA", 11, CREAM)
	text(Vector2(28, 678), "E INTERAGERA   Q JOINT +HP   T LUFTGEVÄR   F BIL", 11, CREAM)
	var place := "SMULSKOGEN" if player.global_position.x < -22 and player.global_position.z < 3 else "LOTUSGÅRDEN" if player.global_position.x > 8 and player.global_position.z < 5 else "VILLAGATAN"
	text(Vector2(28, 711), place, 20, LIME, true)
	_minimap(player.global_position, destination)
	var hint := game.hint()
	if not hint.is_empty():
		var width := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 40
		panel(Rect2(640 - width * 0.5, 476, width, 43), LIME)
		text(Vector2(660 - width * 0.5, 504), hint, 15, LIME, true)
	if game.speech_clock > 0:
		panel(Rect2(430, 564, 605, 105), ORANGE)
		text(Vector2(448, 589), game.speaker, 13, ORANGE, true)
		paragraph(Vector2(448, 615), game.speech, 564, 16)
	if game.flash.a > 0:
		draw_rect(Rect2(0, 0, 1280, 720), game.flash)
	if player.form.mode == AwakeningState.Mode.AWAKENING:
		draw_rect(Rect2(0, 278, 1280, 148), Color(0.04, 0.09, 0.06, 0.9))
		text(Vector2(313, 339), "ERIK → DALE420", 59, LIME, true)
		text(Vector2(394, 386), "EN KROPP. ETT HELT ORIMLIGT EGO.", 20, CREAM, true)
	if not game.started:
		_intro()
	elif game.dead:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.025, 0.06, 0.065, 0.94))
		text(Vector2(325, 285), "FIKAPAUS", 93, ORANGE, true)
		text(Vector2(353, 340), "Erik behöver en omstart. DALE420 med.", 24, CREAM)
		text(Vector2(362, 395), "R / ENTER  →  " + game.checkpoint_name, 23, LIME, true)
		text(Vector2(352, 438), "Samma spelare. Sparat HP/förråd. Ny familjekonfrontation.", 16, CREAM)

func _intro() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.03, 0.075, 0.08, 0.92))
	draw_rect(Rect2(54, 66, 8, 576), LIME)
	text(Vector2(88, 106), "EN SVENSK FÖRORTSKOMEDI / SPELBAR GODOT-VERSION", 14, LIME, true)
	text(Vector2(82, 221), "DALE420", 108, CREAM, true)
	text(Vector2(88, 282), "THE AWAKENING", 42, LIME, true)
	paragraph(Vector2(90, 337), "Erik. 25 år. Arbetslös. Bor hemma. Rödhårig, spinkig och på familjens sista nerv. När de trycker för hårt vaknar hans helt orimliga kung fu-alter ego.", 715, 22)
	paragraph(Vector2(90, 447), "En spelare. Samma HP och förråd. DALE420 slåss som en gud — tills timern går ut och Erik måste ta sig till sitt gömställe i skogen.", 715, 18, Color("d3dac9"))
	panel(Rect2(90, 542, 480, 66), LIME)
	text(Vector2(116, 585), "ENTER  →  STARTA FAMILJERÅDET", 23, LIME, true)
	text(Vector2(90, 647), "WASD rörelse • Mellanslag undvik • J/K strid • E interagera • Q läk • T skjut • F kör", 15, CREAM)
	text(Vector2(90, 677), "Originalfigurer & originalgeometri. Allt familjekaos är tecknad slapstick.", 12, Color("9baea2"))

func _minimap(center: Vector3, destination: Vector3) -> void:
	var rect := Rect2(1055, 493, 193, 220)
	panel(rect, Color("8eb5a3"))
	draw_rect(Rect2(1063, 501, 176, 176), Color("3e5746"))
	var origin := Vector2(1151, 589)
	var map_point := func(pos: Vector3) -> Vector2:
		var offset := Vector2(pos.x - center.x, pos.z - center.z) * 0.85
		return origin + offset.clamp(Vector2(-80, -80), Vector2(80, 80))
	var road_h: Vector2 = map_point.call(Vector3(center.x, 0, 9))
	var road_v: Vector2 = map_point.call(Vector3(-7, 0, center.z))
	draw_rect(Rect2(1066, road_h.y - 4, 169, 8), Color("7e8982"))
	draw_rect(Rect2(road_v.x - 4, 505, 8, 168), Color("7e8982"))
	for obstacle in game.world.obstacles:
		var point: Vector2 = map_point.call(Vector3(obstacle.get_center().x, 0, obstacle.get_center().y))
		draw_rect(Rect2(point - Vector2(4, 4), Vector2(8, 8)), Color("bfaf91"))
	for enemy in game.family:
		if enemy.active and enemy.alive:
			draw_circle(map_point.call(enemy.global_position), 3.4, Color("ee826f"))
	draw_circle(map_point.call(game.car.global_position), 4, ORANGE)
	draw_circle(map_point.call(destination), 5, LIME)
	draw_circle(origin, 4, CREAM)
	draw_line(origin, origin + Vector2(-sin(game.player.rig.rotation.y), -cos(game.player.rig.rotation.y)) * 12, CREAM, 2)
	text(Vector2(1070, 705), "MACKEBY / N ↑", 11, Color("b6c6b5"), true)
