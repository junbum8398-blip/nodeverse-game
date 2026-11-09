extends Control
## Reusable noticeboard guide. Reading is optional; completion requires both checks.
signal closed(completed: bool)

const PAGES := [
	{"title": "환영합니다, NODEVERSE 탐험가!", "body": "이 게시판에서 기본 조작과 학습 방법을 알아보세요.\n\n각 섬은 하나의 학습 주제입니다. NPC에게 설명을 듣고, 직접 실습한 뒤 퀴즈로 확인하면 됩니다.\n\n언제든 닫고 탐험할 수 있고, 게시판에서 E를 누르면 다시 읽을 수 있습니다."},
	{"title": "1. 로봇 움직이기", "body": "W / A / S / D 또는 방향키 : 이동\nSpace : 점프     Shift : 달리기\n우클릭 드래그 : 카메라 회전     휠 : 확대·축소\n\n다리를 따라 섬 사이를 이동하세요. 길을 잃으면 R로 시작 지점에 돌아올 수 있습니다."},
	{"title": "2. 주변과 상호작용하기", "body": "E : 가까운 NPC와 대화하거나 게시판 읽기\n자료구조 섬의 컴퓨터에서 E : 2D 학습 실습 시작\nT : 현재 구역의 퀴즈     Esc : 일시정지 메뉴\n\nNPC에게 가까이 가면 화면 아래에 대화 안내가 나타납니다. 설명을 먼저 읽고 실습해 보세요."},
	{"title": "3. 프로그래밍의 첫걸음", "body": "변수 : 값을 이름에 담아 두는 공간입니다. 예) 점수 = 10\n조건문 : 조건에 따라 행동을 고릅니다. 예) 점수가 10 이상이면 문 열기\n반복문 : 같은 행동을 여러 번 수행합니다. 예) 상자 3개를 차례로 옮기기\n\n입문 섬의 학습 오브젝트를 살펴보며 이 세 가지를 익혀 보세요."},
	{"title": "4. 학습 순서 알아보기", "body": "입문 섬에서 기초를 익히고 자료구조 섬에서 실습해 보세요.\n배열은 순서와 인덱스, 스택은 나중에 넣은 것부터, 큐는 먼저 넣은 것부터 다룹니다.\n\n알고리즘·SQL·데이터 탐험 섬으로 학습을 넓히고 종합 도전 섬에서 마무리하세요. 어려우면 NPC 설명을 다시 확인하세요."},
	{"title": "확인 1. 어떤 조작일까요?", "body": "가까이 있는 NPC에게 말을 걸거나 이 게시판을 읽을 때 누르는 키는 무엇일까요?", "options": ["E — 상호작용", "Space — 점프", "Shift — 달리기"], "answer": 0, "explanation": "맞아요! E는 가까운 대상과 상호작용하는 키입니다."},
	{"title": "확인 2. 반복문 알아보기", "body": "‘상자 3개를 차례로 옮긴다’처럼 같은 행동을 여러 번 실행할 때 사용하는 것은 무엇일까요?", "options": ["변수 — 값 보관", "반복문 — 같은 행동 반복", "조건문 — 조건에 따라 선택"], "answer": 1, "explanation": "맞아요! 반복문은 같은 행동을 정해진 횟수만큼 반복할 때 사용합니다."}
]

var page := 0
var answers: Dictionary = {}
var heading: Label
var body: Label
var progress: Label
var feedback: Label
var choices: VBoxContainer
var previous: Button
var next: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.07, 0.12, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -420
	panel.offset_right = 420
	panel.offset_top = -290
	panel.offset_bottom = 290
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f8f0da")
	style.border_color = Color("417495")
	style.set_border_width_all(4)
	style.set_corner_radius_all(18)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	progress = _label(17)
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(progress)
	var close := Button.new()
	close.text = "닫기 · Esc"
	close.pressed.connect(func(): dismiss(false))
	top.add_child(close)
	heading = _label(28)
	column.add_child(heading)
	body = _label(22)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	choices = VBoxContainer.new()
	choices.add_theme_constant_override("separation", 6)
	column.add_child(choices)
	feedback = _label(18)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.y = 44
	column.add_child(feedback)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 16)
	column.add_child(navigation)
	previous = Button.new()
	previous.text = "이전"
	previous.custom_minimum_size = Vector2(140, 44)
	previous.pressed.connect(go_back)
	navigation.add_child(previous)
	next = Button.new()
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next.pressed.connect(advance)
	navigation.add_child(next)
	hide()

func _label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("243d50"))
	return label

func open() -> void:
	page = 0
	answers.clear()
	show()
	refresh()

func refresh() -> void:
	var item: Dictionary = PAGES[page]
	progress.text = "메인 섬 게시판 · 기본 안내  %d / %d" % [page + 1, PAGES.size()]
	heading.text = item.title
	body.text = item.body
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	feedback.text = item.get("explanation", "") if answers.has(page) else ""
	feedback.add_theme_color_override("font_color", Color("247147"))
	if item.has("options"):
		for i in item.options.size():
			var button := Button.new()
			button.text = item.options[i]
			button.custom_minimum_size.y = 40
			button.add_theme_font_size_override("font_size", 19)
			button.pressed.connect(choose.bind(i))
			choices.add_child(button)
	previous.disabled = page == 0
	next.disabled = item.has("options") and not answers.has(page)
	next.text = "학습 완료" if page == PAGES.size() - 1 else "다음 · E / Enter"

func choose(option: int) -> void:
	var item: Dictionary = PAGES[page]
	if option == item.answer:
		answers[page] = true
		refresh()
	else:
		feedback.text = "다시 생각해 보세요. 앞의 설명을 다시 읽어도 좋습니다."
		feedback.add_theme_color_override("font_color", Color("ab4337"))

func advance() -> void:
	if next.disabled: return
	if page == PAGES.size() - 1:
		dismiss(true)
	else:
		page += 1
		refresh()

func go_back() -> void:
	if page > 0:
		page -= 1
		refresh()

func dismiss(completed: bool) -> void:
	hide()
	closed.emit(completed)

func handle_key(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE: dismiss(false)
			KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_RIGHT: advance()
			KEY_LEFT: go_back()
