extends RefCounted
## SQL 5x5 서랍 게임의 표와 레벨. 화면 코드와 분리한다.

const STUDENTS := {"name": "students", "cols": ["id", "name", "score", "dept", "city"],
	"rows": [[1, "민지", 90, "개발", "서울"], [2, "준호", 55, "디자인", "부산"], [3, "서연", 80, "개발", "서울"], [4, "도윤", null, "디자인", "서울"], [5, "하늘", 70, "기획", "대전"]]}
const STUDENTS_J := {"name": "students", "cols": ["id", "name", "dept_id", "score", "city"],
	"rows": [[1, "민지", 10, 90, "서울"], [2, "준호", 20, 55, "부산"], [3, "서연", 10, 80, "서울"], [4, "도윤", 99, null, "서울"], [5, "하늘", null, 70, "대전"]]}
const DEPTS := {"name": "depts", "cols": ["id", "name", "city", "floor", "active"],
	"rows": [[10, "개발", "서울", 1, 1], [20, "디자인", "부산", 2, 1], [30, "기획", "대전", 3, 1], [40, "운영", "서울", 4, 1], [50, "연구", "부산", 5, 1]]}
const PROJECTS := {"name": "projects", "cols": ["id", "name", "dept_id", "weeks", "active"],
	"rows": [[1, "앱", 10, 4, 1], [2, "웹", 10, 6, 1], [3, "포스터", 20, 2, 1], [4, "기획서", 30, 3, 1], [5, "백업", 40, 1, 0]]}

const GAMES := {
	"query": {"id": "SQL01", "title": "필요한 칸만 꺼내기", "bg": "sql01", "levels": [
		{"mission": "모든 학생의 이름과 점수를 뽑아 주세요", "tools": {"1": "col", "3": "erase"},
		 "target": {"select": ["name", "score"]},
		 "hints": ["의뢰에 나온 정보가 어느 열에 들어 있는지 찾아 보세요.", "열 붓은 열 하나를 통째로 고르는 도구예요. SELECT에 차례로 들어가요."]},
		{"mission": "80점 이상 학생의 이름과 점수를 뽑아 주세요", "tools": {"1": "col", "2": "cond", "3": "erase"},
		 "target": {"select": ["name", "score"], "cond": {"col": "score", "op": ">=", "val": 80}},
		 "hints": ["점수 열의 숫자를 위에서 아래로 읽어 보세요. NULL은 비교되지 않아요.", "조건 붓은 규칙 하나를 전체 행에 똑같이 적용해요. WHERE가 되는 도구예요."]},
		{"mission": "60점 이상 학생 중 1등 한 명의 이름과 점수를 뽑아 주세요", "tools": {"1": "col", "2": "cond", "3": "erase", "4": "order", "5": "limit"},
		 "target": {"select": ["name", "score"], "cond": {"col": "score", "op": ">=", "val": 60}, "order": {"col": "score", "dir": "DESC"}, "limit": 1},
		 "hints": ["1등은 점수를 어떤 순서로 세웠을 때 맨 위에 올까요?", "먼저 줄을 세운 다음에 위에서 몇 명만 가져올지 정해요."]},
	]},
	"group": {"id": "SQL02", "title": "같은 값은 같은 색으로", "bg": "sql02", "levels": [
		{"mission": "부서별 학생 수를 세어 주세요", "tools": {"1": "group", "2": "count", "3": "erase"},
		 "target": {"group": "dept", "aggs": [{"fn": "COUNT", "col": "*"}]},
		 "hints": ["같은 값끼리 묶고 싶은 열이 어디인지 보세요.", "그룹 붓으로 묶은 뒤, 묶음마다 몇 행인지 세는 도구를 써요."]},
		{"mission": "부서별 전체 인원, 점수가 있는 인원, 평균 점수를 비교해 주세요", "tools": {"1": "group", "2": "count", "3": "erase", "4": "countcol", "5": "avg"},
		 "target": {"group": "dept", "aggs": [{"fn": "COUNT", "col": "*"}, {"fn": "COUNT", "col": "score"}, {"fn": "AVG", "col": "score"}]},
		 "hints": ["디자인 부서의 점수 칸을 보세요. 비어 있는 값이 있어요.", "COUNT(*)는 행을, COUNT(score)는 값이 있는 칸을 세요. 평균도 NULL을 빼고 계산해요."]},
		{"mission": "평균 점수가 80점 이상인 부서만 남겨 주세요", "tools": {"1": "group", "2": "count", "3": "erase", "4": "countcol", "5": "avg", "6": "having"},
		 "target": {"group": "dept", "aggs": [{"fn": "AVG", "col": "score"}], "having": {"agg": "AVG(score)", "op": ">=", "val": 80}},
		 "hints": ["평균은 묶은 다음에야 나오는 값이에요.", "요약 서랍에 조건 붓을 쓰면 묶은 뒤의 조건, HAVING이 돼요."]},
	]},
	"join": {"id": "SQL03", "title": "번호가 같은 서랍끼리 연결", "bg": "sql03", "levels": [
		{"mission": "소속 부서를 찾은 학생에게 부서 이름을 붙여 주세요", "tools": {"1": "key", "2": "mode", "3": "erase"}, "right": "DEPTS",
		 "target": {"lk": "dept_id", "rk": "id", "join": "INNER"},
		 "hints": ["두 표에서 같은 뜻의 번호가 들어 있는 열을 찾아 보세요.", "키 붓을 왼쪽 열, 오른쪽 열에 차례로 쓰면 ON이 완성돼요."]},
		{"mission": "부서를 못 찾은 학생도 빠지지 않게 명단을 만들어 주세요", "tools": {"1": "key", "2": "mode", "3": "erase"}, "right": "DEPTS",
		 "target": {"lk": "dept_id", "rk": "id", "join": "LEFT"},
		 "hints": ["99와 NULL을 가진 학생은 짝이 없어요.", "왼쪽 표를 모두 남기는 처리 방식이 LEFT JOIN이에요."]},
		{"mission": "학생별 담당 프로젝트를 모두 찾아 주세요", "tools": {"1": "key", "2": "mode", "3": "erase"}, "right": "PROJECTS",
		 "target": {"lk": "dept_id", "rk": "dept_id", "join": "INNER"},
		 "hints": ["오른쪽 표에서 부서 번호가 들어 있는 열은 id가 아니에요.", "한 키에 여러 행이 맞으면 결과도 그만큼 늘어나요."]},
	]},
	"sub": {"id": "SQL04", "title": "계산한 값으로 다시 칠하기", "bg": "sql04", "levels": [
		{"mission": "학생들의 평균 점수를 구해 주세요", "tools": {"1": "avg", "3": "erase"},
		 "target": {"inner": {"fn": "AVG", "col": "score"}},
		 "hints": ["평균을 낼 숫자가 들어 있는 열을 찾아 보세요.", "NULL은 평균을 낼 때 빠져요. 아래 계산 띠를 보세요."]},
		{"mission": "평균 점수를 넘은 학생의 이름과 점수를 찾아 주세요", "tools": {"1": "avg", "2": "compare", "3": "erase", "4": "col"},
		 "target": {"inner": {"fn": "AVG", "col": "score"}, "outer_op": ">", "outer_col": "score", "select": ["name", "score"]},
		 "hints": ["먼저 평균을 알아야 비교할 수 있어요.", "계산으로 만든 토큰을 비교 붓에 연결하면 안쪽 SELECT가 WHERE 안으로 들어가요."]},
		{"mission": "최고 점수를 받은 학생의 이름과 점수를 찾아 주세요", "tools": {"1": "max", "2": "compare", "3": "erase", "4": "col"},
		 "target": {"inner": {"fn": "MAX", "col": "score"}, "outer_op": "=", "outer_col": "score", "select": ["name", "score"]},
		 "hints": ["가장 큰 값을 먼저 계산해 보세요.", "최댓값과 같은 사람을 찾으려면 어떤 비교가 필요할까요?"]},
	]},
}

const TOOL_INFO := {
	"col": ["열 붓", "tool_blue_brush"], "cond": ["조건 붓", "tool_gold_brush"], "erase": ["지우개", "tool_eraser"],
	"order": ["정렬", ""], "limit": ["개수", ""],
	"group": ["그룹 붓", "tool_group_brush"], "count": ["전체 건수", "tool_count"], "countcol": ["값 있는 수", "tool_sum"], "avg": ["평균", ""], "having": ["조건 붓", "tool_gold_brush"],
	"key": ["키 붓", "tool_key_brush"], "mode": ["처리 방식", "tool_funnel"],
	"max": ["최댓값", ""], "compare": ["비교 붓", "tool_green_brush"],
}
