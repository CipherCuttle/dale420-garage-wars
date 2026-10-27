extends SceneTree

func _init() -> void:
	call_deferred("run")

func save_frame(game: GarageWarsGame, path: String) -> void:
	game.hud.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://evidence/" + path + ".png")
	assert(error == OK)
	print("CAPTURE " + path + ".png")

func run() -> void:
	# These are labeled visual fixtures, separate from the gameplay screenshots.
	var game: GarageWarsGame = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.started = true
	game.hud.visible = false
	game.player.global_position = Vector3(-8, 0.1, 9)
	game.player.rig.rotation = Vector3.ZERO
	var people: Array[Node3D] = [game.player]
	for i in range(4):
		var enemy := game.family[i]
		enemy.reset_at(Vector3(-4 + i * 4, 0.1, 9), false)
		enemy.rig.rotation = Vector3.ZERO
		people.append(enemy)
	for person in people:
		person.rig.animate(0.1, 0, false, "", 0, false, 0)
	GarageGeometry.label(game, Vector3(-8, 3.25, 9), "ERIK / DALE420\nSAME PERSON", Color("dfff89"), 22)
	GarageGeometry.label(game, Vector3(0, 4.5, 9), "GINGER FAMILY • ORIGINAL PROCEDURAL CHARACTER RIGS\nVISUAL FIXTURE / NOT A GAMEPLAY CHECKPOINT", Color("fff1d6"), 22)
	game.camera.global_position = Vector3(0, 3.7, -4)
	game.camera.look_at(Vector3(0, 1.9, 9))
	await save_frame(game, "09_family_visual_fixture")
	game.camera.global_position = Vector3(-8, 2.4, 6.4)
	game.camera.look_at(Vector3(-8, 1.7, 9))
	await save_frame(game, "10_erik_identity_visual_fixture")
	game.player.form.begin_encounter("visual_fixture")
	game.player.form.family_damage(36, "Lotusmicke", 1, true)
	game.player.form.tick(game.config.transformation_intro)
	game.player.rig.animate(0.1, 0, true, "kick", 0.18, false, 0)
	await save_frame(game, "11_dale_stance_visual_fixture")
	for node in game.get_children():
		if node is AudioStreamPlayer:
			node.stop()
	# Let the audio mixer release its playback snapshots before engine teardown.
	await create_timer(0.12).timeout
	game.queue_free()
	await process_frame
	GarageGeometry.materials.clear()
	quit(0)
