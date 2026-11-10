extends SceneTree
## 실제 체험 경로: 장면의 카드/목적지 Interactable을 통해 19개 의뢰를 해결한다.
var failures = 0
var checks = 0
var g
func check(ok, message):
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ",message)
func _init(): call_deferred("run")
func press(key):
	check(g.work_spots.has(key), "장치 존재 "+key)
	g._on_interact(g.work_spots[key])
func move(kind, id, destination):
	press(kind+":"+str(id))
	press(destination)
func choose(key, field, wanted):
	var guard = 0
	while g.state.work[field] != wanted and guard < 10:
		press(key); guard += 1
	check(g.state.work[field] == wanted,"도구 설정 "+str(wanted))
func solve_query(lv,p):
	var columns = [[['name','dept'],['id','score']],[['name'],['name','score']],[['name','score'],['name'],['name']]][lv][p]
	var outputs = [[[0,1,2,3,4,5],[0,1,2,3,4,5]],[[0,2],[0,2,4,5]],[[0,2],[],[]]][lv][p]
	for c in columns: press("lens:"+c)
	for i in outputs: move("row",i,"put:out")
	for i in 6:
		if not outputs.has(i): move("row",i,"put:reject")
func solve_group(lv,p):
	choose("criterion","criterion","dept")
	var tools = [['COUNT(*)','SUM(amount)'],['COUNT(*)','COUNT(amount)','AVG(amount)'],['SUM(amount)'] if p==0 else ['COUNT(*)']][lv]
	for tool in tools: press("agg:"+tool)
	for i in 7:
		var excluded = lv==2 and (p==1 or i in [2,3])
		move("row",i,"put:reject" if excluded else "basket:"+g.SALES[i][1])
	for key in ['A','B','C','D']:
		if g.members(key).is_empty(): continue
		press("basket:"+key)
		press("put:reject" if lv==2 and key=='D' else "put:out")
func solve_join(lv,p):
	var mode = "INNER" if lv==0 or (lv==2 and p==0) else "LEFT"
	choose("mode","mode",mode)
	var pairs = [[0,1],[1,0]] if lv<2 else ([[0,0],[0,1],[1,2]] if p==0 else [])
	for pair in pairs: move("employee",pair[0],"match:"+str(pair[1]))
	for i in 4:
		if not pairs.any(func(pair): return pair[0]==i): move("employee",i,"put:out" if mode=='LEFT' else "put:reject")
func solve_sub(lv,p):
	var inner = ['AVG','CITY:서울','MAX' if p==0 else 'CITY:제주'][lv]
	choose("function","inner",inner)
	var inputs = [0,1,2] if inner in ['AVG','MAX'] else ([0,2] if inner=='CITY:서울' else [])
	for i in g.inner_sources().size(): move("input",i,"collect" if inputs.has(i) else "ignore")
	press("collect")
	check(g.state.work.token != null,"실제 입력에서 토큰 생성")
	press("token");press("plug")
	choose("operator","op",'>' if lv==0 else ('IN' if inner.begins_with('CITY:') else '='))
	var outputs = [2] if lv==0 or inner=='MAX' else ([0,1,3] if inner=='CITY:서울' else [])
	for i in 4: move("student",i,"put:out" if outputs.has(i) else "put:reject")
func run():
	MiniGameBase.progress_saving=false
	root.get_node("NetworkManager").auto_send_enabled=false
	for scene in ['SQL01_Query','SQL02_GroupBy','SQL03_Join','SQL04_Subquery']:
		g=load('res://scenes/stages/'+scene+'.tscn').instantiate()
		root.add_child(g)
		await process_frame
		for lv in 3:
			g.start_level(lv);g.hud.dialogue_skip()
			check(g.next_action()[0]==null,"정답 화살표 제거")
			var pcount=g.problems().size()
			for p in pcount:
				var original=g.state.work.duplicate(true)
				press('submit')
				check(g.state.phase=='setup' and not g.done,"기본 설정 즉시 완료 방지")
				check(g.state.work==original,"빈 제출은 상태를 바꾸지 않음")
				match scene:
					'SQL01_Query':solve_query(lv,p)
					'SQL02_GroupBy':solve_group(lv,p)
					'SQL03_Join':solve_join(lv,p)
					'SQL04_Subquery':solve_sub(lv,p)
				check(g.work_error()=='',scene+' 정답 경로 '+str(lv)+'/'+str(p)+' '+g.work_error())
				var ready = g.state.work.duplicate(true)
				# 완성 직전의 실제 카드를 잘못 옮긴 뒤, 운반 두 행동을 되돌리면 복구돼야 한다.
				match scene:
					'SQL01_Query':move('row',0,'put:reject' if ready.rows[0]=='out' else 'put:out')
					'SQL02_GroupBy':move('row',0,'put:reject' if ready.rows[0]!='reject' else 'basket:A')
					'SQL03_Join':
						press('mode');press('mode') # 두 번 순환은 복원: 아래에서 잘못된 직원 처리 방식을 선택.
						press('mode')
					'SQL04_Subquery':move('student',0,'put:reject' if ready.rows[0]=='out' else 'put:out')
				check(g.work_error()!='',scene+' 잘못 옮긴 실제 결과 거부')
				g.undo_last()
				if scene!='SQL03_Join':g.undo_last()
				check(g.state.work==ready and g.work_error()=='',scene+' 실제 카드·연결·보고서 복원')
				press('submit')
				check(g.state.phase=='review' and not g.done,"결과 관찰 전 자동 진행 금지")
				check(not g.code_lines.is_empty(),"행동과 SQL 해설 연결")
				g.confirm_review()
			check(g.done,scene+' 레벨 완료 '+str(lv))
		g.free()
	# 물리 접근성, 운반 상태, 잘못된 연결·분류와 되돌리기.
	for scene in ['SQL01_Query','SQL02_GroupBy','SQL03_Join','SQL04_Subquery']:
		g=load('res://scenes/stages/'+scene+'.tscn').instantiate();root.add_child(g)
		g.hud.dialogue_skip()
		for key in g.work_spots:
			var sp=g.work_spots[key]
			if not sp.enabled:continue
			g.player.position=sp.position+Vector2(0,12)
			for n in 3:await physics_frame
			check(g.player.focus==sp,scene+' 접근 가능 '+key)
		if scene=='SQL01_Query':
			press('row:0');var held=g.state.work.hand.duplicate()
			press('row:1');check(g.state.work.hand==held,'들고 있는 카드 교체 방지')
			press('put:reject');check(g.state.work.rows[0]=='reject','실제 분류 상태')
			g.undo_last();check(g.state.work.hand==held and not g.state.work.rows.has(0),'운반·목적지 원자적 되돌리기')
			g.start_level(0);g.hud.dialogue_skip();check(g.state.work.hand.is_empty(),'초기화 후 빈손')
		if scene=='SQL03_Join':
			choose('mode','mode','INNER');move('employee',0,'match:0')
			check(g.work_error()!='','키가 다른 연결 거부')
		if scene=='SQL04_Subquery':
			press('student:0');check(g.state.work.hand.is_empty(),'토큰 전달 전 외부 단계 잠금')
		g.free()
	print('SQL_EXPERIENCE_TEST_DONE checks=%d failures=%d'%[checks,failures])
	quit(1 if failures else 0)
