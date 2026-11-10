extends SceneTree
## 걷는 스테이지에 PDF 기준으로 추가한 규칙을 검사한다 (오답·경계값 위주, 정상 경로는 autoplay_stages).
## 실행: Godot --headless --path . --script res://scripts/tools/test_stage_rules.gd

var failures := 0
var checks := 0
var s

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL ", message)

func _init() -> void:
	call_deferred("run")

func open(scene: String) -> void:
	s = (load("res://scenes/stages/%s.tscn" % scene) as PackedScene).instantiate()
	root.add_child(s)
	s.hud.dialogue_skip()

func level(n: int) -> void:
	s.start_level(n)
	s.hud.dialogue_skip()

func act(kind: String, index := -1) -> void:
	s.interact(s.spot(kind, index))
	s.refresh()

func play_hints() -> void:
	var guard := 0
	while not s.done and guard < 80:
		guard += 1
		var t = s.next_action()[0]
		if t == null:
			break
		s.interact(t)
		s.refresh()

func run() -> void:
	MiniGameBase.progress_saving = false
	var nm = root.get_node_or_null("NetworkManager")
	if nm:
		nm.auto_send_enabled = false
	test_st01()
	test_st02()
	test_st03()
	test_st04()
	test_st05()
	test_st07()
	test_st08()
	test_st09()
	print("STAGE_RULES_TEST_DONE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func st01_step() -> void:
	var a: Array = s._next_action()
	match a[0]:
		"slot": s._slot(a[1])
		"tray": s._tray()
		"bin": s._bin()
	s._refresh()
	s._check()

func test_st01() -> void:
	open("ST01_Array")
	check(s.LEVELS.size() == s.LEVEL_TALK.size(), "ST01 대사 수")
	s._slot(0)
	check(s.mistakes == 1 and s.reads == [2, 0], "ST01 틀린 인덱스 조회")
	st01_step()
	st01_step()
	s._check()
	check(s.done and s.slots == [10, 20, 30, 40, null], "ST01 조회는 배열을 바꾸지 않음")
	s.start_level(5)
	s.hud.dialogue_skip()
	s._tray()
	s._slot(1)
	check(s.mistakes == 1 and s.hand != null, "ST01 가득 찬 배열 삽입 거부")
	for lv in s.LEVELS.size():
		s.start_level(lv)
		s.hud.dialogue_skip()
		var guard := 0
		while not s.done and guard < 40:
			guard += 1
			st01_step()
		check(s.done and s.mistakes == 0, "ST01 레벨 %d 힌트 경로" % (lv + 1))
	s.free()
	print("ST01 ok")

func test_st02() -> void:
	open("ST02_LinkedList")
	check(s.LEVELS.size() == s.level_talk.size(), "ST02 대사 수")
	act("node", 1)
	check(s.mistakes == 1 and s.read_i == 0, "ST02 순서 어긴 읽기 거부")
	s.free()
	print("ST02 ok")

func test_st03() -> void:
	open("ST03_Stack")
	check(s.LEVELS.size() == s.level_talk.size(), "ST03 대사 수")
	act("desk")
	check(s.mistakes == 1, "ST03 빈 스택 Peek 거부")
	play_hints()
	check(s.done and s.peeked, "ST03 Peek 레벨 완료")
	s.start_level(0)
	s.hud.dialogue_skip()
	act("intake")
	act("tower")
	act("intake")
	act("tower")
	act("desk")
	check(s.stack == ["A", "B"], "ST03 Peek 후 스택 유지")
	s.free()
	print("ST03 ok")

func test_st04() -> void:
	open("ST04_QueueDeque")
	check(s.LEVELS.size() == s.level_talk.size(), "ST04 대사 수")
	level(2)
	check(s.mode == "circular" and s.front_i == 1, "ST04 원형 큐 시작")
	act("arrive")
	act("front")
	check(s.mistakes == 1, "ST04 원형 큐 앞 삽입 거부")
	act("rear")
	check(s._rear_i() == 0, "ST04 rear 순환")
	act("rear")
	check(s.mistakes == 2, "ST04 원형 큐 뒤 빼기 거부")
	s.free()
	print("ST04 ok")

func test_st05() -> void:
	open("ST05_Hash")
	check(s.LEVELS.size() == s.level_talk.size(), "ST05 대사 수")
	level(3)
	play_hints()
	var item = s.buckets[2].filter(func(it): return it[0] == 7)[0]
	check(s.done and item[1] == "귤" and s.count() == 2, "ST05 같은 키 값 갱신")
	level(4)
	act("intake")
	act("bucket", 0)
	check(s.mistakes == 1, "ST05 탐사 칸 오답")
	s.start_level(4)
	s.hud.dialogue_skip()
	play_hints()
	check(s.done and s.mistakes == 0, "ST05 선형 탐사와 없는 키")
	check(s.buckets[0][0][0] == 9 and s.buckets[4][0][0] == 2, "ST05 순환 탐사 위치")
	s.free()
	print("ST05 ok")

func test_st07() -> void:
	open("ST07_Bst")
	check(s.LEVELS.size() == s.level_talk.size(), "ST07 대사 수")
	level(4)
	play_hints()
	check(s.done and s.keys.filter(func(k): return k == 6).size() == 1, "ST07 중복 키 거부")
	s.free()
	print("ST07 ok")

func test_st08() -> void:
	open("ST08_Heap")
	check(s.LEVELS.size() == s.level_talk.size(), "ST08 대사 수")
	act("pad", 2)
	check(s.mistakes == 1, "ST08 틀린 받침대")
	level(5)
	play_hints()
	check(s.done and s.heap == [2, 2] and s.outbox == [4], "ST08 한 원소 추출과 동률")
	s.free()
	print("ST08 ok")

func test_st09() -> void:
	open("ST09_Graph")
	check(s.LEVELS.size() == s.level_talk.size(), "ST09 대사 수")
	level(4)
	check(s.answer == ["A", "B", "C", "D"], "ST09 단절 정점 제외")
	act("house", 4)
	check(s.mistakes == 1, "ST09 도달 불가 정점 거부")
	s.free()
	print("ST09 ok")
