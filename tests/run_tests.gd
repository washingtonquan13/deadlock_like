extends SceneTree
## Headless movement test runner (design §12).
##   godot --headless --path <project> -s res://tests/run_tests.gd [-- --filter=T02,T03]
## Loads every res://tests/cases/test_*.gd (each extends MoveTestCase), awaits every method whose
## name starts with "test_", prints PASS/FAIL lines and a summary, and quits with 0 (all pass) or 1.
## --filter takes comma-separated IDs (e.g. T02) matched case-insensitively against method names.

const CASES_DIR := "res://tests/cases"
const TEST_TIMEOUT_MS := 30000

var _passed: int = 0
var _failed: int = 0
var _failed_names: PackedStringArray = PackedStringArray()
var _current_done: bool = false


func _initialize() -> void:
	_run()


func _filters() -> PackedStringArray:
	var out := PackedStringArray()
	var args := OS.get_cmdline_user_args()
	args.append_array(OS.get_cmdline_args())
	for a in args:
		if a.begins_with("--filter="):
			for tok in a.substr(9).split(",", false):
				var t := tok.strip_edges().to_lower()
				if t != "" and not out.has(t):
					out.append(t)
	return out


func _matches(name: String, filters: PackedStringArray) -> bool:
	if filters.is_empty():
		return true
	var n := name.to_lower()
	for f in filters:
		var i := n.find(f)
		while i >= 0:
			var end := i + f.length()
			var before_ok := i == 0 or not _is_alnum(n[i - 1])
			var after_ok := end >= n.length() or not n[end].is_valid_int()
			if before_ok and after_ok:
				return true
			i = n.find(f, i + 1)
	return false


func _is_alnum(c: String) -> bool:
	return c.is_valid_int() or (c >= "a" and c <= "z")


func _case_files() -> PackedStringArray:
	var files := PackedStringArray()
	for f in DirAccess.get_files_at(CASES_DIR):
		var fn := f.trim_suffix(".remap")
		if fn.begins_with("test_") and fn.ends_with(".gd") and not files.has(fn):
			files.append(fn)
	files.sort()
	return files


func _run() -> void:
	# let the main loop start so physics frames are ticking
	await process_frame
	var filters := _filters()
	if not filters.is_empty():
		print("Filter: %s" % ", ".join(filters))
	var t0 := Time.get_ticks_msec()
	for fn in _case_files():
		var path := CASES_DIR.path_join(fn)
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			_report_fail(fn, "could not load or instantiate script (parse error?)")
			continue
		var names := PackedStringArray()
		for m in script.get_script_method_list():
			var mn: String = m["name"]
			if mn.begins_with("test_") and not names.has(mn) and _matches(mn, filters):
				names.append(mn)
		names.sort()
		for mn in names:
			await _run_one(script, mn)
	var ms := Time.get_ticks_msec() - t0
	print("")
	print("==== %d passed, %d failed (%d ms) ====" % [_passed, _failed, ms])
	for n in _failed_names:
		print("  failed: %s" % n)
	quit(0 if _failed == 0 and _passed > 0 else 1)


func _run_one(script: GDScript, method: String) -> void:
	var inst := script.new() as MoveTestCase
	if inst == null:
		_report_fail(method, "script does not extend MoveTestCase")
		return
	inst.tree = self
	await inst.before_each()
	_current_done = false
	_invoke(inst, method)
	var start := Time.get_ticks_msec()
	while not _current_done and Time.get_ticks_msec() - start < TEST_TIMEOUT_MS:
		await process_frame
	var msg := ""
	if not _current_done:
		msg = "timed out or aborted after an await (script error?)"
	elif not inst.failures.is_empty():
		msg = "; ".join(inst.failures)
	elif not inst.completed:
		msg = "did not reach done() (script error?)"
	await inst.after_each()
	if msg == "":
		_passed += 1
		print("PASS %s" % method)
	else:
		_report_fail(method, msg)


func _invoke(inst: MoveTestCase, method: String) -> void:
	await inst.call(method)
	_current_done = true


func _report_fail(name: String, msg: String) -> void:
	_failed += 1
	_failed_names.append(name)
	print("FAIL %s: %s" % [name, msg])
