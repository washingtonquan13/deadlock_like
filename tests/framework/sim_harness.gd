class_name SimHarness
extends RefCounted
## Headless harness around the pure MovementSim (design §12).
## Usage:
##   var h := SimHarness.create(tree, &"flat")
##   ArenaBuilder.add_box(h.root, ...)        # optional extra geometry, before ready()
##   await h.ready()                          # two physics frames so the space holds the bodies
##   h.spawn(Vector3.ZERO, 0.0)               # optional; ready() spawns at the layout spawn
##   h.run(64, func(t: int) -> InputCmd: return InputCmd.create(t, 0, 0, 1, 0.0, 0.0))
## Never instances PlayerCharacter, LocalController or DEBUG scenes, never reads the Input singleton.

var tree: SceneTree
var root: Node3D
var cp: CompiledMoveParams
var sim: MovementSim
var state: MoveState
## One entry per simulate(): { tick, pos, vel, loco, stamina, events, grounded, hspeed }.
var trace: Array[Dictionary] = []
## Layout info from ArenaBuilder.build: { spawn, markers }.
var info: Dictionary = {}
## design §13 common setup: push a combat_interaction op every tick so sprint never starts.
var suppress_sprint: bool = true
var _freed: bool = false


static func create(p_tree: SceneTree, layout: StringName = &"flat", params: MovementParams = null, hero: HeroMovementStats = null) -> SimHarness:
	var h := SimHarness.new()
	h.tree = p_tree
	h.root = Node3D.new()
	h.root.name = "SimHarnessRoot"
	p_tree.root.add_child(h.root)
	h.info = ArenaBuilder.build(h.root, layout)
	h.cp = CompiledMoveParams.build(params if params != null else MovementParams.new(), hero if hero != null else HeroMovementStats.new())
	h.sim = MovementSim.new(h.cp, h.root.get_world_3d())
	return h


## Waits two physics frames so freshly built static bodies are in the space, then gathers
## ziplines and ropes under the root and spawns a state at the layout spawn.
func ready() -> void:
	await tree.physics_frame
	await tree.physics_frame
	refresh_world_features()
	if state == null:
		spawn(info.get("spawn", Vector3.ZERO), 0.0)


## Rebuilds the sim's rail lists from Zipline / ClimbRope nodes under the harness root.
func refresh_world_features() -> void:
	var zips: Array[ZiplineRail] = []
	var ropes: Array[RopeRail] = []
	_collect(root, zips, ropes)
	sim.set_world_features(zips, ropes)


func _collect(n: Node, zips: Array[ZiplineRail], ropes: Array[RopeRail]) -> void:
	for c in n.get_children():
		if c is Zipline:
			zips.append((c as Zipline).to_rail(zips.size()))
		elif c is ClimbRope:
			ropes.append((c as ClimbRope).to_rail(ropes.size()))
		_collect(c, zips, ropes)


## Fresh state at `pos` (feet) facing `yaw`; clears the trace.
func spawn(pos: Vector3, yaw: float = 0.0) -> MoveState:
	state = sim.new_state(pos, yaw)
	trace.clear()
	return state


## Runs `ticks` simulate() calls. cmd_fn(tick) -> InputCmd, where tick is the tick being
## produced (state.tick + 1). A null return means a neutral cmd at the current yaw.
func run(ticks: int, cmd_fn: Callable) -> void:
	for i in ticks:
		var t := state.tick + 1
		var cmd: InputCmd = cmd_fn.call(t) if cmd_fn.is_valid() else null
		if cmd == null:
			cmd = InputCmd.create(t, 0, 0, 0, state.yaw, 0.0)
		cmd.tick = t
		step(cmd)


## One simulate() with the harness conventions (sprint suppression, trace recording).
func step(cmd: InputCmd) -> void:
	if suppress_sprint:
		sim.push_external(state, {"op": &"combat_interaction"})
	sim.simulate(state, cmd)
	trace.append({
		"tick": state.tick,
		"pos": state.position,
		"vel": state.velocity,
		"loco": state.loco,
		"stamina": state.stamina,
		"events": state.events.duplicate(true),
		"grounded": state.grounded,
		"hspeed": state.horizontal_speed(),
	})


func free_all() -> void:
	if _freed:
		return
	_freed = true
	if sim != null:
		sim.dispose()
	if root != null and is_instance_valid(root):
		if root.get_parent() != null:
			root.get_parent().remove_child(root)
		root.free()
	root = null
