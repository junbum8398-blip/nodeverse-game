extends SceneTree
## SQL 서랍 게임 화면 캡처 (창 모드).
## 실행: Godot --path . --resolution 1280x720 --script res://scripts/tools/capture_sql_drawer.gd -- <저장 폴더>

const Drawer = preload("res://scripts/minigames/sql_drawer.gd")
var out := ""
var g

func _init() -> void:
	call_deferred("run")

func shot(n: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(n + ".png"))

func open(scene: String, lv: int) -> void:
	g = (load("res://scenes/stages/%s.tscn" % scene) as PackedScene).instantiate()
	g.instant = true
	root.add_child(g)
	g._load_level(lv)
	g.phase = "play"

func paint(t: String, row: int, col: int) -> void:
	g.tool_id = t
	g.r = row
	g.c = col
	g.press_e()

func cond(t: String, row: int, col: int, op: String, val: int) -> void:
	paint(t, row, col)
	var ops: Array = g.COMPARE_OPS if g.palette.mode == "compare" else g.Model.NUMERIC_OPS
	g.palette.op = ops.find(op)
	if g.palette.has("val"):
		g.palette.val = g.WHERE_VALUES.find(val)
	g.confirm_palette()

func finish(name: String) -> void:
	g._place_robot(true)
	await create_timer(0.6).timeout
	await shot(name)
	g.queue_free()
	await process_frame

func run() -> void:
	MiniGameBase.progress_saving = false
	out = OS.get_cmdline_user_args()[0]
	var nm = root.get_node_or_null("NetworkManager")
	if nm:
		nm.auto_send_enabled = false
	Drawer.saved.clear()
	open("SQL01_Query", 1)
	paint("col", 0, 1)
	paint("col", 0, 2)
	cond("cond", 2, 2, ">=", 80)
	await finish("sql1")
	open("SQL02_GroupBy", 1)
	paint("group", 1, 3)
	paint("count", 0, 0)
	paint("countcol", 0, 2)
	paint("avg", 0, 2)
	await finish("sql2")
	open("SQL03_Join", 1)
	paint("key", 0, 2)
	paint("key", 0, 5)
	paint("mode", 0, 2)
	await finish("sql3")
	open("SQL04_Subquery", 1)
	paint("avg", 2, 2)
	cond("compare", 2, 2, ">", 0)
	paint("col", 0, 1)
	paint("col", 2, 2)
	await finish("sql4")
	open("SQL01_Query", 1)
	paint("col", 0, 1)
	g.tool_id = "cond"
	g.r = 2
	g.c = 2
	g.press_e()
	await finish("sql_palette")
	quit()
