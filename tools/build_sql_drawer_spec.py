"""SQL 5x5 drawer-coloring specification and separate concept-only ZIP."""
from pathlib import Path
import json, sqlite3, zipfile, shutil
from PIL import Image
from pypdf import PdfReader
from build_minigame_spec import Book, ROOT, W, H, BODY, HEAD, SMALL

OUT=ROOT/'output/sql_drawer_5x5_v2'
ART=ROOT/'reference/sql_drawer_5x5_v2'
OUT.mkdir(parents=True,exist_ok=True)
ROWS=[(1,'민지',90,'개발','서울'),(2,'준호',55,'디자인','부산'),(3,'서연',80,'개발','서울'),(4,'도윤',None,'디자인','서울'),(5,'하늘',70,'기획','대전')]
JOIN_ROWS=[(1,'민지',10,90,'서울'),(2,'준호',20,55,'부산'),(3,'서연',10,80,'서울'),(4,'도윤',99,None,'서울'),(5,'하늘',None,70,'대전')]
DEPTS=[(10,'개발','서울',1,1),(20,'디자인','부산',2,1),(30,'기획','대전',3,1),(40,'운영','서울',4,1),(50,'연구','부산',5,1)]
PROJECTS=[(10,'앱','가',100,1),(10,'웹','나',200,1),(20,'디자인','다',100,1),(30,'독서','라',50,1),(40,'테스트','마',80,1)]
CASES=[
('SQL01-L1','query','SELECT name, score FROM students', [('민지',90),('준호',55),('서연',80),('도윤',None),('하늘',70)]),
('SQL01-L2','query','SELECT name, score FROM students WHERE score >= 80',[('민지',90),('서연',80)]),
('SQL01-L3','query','SELECT name, score FROM students WHERE score >= 60 ORDER BY score DESC, id ASC LIMIT 1',[('민지',90)]),
('SQL02-L1','query','SELECT dept, COUNT(*) FROM students GROUP BY dept',[('개발',2),('기획',1),('디자인',2)]),
('SQL02-L2','query','SELECT dept, COUNT(*), COUNT(score), AVG(score) FROM students GROUP BY dept',[('개발',2,2,85.0),('기획',1,1,70.0),('디자인',2,1,55.0)]),
('SQL02-L3','query','SELECT dept, AVG(score) FROM students GROUP BY dept HAVING AVG(score) >= 80',[('개발',85.0)]),
('SQL03-L1','join','SELECT s.name, d.name FROM students s INNER JOIN depts d ON s.dept_id = d.id',[('민지','개발'),('준호','디자인'),('서연','개발')]),
('SQL03-L2','join','SELECT s.name, d.name FROM students s LEFT JOIN depts d ON s.dept_id = d.id',[('민지','개발'),('준호','디자인'),('서연','개발'),('도윤',None),('하늘',None)]),
('SQL03-L3','join','SELECT s.name, p.project FROM students s JOIN projects p ON s.dept_id = p.dept_id',[('민지','앱'),('민지','웹'),('준호','디자인'),('서연','앱'),('서연','웹')]),
('SQL04-L1','query','SELECT AVG(score) FROM students',[(73.75,)]),
('SQL04-L2','query','SELECT name, score FROM students WHERE score > (SELECT AVG(score) FROM students)',[('민지',90),('서연',80)]),
('SQL04-L3','query','SELECT name, score FROM students WHERE score = (SELECT MAX(score) FROM students)',[('민지',90)])]

def verify():
    result=[]
    for id,mode,sql,expected in CASES:
        db=sqlite3.connect(':memory:')
        if mode=='join':
            db.execute('CREATE TABLE students(id,name,dept_id,score,city)');db.executemany('INSERT INTO students VALUES(?,?,?,?,?)',JOIN_ROWS)
            db.execute('CREATE TABLE depts(id,name,city,floor,active)');db.executemany('INSERT INTO depts VALUES(?,?,?,?,?)',DEPTS)
            db.execute('CREATE TABLE projects(dept_id,project,owner,budget,active)');db.executemany('INSERT INTO projects VALUES(?,?,?,?,?)',PROJECTS)
        else:
            db.execute('CREATE TABLE students(id,name,score,dept,city)');db.executemany('INSERT INTO students VALUES(?,?,?,?,?)',ROWS)
        got=db.execute(sql).fetchall()
        # Group/Join output order is not graded unless ORDER BY is explicitly part of the mission.
        assert (got==expected if 'ORDER BY' in sql else sorted(map(repr,got))==sorted(map(repr,expected))),(id,got,expected)
        result.append({'id':id,'sql':sql,'expected':expected,'actual':got,'passed':True});db.close()
    return result

PAGES=[
('01 / REVISED DIRECTION','5×5 서랍 색칠 SQL','작은 로봇 · 짧은 조작 · 오른쪽 실시간 코드',[
('이번에 바꾸는 중심','10×10은 5×5로 줄인다. 서랍 덮개 25칸 위를 작은 로봇이 한 칸씩 움직이고 붓을 톡 찍는다. 작업한 내용은 오른쪽 SQL과 결과 미리보기에 즉시 반영된다. 25칸을 모두 칠하거나 카드를 운반하는 반복 작업은 요구하지 않는다.'),
('네 게임','SQL01: 열 선택·조건 색칠·추출. SQL02: 같은 값끼리 색 묶기·집계. SQL03: 두 서랍장의 같은 키 색 연결. SQL04: 칠한 열에서 계산한 값으로 다시 조건 색칠. 네 게임이 같은 이동·붓·코드 화면을 공유한다.'),
('게임과 문서의 상태','이 문서는 새 방향의 기획·디자인 제안 v2.0이다. 직전 카드 운반 방식과 10×10 시안을 대체한다. 기존 전체 기획서에서는 SQL 4종 부분만 이 문서로 교체한다. 이번 작업은 명세와 시안 제작이며 실행 코드는 아직 이 방식으로 바꾸지 않았다.'),
('피로를 줄이는 기준','의뢰는 한 문장, 화면에는 5행·5열만 표시한다. 붓 한 번은 한 SQL 연산으로 연결한다. 짧은 문제는 3~6번의 의미 있는 조작, 30~90초를 목표로 하되 플레이테스트로 조정한다. 정답 경로 화살표와 매번 행 수를 맞히는 필수 퀴즈는 두지 않는다.')]),
('02 / PLAY & SCREEN','한 칸씩 톡, 코드가 바로','이동은 가볍게, 실제 데이터 범위는 정확하게',[
('기본 흐름','의뢰 읽기 → WASD/방향키로 로봇 이동 → 붓 고르기 → E로 현재 셀·열에 적용 → 색 범위와 SQL 변화 확인 → Enter로 의뢰 결과 제출. 이동만으로 데이터가 바뀌지 않으며 원본 값은 수정하지 않는다.'),
('로봇과 입력','로봇은 한 칸의 약 절반 크기이며 격자 중심으로 이동한다. 이동 0.12~0.18초, 작은 점프·착지·붓 터치로 반응한다. 키를 누르고 있어도 E 적용은 최초 입력 한 번만 처리한다. 1·2는 현재 단계의 붓 전환, 3은 지우개, Z는 한 동작 취소, X는 문제 초기화다. Enter는 완성된 질의의 제출이다.'),
('색칠 단위','열 붓은 현재 열 전체를 SELECT 범위로 칠한다. 조건 붓은 현재 필드의 비교 기준을 정한 뒤 조건에 맞는 모든 행을 한 번에 칠한다. 로봇의 짧은 연출이 범위를 따라가더라도 학습자에게 같은 규칙을 행마다 반복 적용하게 하지 않는다. 색칠은 테이블을 읽는 표시이며 값 변경이 아니다.'),
('화면 배분','1280×720 기준 왼쪽 약 860px는 서랍장·로봇·짧은 의뢰, 오른쪽 약 380px는 LIVE SQL과 결과표다. 기본 서랍 덮개는 약 80~92px 정사각형, 행·열 제목은 25칸 바깥에 둔다. JOIN만 5×5 두 개를 나란히 두거나 Tab으로 전환한다. 숫자·NULL·열 이름은 로봇과 겹치면 작은 값 툴팁으로 다시 보여준다.'),
('색과 접근성','조회는 열=파랑, 조건 행=금색, 교집합 추출=초록. 집계는 그룹별 색·무늬·이름을 함께 사용한다. 선택 테두리, 조건 통과 아이콘, NULL 사선 무늬를 제공해 색만으로 판정하지 않는다. 원본은 지우개로 삭제되지 않는다.')]),
('03 / DATA & PAINT','5행이 계속 익숙해지게','추가 데이터보다 한 표의 다른 해석을 먼저 배운다',[
('기본 표','조회·집계·서브쿼리는 같은 students(id,name,score,dept,city) 5행을 사용한다. 시안은 영어 별칭 MIN/JUN/SEO/DO/HA와 DEV/ART/PLAN을 사용하지만 실제 UI는 민지/준호/서연/도윤/하늘과 개발/디자인/기획으로 표시한다.'),
('마스크의 뜻','열 마스크 C와 조건 행 마스크 R을 독립 보관한다. 최종 추출 셀은 R×C다. 파란 열과 금색 행의 교집합만 초록으로 강조한다. 데이터 값과 행 ID는 색칠로 바뀌지 않는다. ORDER BY는 통과 행의 순서만, LIMIT은 정렬 이후 결과 개수만 바꾼다.'),
('조건은 붓에 담긴 규칙','점수 셀에서 조건 붓을 선택하면 비교 기호와 숫자를 정하는 작은 팔레트가 열린다. 예: ≥ 와 80. 부서 셀에서는 해당 값 도장을 사용할 수 있다. SQL 문장 선택지를 고르지 않는다. 규칙이 정해지면 전체 표에 같은 규칙을 적용해 칠하고 실제 WHERE를 생성한다.'),
('임의 색칠과 SQL의 경계','사용자가 아무 행이나 자유 색칠한 것을 score >= 80 같은 조건이라고 자동 추측하지 않는다. 자유 낙서는 연습용 시각 표시로만 취급한다. 제출 가능한 질의는 열·비교·그룹·키 등 명시적인 붓 연산에서 만들어져야 하며, 오른쪽 SQL의 실제 실행 결과와 화면의 선택 범위가 일치해야 한다.')]),
('SQL01 / EXTRACT','필요한 칸만 꺼내기','열 선택 → 조건 행 색칠 → 교집합 추출',[
('목표와 조작','의뢰: 80점 이상 학생의 이름과 점수를 뽑아 주세요. 이름 열에 로봇을 놓고 열 붓 E, 점수 열에서도 E를 눌러 출력 순서를 name,score로 정한다. 점수 셀에서 조건 붓으로 ≥80을 적용하면 민지·서연 행이 금색, 두 행의 이름·점수 칸이 초록이 된다.'),
('오른쪽에 바로 보이는 변화','이름 열 적용 → SELECT name. 점수 열 적용 → SELECT name, score. 조건 적용 → WHERE score >= 80. 오른쪽 결과표는 민지 90, 서연 80을 즉시 보여준다. 바뀐 SQL 줄만 0.4초 강조하고 로봇은 현재 칸에서 짧게 붓질한다.'),
('3단계','1: 모든 학생의 이름·점수 두 열 선택. 2: 점수 ≥80 조건 색칠. 3: 점수 ≥60에서 내림차순·상위 1명 선택. 3단계 결과는 민지 90이다. AND/OR 조건 붓은 기본 3단계 이후 선택 도전으로 둬 처음부터 도구를 늘리지 않는다.'),
('판정과 피드백','선택 열과 열 순서, 조건 연산, 실제 결과를 검사한다. 필요한 열이 없으면 열 제목에만 작은 물음표를 표시하고 정답 열을 자동 선택하지 않는다. NULL 점수는 수치 비교 통과 행에 포함되지 않는다. 없는 열, 빈 선택, 정렬 전에 LIMIT을 적용하는 오류를 차단한다.'),
('중요 제약','서랍 하나는 값 하나이며 하나의 행이 학생 한 명이다. 이름 칸과 다른 학생의 점수 칸을 임의로 짝지어 결과 행을 만들 수 없다. 초록은 행과 열의 교집합에서 자동 계산하고 직접 정답 셀을 하나씩 찍게 하지 않는다.')]),
('SQL02 / GROUP','같은 값은 같은 색으로','한 번 묶고, 숫자가 달라지는 이유 보기',[
('목표와 조작','의뢰: 부서별 학생 수를 세어 주세요. 로봇이 부서 열에 가서 그룹 붓을 한 번 찍으면 같은 부서인 행들이 같은 색·무늬로 묶인다. 개발은 1·3행, 디자인은 2·4행, 기획은 5행이다. 그룹 색은 의미 없는 식별자이므로 다른 색 조합도 허용한다.'),
('계산 도구','그룹이 생기면 아래 3개 작은 요약 서랍에 개발 2, 디자인 2, 기획 1이 표시된다. COUNT 도구는 전체 행 수, 점수 열의 값수 도구는 COUNT(score), 평균 도구는 AVG(score)에 대응한다. 다섯 행을 바구니에 일일이 옮기지 않는다.'),
('3단계','1: GROUP BY dept와 COUNT(*). 2: COUNT(*)·COUNT(score)·AVG(score)를 비교한다. 개발 2/2/85, 디자인 2/1/55, 기획 1/1/70이다. 3: 평균 ≥80인 그룹만 요약 서랍에 조건 붓 적용 → 개발 85만 남는다.'),
('즉시 SQL','그룹 붓은 GROUP BY dept를, 전체 건수 도구는 COUNT(*)를, 평균 도구는 AVG(score)를 추가한다. 요약 서랍에 적용한 조건은 HAVING AVG(score) >= 80이 된다. 원본 행 조건은 WHERE, 집계 후 요약 조건은 HAVING으로 별도 표시한다.'),
('판정과 경계','같은 키의 행이 한 그룹인지, 사용한 집계와 실제 값이 맞는지 검사한다. NULL도 COUNT(*)에는 한 행이지만 COUNT(score)와 AVG(score)의 분모에서는 제외한다. SELECT에는 그룹 열과 집계식만 허용한다. HAVING으로 숨겨진 그룹은 지워지지 않고 흐리게 남는다.')]),
('SQL03 / JOIN','번호가 같은 서랍끼리 연결','두 개의 작은 5×5 · 키는 색 선으로 보이게',[
('별도 5열 표','이 게임의 왼쪽 students는 id,name,dept_id,score,city다. 부서 키는 민지10·준호20·서연10·도윤99·하늘NULL. 오른쪽 depts는 id,name,city,floor,active이며 10개발·20디자인·30기획·40운영·50연구의 5행이다. 다른 게임의 dept 이름 열 대신 dept_id를 보여주는 별도 데이터셋이다.'),
('목표와 조작','로봇을 왼쪽 dept_id 열에 놓고 키 붓 E, 오른쪽 id 열에서 E를 누르면 같은 키가 연결된다. 학생과 부서의 행 위치는 달라도 된다. 학생이 같은 부서를 쓰면 같은 오른쪽 행으로 여러 선이 연결된다. 각 선을 학습자가 반복해서 운반·조립하지 않는다.'),
('3단계','1: INNER JOIN으로 짝 있는 학생만 → 민지/개발, 준호/디자인, 서연/개발. 2: 왼쪽 모두 남기기 모드 → 도윤/NULL과 하늘/NULL까지 5행. 3: 오른쪽을 프로젝트 표로 바꿔 1:N 확인 → 민지와 서연이 앱·웹 각각에 연결되어 총 5행.'),
('즉시 SQL','왼쪽 키 지정은 ON s.dept_id = ... 초안, 오른쪽 키 지정이 끝나면 ON s.dept_id = d.id로 완성된다. 직원 모두 남기기 도구는 LEFT JOIN, 짝만 도구는 INNER JOIN으로 즉시 바뀐다. ON이 미완성일 때는 주석과 빈 슬롯을 보여주고 실행 가능한 SQL인 척하지 않는다.'),
('판정과 경계','키 필드 의미와 모든 매칭 쌍, 미매칭 처리, 결과의 중복 수를 검사한다. NULL=어떤 키도 일치하지 않는다. 결과가 5행을 넘으면 오른쪽 결과 서랍만 스크롤한다. 원본 5×5는 늘리지 않는다. 오른쪽 프로젝트 표는 같은 dept_id가 여러 행에 나타날 수 있다.')]),
('SQL04 / SUBQUERY','계산한 값으로 다시 칠하기','큰 표를 늘리지 않고 5칸 계산 띠를 사용',[
('목표와 조작','의뢰: 평균을 넘은 학생을 찾아 주세요. 점수 열에서 평균 붓을 찍으면 아래 5칸 계산 띠가 90·55·80·NULL·70을 보여준다. NULL을 제외한 평균 73.75가 작은 토큰으로 나타난다. 이 토큰을 비교 붓에 연결해 > 조건을 적용하면 민지·서연 행만 칠해진다.'),
('캐릭터 반응','로봇은 점수 열에서 두세 칸을 짧게 톡톡 이동하며 계산 범위를 보여준다. 값 토큰은 비교 팔레트로 자동 붙는다. 학습자가 계산값을 집어 들고 긴 거리를 걷거나 점수 카드를 다섯 번 운반하지 않는다. 외부 조건의 >,>=,=는 아이콘과 짧은 한글 뜻으로 고른다.'),
('3단계','1: 평균 계산만 하고 SELECT AVG(score) 결과 73.75 확인. 2: 평균 초과 조건으로 민지90·서연80 추출. 3: 최댓값 토큰 90에 = 비교를 적용해 민지90만 추출. 빈 집합 IN은 선택 확장으로 두고 기본 난도를 늘리지 않는다.'),
('즉시 SQL','평균 붓을 누르면 안쪽 SELECT AVG(score) FROM students가 먼저 생긴다. 비교 적용 후 WHERE score > (안쪽 SELECT)가 연결된다. 안쪽 블록은 금색, 바깥 WHERE는 파랑으로 대응시킨다. 숫자 73.75만 코드에 박아 넣어 서브쿼리 관계를 숨기지 않는다.'),
('판정과 경계','내부 계산 범위·함수·NULL 제외·외부 비교와 출력 열을 검사한다. 안쪽 도구를 바꾸면 토큰과 바깥 결과를 함께 재계산한다. 아직 토큰이 없는 상태에서는 바깥 조건을 제출할 수 없다. >와 >=의 경계값 차이는 별도 짧은 변형 문제로 보여준다.')]),
('08 / LIVE SQL','색과 코드가 같은 상태를 가리키게','화면 연출보다 데이터 모델을 먼저 갱신',[
('단일 상태 모델','선택 열 순서, 조건 AST, 그룹 키·집계식, JOIN 대상·키·종류, 내부 질의·외부 비교, 정렬·LIMIT을 한 상태로 관리한다. 화면 색 마스크와 SQL 문자열, 결과표는 이 동일한 상태에서 파생한다. 정답 SQL을 단순히 보여주는 패널을 만들지 않는다.'),
('즉시 반영 규칙','이동만 했을 때는 현재 셀 값만 강조한다. 붓 적용 한 번을 한 트랜잭션으로 처리해 SQL·마스크·결과를 동시에 갱신한다. 입력 후 100ms 이내 갱신을 목표로 하고 0.2~0.6초의 짧은 연출은 모델 변경을 지연시키지 않는다. 다음 입력은 가능하면 연출과 병행한다.'),
('단계별 예','열 이름 붓 → SELECT name FROM students. 점수 열 추가 → SELECT name, score FROM students. 점수 조건 ≥80 → WHERE score >= 80. 지우개로 조건 도장 지우기 → WHERE 제거, 결과는 다시 5행. Z → 직전 조건과 색·결과·코드가 함께 복원된다.'),
('미완성·오답 표시','아직 SELECT 열이 없거나 JOIN 키가 한쪽만 있으면 주석과 빈 슬롯을 보여준다. 유효한 다른 설정은 실제 다른 결과를 계산해 보여주며, 제출 전부터 정답 설정으로 고치지 않는다. 제출 시 의뢰와 다른 행·열·그룹만 설명한다. 빈 결과도 유효한 질의 결과다.'),
('원본 보존','색칠은 읽기·추출의 시각적 조작이다. UPDATE나 DELETE처럼 원본 값·행을 바꾸지 않는다. SELECT 결과의 행 순서는 ORDER BY가 있을 때만 판정한다. JOIN·집계의 중복과 NULL 처리는 실제 계산 규칙으로 결정한다.')]),
('09 / FEEDBACK & PACING','지루한 반복을 줄이는 기준','목표 1개 · 새 개념 1개 · 작은 성공 1개',[
('단계 구성','처음부터 붓을 모두 보여주지 않는다. 조회는 열 붓부터, 그다음 조건 붓, 마지막에 순서·개수 도구를 연다. 집계·JOIN·서브쿼리도 직전 조작을 재사용하고 새 도구는 한두 개만 추가한다. 반복 데이터로 화면 읽기 비용을 줄인다.'),
('진행과 해설','자연어 의뢰를 최상단에 짧게 고정한다. 작업마다 작은 효과음·붓 자국·코드 줄 강조가 반응한다. 정답 제출 후 잠깐 결과를 살펴보고 Enter로 다음 문제를 선택한다. 긴 NPC 설명과 행 수 예측을 매 문제마다 강제하지 않는다.'),
('오답 안내','빨간 정답 칠하기 대신, 누락 열·과다 행·잘못 연결한 키·그룹 기준 차이를 짚는다. 첫 힌트는 데이터의 어느 특징을 볼지, 다음 힌트는 연산 개념을 설명한다. 자동으로 정답 칸이나 조건 값을 칠하는 힌트는 기본으로 제공하지 않는다.'),
('수용 기준','붓 한 번이 한 연산으로 대응하고 칠한 범위와 실제 SQL 결과가 같아야 한다. 25개 셀 반복 클릭이 필요하지 않아야 한다. 로봇이 값·헤더·코드를 가리지 않아야 한다. Z/X/재진입 후 상태가 정확히 복원돼야 한다. 색약 모드에서도 패턴·레이블로 그룹과 선택을 구분할 수 있어야 한다.'),
('검증 범위','본 문서의 12개 예제 SQL은 SQLite 메모리 DB로 실행해 기대 결과를 대조했다. 이는 제안 명세의 데이터 검증이며 신규 UI가 이미 구현·플레이테스트됐다는 뜻은 아니다. 입문자에게 1분 안에 첫 열 선택을 이해하는지와 피로도를 실제 확인해야 한다.')]),
('10 / HANDOFF','개발·아트 전달 명세','기존 게임은 보존하고 SQL 화면만 새 규칙으로 교체',[
('개발 경계','현재 카드 운반 SQL은 이번 제안의 최종 방식이 아니다. 기존 데이터 계산·메뉴·진행 저장·월드 복귀를 재사용하되 SQL 4종의 화면·입력·상태 모델을 5×5 색칠 방식으로 교체한다. 섬·건물·NPC의 월드 배치 좌표는 유지한다. 이번 산출물은 실행 코드 변경을 포함하지 않는다.'),
('권장 구성','DrawerBoard: 5행×5열과 헤더·값·마스크. GridRobot: 한 칸 이동과 붓 적용 표시. BrushState: 열·조건·그룹·키·집계 연산. QueryModel: 실제 SQL 구조. LiveCodePanel: 변경 줄 강조와 초안 표시. ResultTray: 결과·빈 결과·5행 초과 스크롤. 레벨 데이터와 정답 제약은 UI와 분리한다.'),
('필수 검사','조회 ≥80은 민지·서연만, 평균은 73.75, 그룹 COUNT(*) 합은 5, COUNT(score) 합은 4. LEFT JOIN은 5행·미매칭 2명, 프로젝트 JOIN은 5행과 중복 학생을 보존해야 한다. 미완성 질의 제출 차단·연속 E 중복 방지·모든 도구 되돌리기·NULL·0행·반복 색칠도 검사한다.'),
('시안의 역할','뒤의 네 장은 내장 이미지 생성 도구로 만든 화면 디자인 시안이다. 격자·문구·SQL은 구현 시 실제 데이터로 다시 그린다. 배경, 5×5 서랍, 로봇, 선택 색 마스크, 붓 아이콘, SQL 패널을 분리 제작한다. PNG 한 장을 배경으로 깔고 가짜 숫자·선을 그대로 사용하는 방식은 피한다.'),
('제공 파일','수정 명세 PDF와 시안 PNG 4장 전용 ZIP을 별도로 제공한다. JSON에는 표·예제 SQL·기대 결과와 검증 기록을 보존하고 생성 요청문도 따로 저장한다. 10×10 및 카드 운반 시안은 이번 시안 ZIP에 포함하지 않는다.')])]

def build():
    checked=verify()
    (OUT/'example_validation.json').write_text(json.dumps(checked,ensure_ascii=False,indent=2),encoding='utf-8')
    (OUT/'datasets.json').write_text(json.dumps({'students_columns':['id','name','score','dept','city'],'students':ROWS,'join_students_columns':['id','name','dept_id','score','city'],'join_students':JOIN_ROWS,'depts_columns':['id','name','city','floor','active'],'depts':DEPTS,'projects_columns':['dept_id','project','owner','budget','active'],'projects':PROJECTS},ensure_ascii=False,indent=2),encoding='utf-8')
    markdown=['# SQL 5×5 서랍 색칠 미니게임 명세 v2.0','작성일: 2026-11-09','상태: 기획·디자인 제안 / 아직 실행 코드에 미적용','']
    for k,title,sub,sections in PAGES:
        markdown+=['## '+title,sub,'']
        for label,text in sections:markdown+=['### '+label,text,'']
    markdown+=['## 기본 표','|id|name|score|dept|city|','|---|---|---|---|---|']
    for row in ROWS:markdown.append('|'+ '|'.join('NULL' if x is None else str(x) for x in row)+'|')
    markdown+=['','## 검증된 예제 SQL']
    for test in checked:markdown+=['### '+test['id'],'```sql',test['sql']+';','```','예상 결과: '+json.dumps(test['expected'],ensure_ascii=False),'']
    md='\n'.join(markdown)
    (OUT/'SQL_5x5_Design_Spec_v2.0.md').write_text(md,encoding='utf-8')
    (ROOT/'docs/SQL_DRAWER_5X5_SPEC.md').write_text(md,encoding='utf-8')
    pdf=OUT/'Nodeverse_SQL_5x5_Design_Spec_v2.0.pdf'
    b=Book(pdf,version='2.0')
    for k,title,sub,sections in PAGES:
        b.start(k,title,sub,color='#28669e')
        if k.startswith('03'):
            b.table([['id','name','score','dept','city']]+[[('NULL' if v is None else str(v)) for v in row] for row in ROWS],[55,120,85,125,126])
        for label,text in sections:b.section(label,text)
    arts=[('SQL01_5x5_Extract','조회 · 색칠한 교집합 추출'),('SQL02_5x5_Group','집계 · 같은 값은 같은 색'),('SQL03_5x5_Join','JOIN · 같은 키 색 연결'),('SQL04_5x5_Subquery','서브쿼리 · 계산한 값으로 색칠')]
    previews=ROOT/'tmp/pdfs/embedded';previews.mkdir(parents=True,exist_ok=True)
    for id,title in arts:
        p=ART/(id+'.png');assert p.exists()
        Image.open(p).convert('RGB').save(previews/(id+'.jpg'),quality=92,optimize=True)
        b.start('DESIGN CONCEPT / 5×5',title,'작은 로봇 + 실제 색 범위 + 오른쪽 LIVE SQL',color='#28669e')
        b.image(p,42,355,W-84,340)
        b.y=327
        b.section('검토할 핵심','25개 데이터 칸과 바깥 헤더를 분리한다. 캐릭터가 셀 위에서 짧게 움직이며 붓 적용이 코드 줄 변화와 연결된다. 색 범위·결과표·SQL은 실제 데이터 모델로 동기화한다.')
        b.section('최종 제작 시','이 그림은 화면 방향을 전달하는 시안이다. 영어 별칭은 실제 UI에서 한글 데이터와 대응시키고, 숫자·선·코드·로봇·색 마스크는 별도 레이어로 구현한다. 시안의 장식·폰트 크기를 그대로 베끼기보다 1280×720에서 읽기 쉬운 크기로 맞춘다.')
        b.text('PNG: '+p.name,SMALL)
    assert b.page==14,b.page
    b.c.save()
    reader=PdfReader(str(pdf));assert len(reader.pages)==14
    text='\n'.join(p.extract_text() or '' for p in reader.pages)
    for term in ['5×5','73.75','실시간','SQL01','SQL04']:assert term in text,term
    zpath=OUT/'Nodeverse_SQL_5x5_Concepts_4.zip'
    with zipfile.ZipFile(zpath,'w',zipfile.ZIP_DEFLATED) as z:
        for id,_ in arts:z.write(ART/(id+'.png'),id+'.png')
    with zipfile.ZipFile(zpath) as z:assert len(z.namelist())==4 and z.testzip() is None
    shutil.copy2(ART/'prompts.json',OUT/'image_prompts.json')
    print(json.dumps({'pdf':str(pdf),'pages':14,'image_zip':str(zpath),'zip_mb':round(zpath.stat().st_size/1024**2,1),'examples_passed':len(checked)},ensure_ascii=False))
if __name__=='__main__':build()
