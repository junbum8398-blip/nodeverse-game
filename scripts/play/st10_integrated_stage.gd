extends WalkStage
## ST10 통합 - 학습 지원 센터
## 접수된 요청에 가장 알맞은 자료구조 장치로 시간 안에 달려가 E 를 누른다. 목숨 3개, 연속 정답 보너스.

const DEVICES := ["스택", "큐", "맵", "집합", "힙", "트리", "그래프", "배열"]
const SNIPPET := {
	"스택": ["Stack<T> s = new Stack<>();", "s.push(x);  x = s.pop();"],
	"큐": ["Queue<T> q = new ArrayDeque<>();", "q.add(x);  x = q.poll();"],
	"맵": ["Map<K, V> m = new HashMap<>();", "m.put(k, v);  v = m.get(k);"],
	"집합": ["Set<T> s = new HashSet<>();", "s.add(x);  s.contains(x);"],
	"힙": ["PriorityQueue<T> h = new PriorityQueue<>();", "h.add(x);  x = h.poll();"],
	"트리": ["class Node { Node left, right; }", "go(n.left);  go(n.right);"],
	"그래프": ["List<List<Integer>> adj;", "for (int v : adj.get(u)) { ... }"],
	"배열": ["int[] a = new int[12];", "a[7] = x;  x = a[7];"],
}
const POOL := [
	["접수 순서대로 민원을 처리해 주세요", "큐", "먼저 온 요청을 먼저 처리 (FIFO)"],
	["방금 한 수정을 취소하고 싶어요", "스택", "가장 최근 작업을 먼저 되돌림 (LIFO)"],
	["학생 ID로 성적을 바로 조회해 주세요", "맵", "키(ID) → 값을 빠르게 찾음"],
	["이미 신청한 사람인지 중복을 확인해 주세요", "집합", "중복 없는 원소 모음, 포함 여부 검사"],
	["가장 긴급한 요청부터 처리해 주세요", "힙", "최솟값/최댓값을 빠르게 꺼냄"],
	["폴더 안의 폴더 구조를 보여 주세요", "트리", "부모-자식 계층 구조"],
	["두 건물 사이 최단 경로를 찾아 주세요", "그래프", "정점과 간선, BFS로 최단 경로"],
	["7번째 사물함 내용을 바로 열어 주세요", "배열", "인덱스로 즉시 접근"],
	["웹 브라우저 뒤로 가기 기록", "스택", "마지막 방문 페이지부터 되돌아감"],
	["프린터 대기 문서 순서 관리", "큐", "들어온 순서대로 인쇄"],
	["단어 → 뜻 사전 만들기", "맵", "단어를 키로 뜻을 저장"],
	["오늘 방문한 서로 다른 손님 수 세기", "집합", "같은 손님은 한 번만"],
	["응급실 환자를 위급도 순으로 호출", "힙", "우선순위 큐"],
	["회사 조직도 표현", "트리", "상하 계층"],
	["친구의 친구 추천", "그래프", "연결 관계 탐색"],
	["1월~12월 월별 판매량 저장", "배열", "고정 순서, 인덱스 접근"],
	["작업 예약을 마감 빠른 순으로 꺼내기", "힙", "가장 이른 마감부터"],
	["지하철 노선도 환승 경로", "그래프", "역=정점, 구간=간선"],
	["괄호 짝이 맞는지 검사", "스택", "여는 괄호를 쌓고 닫을 때 꺼냄"],
]
const TIME := [14.0, 10.0]

var order: Array = []
var qi := 0
var lives := 3
var score := 0
var combo := 0
var timer := 14.0
var limit := 14.0
var card: PanelContainer
var card_text: Label
var bar: ColorRect

func _init() -> void:
	stage_id = "ST10"
	stage_title = "학습 지원 센터"
	npc_name = "학습 지원 안내원"
	npc_portrait = preload("res://textures/npc_portraits/NPC00_portrait.png")
	level_count = 2
	hint_after_mistake = true
	code_keywords += ["class", "Node", "Stack", "Queue", "Map", "Set", "List", "HashMap", "HashSet", "ArrayDeque", "PriorityQueue"]
	intro = [
		"드디어 여기까지 왔네요! 저는 학습 지원 센터 안내원이에요. 지금까지 배운 자료구조가 이 광장에 전부 모여 있답니다.",
		"광장 곳곳의 장치가 보이죠? 스택, 맵, 힙, 트리, 큐, 집합, 그래프, 그리고 아래쪽의 배열까지요.",
		"화면 위에 요청이 올라오면, 그 일에 가장 알맞은 자료구조가 무엇인지 떠올리고 그 장치로 달려가세요. 시간 제한이 있어요!",
		"먼저 온 순서는 큐, 최근 것부터는 스택, 이름으로 찾기는 맵, 중복 확인은 집합, 급한 것부터는 힙, 계층은 트리, 연결은 그래프, 번호로 바로 찾기는 배열이에요.",
		"조작법! WASD로 달려서 장치 앞에서 E를 누르세요. 틀리거나 시간이 지나면 목숨이 줄어요. 연속으로 맞히면 보너스 점수가 붙고, 틀리면 다음 문제에서 화살표가 도와줄 거예요.",
	]
	level_talk = [
		"연습 삼아 8개의 요청부터 해결해 볼까요? 문제당 14초예요. 천천히, 하지만 빠르게요!",
		"이번엔 진짜예요. 요청 12개, 문제당 10초! 장치 위치를 떠올리면서 달리세요.",
	]

func build_stage() -> void:
	hud.toast_y = 148.0
	hud.toast_center_x = 484.0
	var root: Control = hud.get_child(0)
	card = StageHUD.panel(Color("f6e7c8", 0.97), 6)
	card.position = Vector2(150, 76)
	card.custom_minimum_size = Vector2(660, 0)
	var v := VBoxContainer.new()
	card_text = StageHUD.label("", 21, StageHUD.INK)
	card_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(card_text)
	var track := ColorRect.new()
	track.color = StageHUD.INK
	track.custom_minimum_size = Vector2(640, 10)
	bar = ColorRect.new()
	bar.color = StageHUD.GREEN
	bar.size = Vector2(640, 10)
	track.add_child(bar)
	v.add_child(track)
	card.add_child(v)
	root.add_child(card)
	root.move_child(card, 1)
	var want := {}
	for i in 5:
		want["a%d" % i] = {"text": str(i), "pos": mark("Arr%d" % i), "scale": 0.42}
	sync_items(want)

func setup_level(n: int) -> void:
	var idx := range(POOL.size())
	idx.shuffle()
	order = idx.slice(0, 8 if n == 0 else 12)
	qi = 0
	lives = 3
	score = 0
	combo = 0
	limit = TIME[n]
	timer = limit
	goal_text = "요청에 맞는 장치로 달려가기 (%d문제)" % order.size()

## 재시작 때 start_level 이 물건을 지우므로 배열 장치의 상자를 다시 만든다
func rebuild() -> void:
	var want := {}
	for i in 5:
		want["a%d" % i] = {"text": str(i), "pos": mark("Arr%d" % i), "scale": 0.42}
	sync_items(want)
	_show_card()

func _show_card() -> void:
	if qi < order.size():
		card_text.text = "요청 %d: “%s”" % [qi + 1, POOL[order[qi]][0]]

func _process(delta: float) -> void:
	if done or hud.dialogue_open() or qi >= order.size():
		return
	timer -= delta
	bar.size.x = 640.0 * clampf(timer / limit, 0.0, 1.0)
	bar.color = StageHUD.GREEN if timer > 3.0 else StageHUD.RED
	if timer <= 0.0:
		_answer("")
		refresh()

func info_rows() -> Array:
	return [["문제", "%d / %d" % [mini(qi + 1, order.size()), order.size()]], ["점수", score], ["연속", combo], ["목숨", "♥".repeat(lives) + "♡".repeat(3 - lives)]]

func state_text() -> String:
	return "score = %s\ncombo = %s" % [num(score), num(combo)]

func prompt(t: Interactable) -> String:
	return "%s 장치 선택" % DEVICES[t.index]

func interact(t: Interactable) -> void:
	if qi < order.size():
		_answer(DEVICES[t.index])

func _answer(choice: String) -> void:
	var q = POOL[order[qi]]
	if choice == q[1]:
		combo += 1
		var gain := 100 + int(timer * 10) + (combo - 1) * 20
		score += gain
		good("정답! %s: %s (+%d)" % [q[1], q[2], gain])
		code("// 요청 %d: %s" % [qi + 1, q[1]])
		for c in SNIPPET[q[1]]:
			code(c)
	else:
		combo = 0
		lives -= 1
		wrong(("시간 초과! " if choice == "" else "") + "정답은 %s: %s" % [q[1], q[2]])
		code("// 요청 %d: 정답은 %s" % [qi + 1, q[1]])
	qi += 1
	timer = limit
	bar.size.x = 640.0
	if lives <= 0:
		hud.toast("목숨을 모두 잃어 처음부터 다시 시작합니다!", StageHUD.RED, 3.5)
		start_level(level)
		return
	if qi >= order.size():
		card_text.text = "모든 요청 처리 완료!"
		win("최종 점수 %d점\n실수 %d회" % [score, 3 - lives])
	else:
		_show_card()

func undo_last() -> void:
	pass   # 시간제 문제에서는 되돌리기 없음

func next_action() -> Array:
	if qi >= order.size():
		return [null, ""]
	var d: String = POOL[order[qi]][1]
	return [spot("device", DEVICES.find(d)), "%s 장치로" % d]
