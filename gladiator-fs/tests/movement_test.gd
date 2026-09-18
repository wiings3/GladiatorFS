extends SceneTree
## Stress camera tracking at 30 physics ticks / 144 rendered frames per second.
var game
class Recorder extends Node:
 var game
 var values = []
 var time = 0.0
 func _process(delta):
  time += delta
  if game.running and time > 0.6:
   var actor = game.actors[1]
   var rendered = actor.get_global_transform_interpolated().origin if ProjectSettings.get_setting("physics/common/physics_interpolation", false) else actor.global_position
   values.append((game.camera.global_transform.affine_inverse() * rendered).x)
func _initialize():
 Engine.physics_ticks_per_second = 30
 Engine.max_fps = 144
 call_deferred("run")
func _physics_process(_delta):
 if is_instance_valid(game) and game.running:
  game.apply_input(1, Vector2(1, 0), 0, false, false)
 return false
func run():
 game = load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 game.test_no_input = true
 game.start_session(false,"Jitter test",1)
 var record = Recorder.new()
 record.game = game
 record.process_priority = 1000
 root.add_child(record)
 var failed = false
 for view in [{"first": false, "zoom": 5.2}, {"first": false, "zoom": 2.0}, {"first": false, "zoom": 9.0}, {"first": true, "zoom": 5.2}]:
  game.first_person = view.first
  game.third_person_zoom = view.zoom
  game.camera_distance = view.zoom
  game.actors[1].position = Vector3(-6, 0.05, 7)
  game.actors[1].move_velocity = Vector3.ZERO
  game.actors[1].velocity = Vector3.ZERO
  game.actors[1].reset_physics_interpolation()
  record.values.clear()
  record.time = 0
  await create_timer(1.8).timeout
  var lo = 999.0
  var hi = -999.0
  for x in record.values:
   lo = minf(lo,x)
   hi = maxf(hi,x)
  print("STRAFE CAMERA: ", "FIRST PERSON" if view.first else "THIRD PERSON / " + str(view.zoom), "  X RANGE: ", hi-lo, " m / ", record.values.size(), " rendered samples")
  failed = failed or record.values.size() < 30 or hi - lo >= 0.001
 game.leave_session()
 game.queue_free()
 record.queue_free()
 await process_frame
 quit(1 if failed else 0)
