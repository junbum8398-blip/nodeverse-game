extends MiniGameBase
## ST10 통합 - 학습 지원 센터
## 접수된 요청에 가장 알맞은 자료구조 장치를 제한 시간 안에 고른다. 목숨 3개, 연속 정답 보너스.

const DEVICES := ["스택", "큐", "맵", "집합", "힙", "트리", "그래프", "배열"]
const DCOL := {"스택": "c8843f", "큐": "4caf50", "맵": "3d7bd9", "집합": "8a5cc4", "힙": "e05252", "트리": "2e8b57", "그래프": "2bb3a8", "배열": "e8a33d"}
const POOL := [
	["접수 순서대로 민원을 처리해 주세요", "큐", "먼저 온 요청을 먼저 처리 (FIFO)"],
	["방금 한 수정을 취소(Ctrl+Z)하고 싶어요", "스택", "가장 최근 작업을 먼저 되돌림 (LIFO)"],
	["학생 ID로 성적을 바로 조회해 주세요", "맵", "키(ID) → 값 을 빠르게 찾음"],
	["이미 신청한 사람인지 중복을 확인해 주세요", "집합", "중복 없는 원소 모음, 포함 여부 검사"],
	["가장 긴급한 요청부터 처리해 주세요", "힙", "최솟값/최댓값을 빠르게 꺼냄"],
	["폴더 안의 폴더 구조를 보여 주세요", "트리", "부모-자식 계층 구조"],
	["두 건물 사이 최단 경로를 찾아 주세요", "그래프", "정점과 간선, BFS 로 최단 경로"],
	["7번째 사물함 내용을 바로 열어 주세요", "배열", "인덱스로 즉시 접근"],
	["웹 브라우저 뒤로 가기 기록", "스택", "마지막 방문 페이지부터 되돌아감"],
	["프린터 대기 문서 순서 관리", "큐", "들어온 순서대로 인쇄"],
	["단어 → 뜻 사전 만들기", "맵", "단어를 키로 뜻을 저장"],
	["오늘 방문한 서로 다른 손님 수 세기", "집합", "같은 손님은 한 번만"],
	["응급실 환자를 위급도 순으로 호출", "힙", "우선순위 큐"],
	["회사 조직도 표현", "트리", "상하 계층"],
	["친구의 친구 추천", "그래프", "연결 관계 탐색"],
	["1월~12월 월별 판매량 저장", "배열", "고정 순서, 인덱스 접근"],
	["정렬된 상태로 넣고 빠르게 찾기 (이진 탐색 트리)", "트리", "BST: 왼쪽 작고 오른쪽 큼"],
	["작업 예약을 마감 시간 빠른 순으로 꺼내기", "힙", "가장 이른 마감부터"],
	["지하철 노선도 환승 경로", "그래프", "역=정점, 구간=간선"],
	["괄호 짝이 맞는지 검사", "스택", "여는 괄호를 쌓고 닫을 때 꺼냄"],
]
const PER := 10.0

var order: Array = []
var qi := 0
var lives := 3
var score := 0
var combo := 0
var timer := PER
var log_lines: Array = []
var feedback := ""

func _init() -> void:
	stage_id = "ST10"
	stage_title = "학습 지원 센터"
	level_count = 2

func setup_level(n: int) -> void:
	var idx := range(POOL.size())
	idx.shuffle()
	order = idx.slice(0, 8 if n == 0 else 12)
	qi = 0
	lives = 3
	score = 0
	combo = 0
	timer = PER if n == 0 else 7.0
	log_lines = []
	feedback = ""
	goal = "요청에 맞는 장치를 선택하세요 (%d문제, 제한 %d초)" % [order.size(), int(timer)]

func get_state() -> Dictionary:
	return {}

func info_lines() -> Array:
	return [["문제", "%d / %d" % [min(qi + 1, order.size()), order.size()]], ["점수", score], ["연속", combo], ["목숨", "♥".repeat(lives) + "♡".repeat(3 - lives)]]

func controls_text() -> String:
	return "장치 클릭 또는 숫자 1~8 · R 다시 시작 · Esc 메뉴"

func _process(delta: float) -> void:
	super(delta)
	if level_done or qi >= order.size():
		return
	timer -= delta
	if timer <= 0:
		_answer("")

func on_key(ev: InputEventKey) -> bool:
	if ev.keycode >= KEY_1 and ev.keycode <= KEY_8:
		on_button(DEVICES[ev.keycode - KEY_1])
		return true
	return false

func on_button(id) -> void:
	if id in DEVICES:
		_answer(id)

func _answer(choice: String) -> void:
	var q = POOL[order[qi]]
	if choice == q[1]:
		combo += 1
		var gain := 100 + int(timer * 10) + (combo - 1) * 20
		score += gain
		good("정답! %s — %s (+%d)" % [q[1], q[2], gain], q[1])
		log_lines.append([qi + 1, q[1], true])
	else:
		combo = 0
		lives -= 1
		wrong(("시간 초과! " if choice == "" else "") + "정답은 %s — %s" % [q[1], q[2]], choice)
		log_lines.append([qi + 1, q[1], false])
	qi += 1
	timer = PER if level == 0 else 7.0
	if lives <= 0:
		start_level(level)
		say("목숨을 모두 잃어 처음부터 다시 시작합니다!", C_RED, 4.0)
		return
	if qi >= order.size():
		win("최종 점수 %d점!" % score)

func draw_game() -> void:
	# 요청 카드
	pbox(Rect2(200, 110, 660, 150), C_PANEL, C_INK)
	text("접수 요청", Vector2(224, 146), 18, C_PANEL_DARK)
	if qi < order.size() and not level_done:
		var q = POOL[order[qi]]
		text_c("“" + q[0] + "”", Vector2(530, 200), 26, C_INK)
		var w := 600.0 * clampf(timer / (PER if level == 0 else 7.0), 0, 1)
		draw_rect(Rect2(230, 226, 600, 16), C_INK)
		draw_rect(Rect2(234, 230, w - 8 if w > 8 else 0, 8), C_GREEN if timer > 3 else C_RED)
	# 장치 버튼 (2줄)
	for i in DEVICES.size():
		var d: String = DEVICES[i]
		var r := Rect2(120 + (i % 4) * 210, 300 + (i / 4) * 130, 190, 110)
		var col := Color(DCOL[d])
		if flashing(d):
			col = C_GREEN if (not log_lines.is_empty() and log_lines.back()[1] == d) else C_RED
		button(r, "%d  %s" % [i + 1, d], d, not level_done and qi < order.size(), 26, col)
	# 접수 기록
	pbox(Rect2(120, 570, 820, 60), C_PANEL_DARK, C_INK)
	text("접수 기록", Vector2(136, 608), 16, C_WHITE)
	var x := 230.0
	for l in log_lines.slice(max(0, log_lines.size() - 9)):
		label_box(Rect2(x, 578, 76, 44), "%s" % l[1], C_GREEN if l[2] else C_RED, C_WHITE, 16)
		x += 80
	robot(Vector2(1000, 560), "ID%d" % (qi + 1) if qi < order.size() else "")
