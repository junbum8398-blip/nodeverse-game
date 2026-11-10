extends RefCounted
## 미니게임 메뉴 목록. 실행 ID(ST01, DS09, ALG01 ...)는 저장 기록과 연결되어 있으니 바꾸지 말 것.
## 기획 ID(DS-01 ...)는 PDF 명세의 식별자다.

static var selected_category := "DS"
const CATEGORIES := {"DS": "자료구조", "ALGO": "알고리즘", "SQL": "SQL", "DATA": "데이터 탐색"}

# [실행 ID, 제목, 주제, 분야, 씬, 설명, 배경 폴더, 기획 ID]
const GAMES := [
	["ST01", "순서가 있는 보관소", "배열", "DS", "ST01_Array", "인덱스 조회와 삽입·삭제", "ST01", "DS-01"],
	["ST02", "끊어진 운송로", "연결 리스트", "DS", "ST02_LinkedList", "노드와 포인터 연결", "ST02", "DS-02"],
	["ST03", "최근 작업 복구실", "스택", "DS", "ST03_Stack", "LIFO · Push / Pop / Peek", "ST03", "DS-03"],
	["ST04", "접수 순서 안내소", "큐 / 덱", "DS", "ST04_QueueDeque", "FIFO · 원형 큐 · 양쪽 끝 연산", "ST04", "DS-04"],
	["ST05", "이름으로 찾는 물품대장", "해시 테이블", "DS", "ST05_Hash", "체이닝과 선형 탐사", "ST05", "DS-05"],
	["DS09", "가지 잇는 나무", "트리 구조", "DS", "DS09_TreeStructure", "부모·자식·루트·리프 연결", "ST06", "DS-06"],
	["ST07", "갈림길 창고", "이진 탐색 트리", "DS", "ST07_Bst", "BST의 탐색·삽입 규칙", "ST07", "DS-07"],
	["ST08", "긴급 작업 배정실", "힙 · 우선순위 큐", "DS", "ST08_Heap", "최소 힙의 삽입·꺼내기", "ST08", "DS-08"],
	["DS10", "연결망 건설소", "그래프 구조", "DS", "DS10_GraphBuild", "정점·간선·방향·가중치", "ST09", "DS-09"],
	["ST10", "학습 지원 센터", "보너스 · 자료구조 종합", "DS", "ST10_Integrated", "상황에 맞는 자료구조 선택", "ST10", "보너스"],
	["ALG02", "물건 찾기 비교실", "선형·이진 탐색", "ALGO", "ALG02_Search", "구간·중앙값·없는 값", "ALG02", "AL-01"],
	["ALG01", "순서 맞춤 작업대", "기본 정렬", "ALGO", "ALG01_Sorting", "버블·선택·삽입 정렬", "ALG01", "AL-02"],
	["ALG03", "나누고 합치는 공방", "분할 정복 정렬", "ALGO", "ALG03_DivideSort", "병합 정렬과 퀵 정렬", "ALG03", "AL-03"],
	["ST06", "계층형 자료실", "트리 순회", "ALGO", "ST06_BinaryTree", "전위·중위·후위·레벨 순회", "ST06", "AL-04"],
	["ST09", "연결망 조사실", "BFS / DFS", "ALGO", "ST09_Graph", "큐와 스택으로 그래프 탐색", "ST09", "AL-05"],
	["ALG04", "최소 비용 배달소", "최단 경로", "ALGO", "ALG04_ShortestPath", "다익스트라와 경로 복원", "ALG04", "AL-06"],
	["SQL01", "필요한 칸만 꺼내기", "열·조건 색칠", "SQL", "SQL01_Query", "SELECT · WHERE · ORDER BY · LIMIT", "SQL01", "SQ-01"],
	["SQL02", "같은 값은 같은 색으로", "그룹 색칠 · 집계", "SQL", "SQL02_GroupBy", "GROUP BY · HAVING · 집계 함수", "SQL02", "SQ-02"],
	["SQL03", "번호가 같은 서랍끼리 연결", "키 색 연결", "SQL", "SQL03_Join", "INNER JOIN과 LEFT JOIN", "SQL03", "SQ-03"],
	["SQL04", "계산한 값으로 다시 칠하기", "서브쿼리", "SQL", "SQL04_Subquery", "평균·최댓값 토큰으로 조건 만들기", "SQL04", "SQ-04"],
	["DATA02", "관측 준비실", "데이터 점검", "DATA", "DATA02_Profile", "행·열·자료형·결측 비율", "DATA02", "DA-01"],
	["DATA01", "기록 수리 공방", "데이터 정제", "DATA", "DATA01_Explore", "결측·중복·형식 정리", "DATA01", "DA-02"],
	["DATA03", "대표값 실험실", "통계 비교", "DATA", "DATA03_Stats", "평균·중앙값·범위와 이상치", "DATA03", "DA-03"],
	["DATA04", "차트 관측소", "시각화 해석", "DATA", "DATA04_Chart", "막대·선·산점도와 결론", "DATA04", "DA-04"],
]

static func games_for(category: String) -> Array:
	return GAMES.filter(func(game): return game[3] == category)
