from pathlib import Path
import json, re, zipfile, hashlib
from xml.sax.saxutils import escape
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.colors import HexColor, white
from reportlab.platypus import Paragraph, Table, TableStyle
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.utils import ImageReader
from pypdf import PdfReader

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output'/'pdf'
OUT.mkdir(parents=True,exist_ok=True)
ART=ROOT/'reference'/'minigame_spec_concepts'
OLD=ROOT/'reference'/'new_minigame_concepts'
W,H=595.276,841.89
INK=HexColor('#183044'); MUTED=HexColor('#587080'); LINE=HexColor('#dce5eb')
COLORS={'자료구조':'#167a78','알고리즘':'#3866bc','SQL':'#8a5c28','데이터 탐색':'#7f50a0'}
pdfmetrics.registerFont(TTFont('KR','C:/Windows/Fonts/malgun.ttf'))
pdfmetrics.registerFont(TTFont('KRB','C:/Windows/Fonts/malgunbd.ttf'))
BODY=ParagraphStyle('body',fontName='KR',fontSize=9.2,leading=14.5,textColor=INK,wordWrap='CJK')
SMALL=ParagraphStyle('small',parent=BODY,fontSize=8,leading=12)
HEAD=ParagraphStyle('head',fontName='KRB',fontSize=10,leading=15,textColor=INK,wordWrap='CJK')
G=[]
def game(id,cat,title,status,source,pre,goal,loop,levels,example,rules,judge,tests,assets,art=None):
    G.append(dict(id=id,category=cat,title=title,status=status,source=source,prerequisite=pre,goal=goal,loop=loop,levels=levels,example=example,rules=rules,judge=judge,tests=tests,assets=assets,art=art))

game('DS-01','자료구조','배열 | 순서가 있는 보관소','기존 활용','ST01_Array','없음',
'연속된 칸과 인덱스를 이해하고, 삽입·삭제 시 원소가 이동하는 이유를 설명한다.',
'요청 카드 확인 → 인덱스 칸 선택 → 조회·삽입·삭제 → 이동 애니메이션과 결과 배열 확인.',
['기초: 0부터 시작하는 인덱스로 물건 조회','응용: 중간 삽입·삭제 후 순서를 복원','도전: 용량 제한 안에서 여러 요청을 순서대로 수행'],
'[4, 7, 9]의 인덱스 1에 5 삽입 → [4, 5, 7, 9]. 이후 인덱스 2 삭제 → [4, 5, 9].',
'고정 용량 6칸. 조회·삭제는 0 ≤ i < 길이, 삽입은 0 ≤ i ≤ 길이. 가득 차면 삽입 거부. 값 중복은 허용.',
'요청 이행 순서와 최종 배열이 모두 일치하면 완료. 범위 초과는 상태를 바꾸지 않고 이유 표시.',
'빈 배열 삭제·끝 삽입·가득 찬 배열·중복 값·되돌리기를 확인. 이동 칸 수와 실제 변경 칸이 일치해야 한다.',
'번호 보관함, 원소 상자, 이동 화살표, 삽입 위치 표시. 기존 ST01 배경 재사용.')
game('DS-02','자료구조','연결 리스트 | 끊어진 운송로','기존 활용','ST02_LinkedList','DS-01',
'노드와 next 참조를 구분하고, 물리적 위치와 논리적 순서가 다를 수 있음을 이해한다.',
'head에서 연결 추적 → 새 노드 선택 → next 연결 수정 → 운송 테스트로 도착 순서 확인.',
['기초: head와 next를 따라 순서 읽기','응용: 중간 노드를 삽입하거나 삭제','도전: head 변경과 단일 노드 리스트 처리'],
'A → C에서 B 삽입: B.next=C, A.next=B → A → B → C.',
'단일 연결 리스트로 한정. head와 null을 명시. 편집 중 임시 미연결은 허용하되 제출 시 순환·유실 노드를 검사.',
'head에서 읽은 노드 ID 순서가 목표와 일치하고, 사용 노드를 한 번씩 방문해야 완료.',
'빈 리스트 삽입, 첫 노드 삭제, 마지막 next=null, 순환 연결, 값이 같은 서로 다른 노드를 구분한다.',
'노드 블록, 방향 케이블, head 표식, null 종단. 기존 ST02 배경 재사용.')
game('DS-03','자료구조','스택 | 최근 작업 복구실','기존 활용','ST03_Stack','DS-01',
'LIFO와 top을 이해하고, 최근 작업부터 복구되는 순서를 예측한다.',
'작업 카드 수신 → Push로 적재 → Pop으로 최근 작업 복구 → 작업 기록과 적재 상태 대조.',
['기초: Push·Pop과 top 확인','응용: 지정 결과가 되도록 연산 선택','도전: 용량과 빈 스택을 고려한 복구 요청 수행'],
'Push A, Push B, Pop → 반환 B, 남은 스택 [A]. Peek는 A를 보여주고 상태는 유지.',
'용량 5개. 빈 스택 Pop과 가득 찬 Push 거부. top은 항상 가장 최근에 추가된 원소.',
'꺼낸 순서·최종 스택·필수 요청을 함께 비교. 최종 모양만 맞추는 우회는 완료로 인정하지 않는다.',
'underflow·overflow·Peek 무변경·연속 Pop·되돌리기 후 top 표시를 검사한다.',
'수직 적재대, top 화살표, 작업 카드, 복구 기록. 기존 ST03 배경 재사용.')
game('DS-04','자료구조','큐·덱 | 접수 순서 안내소','기존 활용','ST04_QueueDeque','DS-01, DS-03 권장',
'FIFO를 설명하고 큐와 양끝 연산이 가능한 덱의 차이를 구분한다.',
'접수 카드 확인 → 앞·뒤 출입구 선택 → 삽입·꺼내기 → 대기열과 처리 기록 확인.',
['기초: 큐의 enqueue·dequeue','응용: 원형 큐에서 front·rear와 순환 확인','도전: 덱의 앞·뒤 삽입·삭제로 목표 순서 만들기'],
'큐에 A, B 접수 후 dequeue → A. 덱 [B, C]에 push_front A → [A, B, C].',
'용량 5개. 큐 모드에서는 뒤 삽입·앞 삭제만 허용. 원형 큐는 별도 size로 빈 상태와 가득 참을 구분.',
'처리 순서와 남은 대기열이 요청과 일치해야 완료. 허용하지 않는 출입구는 사전 차단.',
'front 순환, 마지막 원소 삭제, 빈 덱의 양끝 삭제, 가득 참, 동일 값 접수를 검사한다.',
'양끝 게이트, 대기 슬롯, front·rear 표식. 기존 ST04 배경 재사용.')
game('DS-05','자료구조','해시 테이블 | 이름으로 찾는 물품대장','기존 활용','ST05_Hash','DS-01',
'키와 값, 해시 인덱스, 충돌을 이해하고 조회 경로를 재현한다.',
'키 확인 → 해시 계산 → 버킷 선택 → 충돌 처리 → 같은 규칙으로 조회.',
['기초: h(k)=k mod 5로 버킷 찾기','응용: 체이닝으로 충돌 키 함께 저장','도전: 선형 탐사 모드에서 삽입·조회 경로 완성'],
'키 7과 12는 모두 버킷 2. 체이닝은 두 항목을 연결하고, 선형 탐사는 12를 다음 빈 칸에 저장.',
'충돌 전략은 레벨별 고정. 같은 키 재입력은 값 갱신. 선형 탐사는 한 바퀴까지만 탐색. 이번 범위에서 삭제 제외.',
'저장된 key/value와 실제 조회 결과를 비교. 충돌 자체는 오답이 아니며 잘못된 처리만 안내.',
'동일 키 갱신, 서로 다른 충돌 키, 없는 키, 가득 찬 탐사, 전략 혼동을 검사한다.',
'버킷 서랍, 키 카드, 체인·탐사 표시. 기존 ST05 배경 재사용.')
game('DS-06','자료구조','트리 구조 | 가지 잇는 나무','기존 활용','DS09_TreeStructure','DS-02',
'루트·부모·자식·리프를 구분하고, 순환 없는 계층 구조를 만든다.',
'목표 관계표 읽기 → 부모·자식 선택 → 왼쪽·오른쪽 연결 → 전체 트리 검사.',
['기초: 루트에서 두 자식 연결','응용: 2단계 계층과 리프 구성','도전: 잘못된 부모 연결을 풀고 목표 트리 복원'],
'A.left=B, A.right=C, B.left=D → 루트 A, 리프 C·D. D → A 연결은 순환이므로 거부.',
'일반 트리 개념을 이진 트리 편집으로 입문. 노드당 부모 최대 1개, 자식 슬롯 최대 2개, 루트 부모 없음.',
'목표 간선·좌우 슬롯이 일치하고, 모든 사용 노드가 루트에서 도달 가능해야 완료.',
'자기 연결, 중복 부모, 슬롯 중복, 순환, 연결 해제 후 복원. 값 정렬 규칙은 이 게임에서 평가하지 않는다.',
'A~E 노드, 연결 소켓, 루트·리프 표식. 기존 트리 시안 활용.','DS09_tree_structure.png')
game('DS-07','자료구조','이진 탐색 트리 | 갈림길 창고','기존 활용','ST07_Bst','DS-06',
'각 노드의 왼쪽 서브트리는 작은 값, 오른쪽은 큰 값이라는 BST 규칙을 적용한다.',
'값 카드 수신 → 루트부터 비교 → 왼쪽·오른쪽 이동 → 빈 자리에 삽입 또는 조회 종료.',
['기초: 비교 방향을 따라 값 조회','응용: 값 여러 개를 차례대로 삽입','도전: 없는 값 탐색과 편향된 트리 비교'],
'8을 루트로 3, 10, 6 삽입 → 3은 왼쪽, 10은 오른쪽, 6은 3의 오른쪽.',
'중복 키는 이번 범위에서 거부하고 규칙 표시. 회전·균형 조정·삭제는 확장 범위. 부모만이 아니라 조상 범위도 지킨다.',
'삽입 순서에 따른 구조와 방문 경로 확인. 목표 값이 없으면 null 도달을 올바른 완료로 인정.',
'빈 트리, 한쪽으로 긴 트리, 조상 범위 위반, 중복 입력, 없는 값 조회를 검사한다.',
'분기 창고, 값 노드, 비교 표지. 기존 ST07 배경 재사용.')
game('DS-08','자료구조','힙·우선순위 큐 | 긴급 작업 배정실','기존 활용','ST08_Heap','DS-01, DS-06',
'최소 힙의 완전 이진 트리 모양과 부모 ≤ 자식 규칙을 유지한다.',
'긴급도 값 수신 → 마지막 슬롯에 삽입 → 위로 교환 → 최솟값 꺼내기 → 아래로 교환.',
['기초: 배열과 트리의 같은 슬롯 확인','응용: 삽입 후 sift-up','도전: 루트 추출 후 sift-down으로 작업 처리'],
'힙 [2, 5, 3]에 1 삽입 → [1, 2, 3, 5]. 최솟값 1 추출 → 유효한 남은 최소 힙.',
'숫자가 작을수록 우선. 같은 값은 작업 ID로 구분하되 선착순 보장은 하지 않음. 트리와 배열 표현을 동기화.',
'꺼낸 최솟값과 힙 불변식을 검사. 유효한 배치가 여러 개면 모두 허용하며 특정 스냅샷만 강제하지 않는다.',
'빈 힙 추출, 한 원소, 같은 우선순위, 두 자식 중 작은 쪽 선택, 배열·트리 동기화를 확인.',
'작업 트리, 배열 슬롯, 우선순위 카드. 기존 ST08 배경 재사용.')
game('DS-09','자료구조','그래프 구조 | 연결망 건설소','신규','신규 씬 필요','DS-02, DS-06',
'정점·간선·방향·가중치와 연결 여부를 구분한다. 방문 순서는 여기서 평가하지 않는다.',
'노선 요청 읽기 → 두 정점 연결 → 방향·비용 설정 → 연결표와 도달 여부 검사.',
['기초: 무방향 간선으로 연결망 만들기','응용: 방향 간선으로 편도 노선 만들기','도전: 가중치와 연결되지 않은 정점을 포함한 노선 복원'],
'A→B(3), B→C(2)일 때 A에서 C는 도달 가능, C에서 A는 불가. C→A 추가 시 순환이 생겨도 유효.',
'정점 4~6개. 순환 허용. 자기 간선·평행 간선은 이번 범위에서 제외. 비용은 양의 정수 1~9.',
'정점 ID, 간선 방향, 가중치 집합이 목표와 일치하면 완료. 단절 자체는 오답이 아니며 요청에 따라 판단.',
'간선 역방향, 무방향 대칭, 단절 정점, 유효한 순환, 비용 수정, BFS 게임과 상태 분리를 검사.',
'연결 소켓 6개, 탈착 케이블, 방향 화살표, 비용판, 연결표.','DS_GRAPH.png')

game('AL-01','알고리즘','탐색 | 물건 찾기 비교실','기존 확장','ALG02_Search','DS-01, 정렬된 순서 이해',
'선형 탐색과 이진 탐색의 전제 및 비교 횟수 차이를 실제 행동으로 확인한다.',
'목표 값 확인 → 탐색 방식 선택 → 다음 검사 칸 선택 → 비교 결과로 다음 상태 갱신.',
['기초: 선형 탐색으로 왼쪽부터 조회','응용: 정렬 배열에서 이진 탐색 구간 축소','도전: 없는 값·중복 값과 비교 횟수 비교'],
'[2,5,8,12,16,23,38]에서 16: 이진 탐색은 인덱스 3→5→4, 총 3회 비교.',
'이진 탐색은 정렬된 배열만 허용. mid=floor((low+high)/2). 없으면 low>high로 종료. 중복은 일치한 어느 인덱스도 인정.',
'매 단계 검사 인덱스와 구간 갱신 검증. 비교 횟수는 기록하되 시간 제한이나 최적 횟수를 완료 조건으로 강제하지 않는다.',
'빈 배열, 한 원소, 양 끝 값, 없는 값, 중복, 정렬되지 않은 배열의 이진 탐색 차단.',
'서고 칸, low·mid·high 표시, 비교 기록. 기존 이진 탐색 시안 재사용. 선형 탐색 단계 추가.','ALG02_binary_search.png')
game('AL-02','알고리즘','기본 정렬 | 순서 맞춤 작업대','기존 확장','ALG01_Sorting','DS-01',
'버블·선택·삽입 정렬에서 비교 대상과 확정 구간이 달라지는 이유를 이해한다.',
'정렬 방식 확인 → 비교 대상 선택 → 교환 또는 이동 → 확정 구간 표시 → 다음 단계.',
['기초: 버블 정렬의 인접 비교·교환','응용: 선택 정렬의 미정렬 구간 최솟값 선택','도전: 삽입 정렬의 key 보관과 큰 값 밀기'],
'[3,1,2]의 첫 패스: 버블은 [1,2,3], 선택은 [1,3,2], 삽입의 첫 삽입은 [1,3,2].',
'오름차순, 음수·중복 포함. 버블은 한 패스의 모든 비교, 선택은 최솟값 결정 후 한 번 교환, 삽입은 key 임시 보관.',
'최종 정렬뿐 아니라 선택한 알고리즘의 단계·원소 보존을 검사. 방식별 비교·쓰기 횟수를 별도로 보여준다.',
'이미 정렬됨, 역순, 같은 값, key 유실, 비인접 버블 교환, 확정 구간 오류를 검사.',
'정렬 트레이, 비교 브래킷, key 받침, 확정 구간 표식. 기존 정렬 시안 확장.','ALG01_sorting.png')
game('AL-03','알고리즘','분할 정복 정렬 | 나누고 합치는 공방','신규','신규 씬 필요','AL-02',
'병합 정렬의 분할·병합과 퀵 정렬의 기준값·분할을 구분한다.',
'방식 선택 → 구간 분할 → 병합 또는 pivot 분배 → 부분 결과 확인 → 전체 정렬.',
['기초: 병합 정렬의 구간을 한 원소까지 분할','응용: 두 정렬 구간의 앞 원소를 비교해 안정 병합','도전: 마지막 값을 pivot으로 골라 작은·같은·큰 그룹 분할 후 재귀'],
'[4,1,3,2]를 [1,4]와 [2,3]으로 정렬한 뒤 병합 → [1,2,3,4]. 퀵 정렬의 첫 pivot은 2.',
'4~8개 원소. 퀵은 교육용 3방향 그룹 분할로 고정하고 제자리 partition과 구분. 병합 동률이면 왼쪽 먼저.',
'원소 ID와 개수 보존, 현재 구간, 병합 선택·pivot 그룹의 조건을 단계별 검사. 최종값만 맞추는 임의 이동은 거부.',
'홀수 길이, 모두 같은 값, 역순, 빈 부분 그룹, 중복 안정 병합, 재귀 종료를 검사.',
'분할 트레이, 병합 레일, pivot 받침, 3방향 구획.','ALGO_DIVIDE_SORT.png')
game('AL-04','알고리즘','트리 순회 | 계층형 자료실','기존 활용','ST06_BinaryTree','DS-06, DS-03, DS-04 권장',
'같은 트리에서 전위·중위·후위·레벨 순회의 방문 결과를 예측한다.',
'순회 지시 확인 → 다음 방문 노드 선택 → 방문 기록과 보조 스택·큐 확인 → 전체 순회.',
['기초: 전위 순회와 루트 우선','응용: 중위·후위 순회 비교','도전: 레벨 순회와 다른 순회 결과 구분'],
'A의 자식 B·C, B의 자식 D·E: 전위 A B D E C / 중위 D B E A C / 후위 D E B C A / 레벨 A B C D E.',
'이진 트리 좌우를 고정. 값이 같아도 노드 ID로 구분. 방문 완료와 경유 애니메이션을 구분해 중복 방문 오해 방지.',
'순회 규칙으로 계산한 노드 ID 목록과 매 입력을 비교. 틀린 입력은 방문 처리하지 않고 다음 규칙을 설명.',
'빈 트리 설명, 단일 노드, 한쪽 자식만 있는 트리, 중복 값, 네 순회 예제 결과를 검사.',
'자료실 트리, 방문 발자국, 스택·큐 보조판. 기존 ST06 배경 재사용.')
game('AL-05','알고리즘','그래프 탐색 | 연결망 조사실','기존 활용','ST09_Graph','DS-09, DS-03, DS-04',
'BFS의 큐와 DFS의 스택·되돌아가기를 이해하고 순환에서 중복 방문을 막는다.',
'시작점 선택 → 다음 정점 또는 frontier 선택 → 방문 표시 → 큐·스택 갱신 → 탐색 종료.',
['기초: BFS로 가까운 단계부터 방문','응용: DFS로 한 갈래를 깊게 조사','도전: 순환·단절이 있는 그래프와 방문 순서 비교'],
'무방향 간선 AB, AC, BD, CD에서 A 시작, 이웃 ID 오름차순: BFS A B C D / 재귀식 DFS A B D C.',
'이웃 ID 오름차순으로 동률 해소. BFS는 enqueue 시 방문 예약. DFS는 재귀 호출을 흉내 낸 스택 프레임 방식.',
'방문 순서와 보조 구조 상태 검사. 기본은 시작점에서 도달 가능한 성분만 방문; 전체 성분 순회는 별도 미션.',
'순환 재방문 방지, 중복 enqueue 방지, 단절 종료, 방향 간선, 이웃 정렬과 예제 일치를 검사.',
'정점 지도, 탐색 빛, visited 표시, frontier 판. 기존 ST09 배경 재사용.')
game('AL-06','알고리즘','최단 경로 | 최소 비용 배달소','신규','신규 씬 필요','DS-08, DS-09, AL-05',
'다익스트라의 현재 최소 거리 확정과 간선 완화로 최소 비용 경로를 찾는다.',
'시작 거리 초기화 → 미확정 최소 거리 정점 선택 → 이웃 비용 갱신 → 목적지 경로 복원.',
['기초: 4정점에서 거리표 갱신','응용: 우회 노선이 더 저렴한 가중 그래프','도전: 동률 경로와 도달 불가 목적지 판정'],
'A→B=4, A→C=1, C→B=2, B→D=1, C→D=5이면 A→C→B→D, 비용 4.',
'비용 0~9, 음수 간선 차단. dist[start]=0, 나머지 무한대. 동률 정점은 ID순, 동일 비용의 유효한 최단 경로는 모두 인정.',
'최소 정점 선택·relax 수식·이전 정점 기록을 검증. 목적지 확정 또는 frontier 소진 시 종료.',
'비용 0, 동률 최단 경로, 단절, 시작=목적지, 음수 거부, 오래된 큐 항목 무시를 검사.',
'가중 노선 지도, 거리 장부, 이전 정점 표, 우선순위 트레이.','ALGO_SHORTEST.png')

game('SQ-01','SQL','기록 조회 | 필요한 기록 찾기','기존 확장','SQL01_Query','표의 행·열 이해',
'원하는 열·행·순서를 SELECT·WHERE·ORDER BY·LIMIT으로 표현한다.',
'의뢰 확인 → 열·조건·정렬·개수 블록 조립 → 실행 → 원본과 결과표 비교 → 질의 수정.',
['기초: 필요한 열만 조회','응용: AND·OR와 비교 조건으로 필터','도전: 정렬과 LIMIT으로 상위 기록 추출'],
'students가 (1,민,90),(2,서,70),(3,준,80)이면 score≥80, 점수 내림차순 LIMIT 1 → (민,90).',
'블록 조립 우선. ORDER BY score DESC, id ASC로 동률 고정. LIMIT은 정렬 후 적용. SQL의 NULL 비교는 별도 안내.',
'열 이름·열 순서·행의 중복 수를 비교. ORDER BY가 있을 때만 행 순서를 채점. 잘못된 질의는 원본 무변경.',
'빈 결과, 조건 경계값, AND·OR 괄호, 동점 정렬, LIMIT 0, 없는 열, 실행 반복 동일 결과.',
'레코드 서랍, 열 선택 스위치, 필터 게이트, 정렬 장치, 결과표. 기존 SQL 시안 활용.','SQL01_query.png')
game('SQ-02','SQL','그룹 집계 | 부서별 실적 보고서','신규','신규 씬 필요','SQ-01',
'행 필터와 그룹 필터를 구분하고 COUNT·SUM·AVG로 집계 보고서를 만든다.',
'보고서 요청 읽기 → WHERE 선택 → 그룹 열 선택 → 집계 함수 조립 → HAVING → 결과 실행.',
['기초: 부서별 COUNT·SUM','응용: AVG와 COUNT(*)·COUNT(열)의 차이','도전: WHERE와 HAVING을 함께 적용'],
'sales의 (A,10),(A,20),(B,5): GROUP BY dept → A:개수2·합30·평균15, B:개수1·합5·평균5. HAVING SUM>10 → A만.',
'선택 열은 그룹 열 또는 집계식으로 제한. COUNT(*)는 모든 행, COUNT(amount)는 NULL 제외. AVG는 유효 값으로 계산.',
'그룹 키와 집계값을 기대 결과와 비교. SQL 실행 결과와 단계별 행 수를 함께 표시해 필터 위치 오류를 설명.',
'NULL 포함, 한 그룹, 빈 입력, WHERE로 전체 제거, HAVING 경계, 허용되지 않는 비집계 열.',
'그룹별 바구니, 집계 선택기, HAVING 게이트, 보고서 판.','SQL_GROUP.png')
game('SQ-03','SQL','테이블 연결 | 기록 연결 사무소','기존 요소 분리·확장','SQL01_Query의 제한 JOIN','SQ-01, 키 개념',
'키 조건으로 테이블을 연결하고 INNER JOIN과 LEFT JOIN의 결과 차이를 이해한다.',
'왼쪽·오른쪽 표 확인 → 연결 키 선택 → JOIN 종류 선택 → 매칭 애니메이션 → 결과표 검사.',
['기초: 일치하는 키를 INNER JOIN','응용: LEFT JOIN으로 미매칭 행 유지','도전: 한 키에 여러 행이 매칭되는 결과 예측'],
'직원 (민,1),(서,2),(준,9), 부서 (1,개발),(2,운영). LEFT JOIN → 민/개발, 서/운영, 준/NULL.',
'키 동등 비교 JOIN만 지원. 왼쪽 키가 NULL이면 일반 = 조건으로 매칭하지 않음. 1:N은 행을 모두 생성; 자동 중복 제거 금지.',
'매칭된 행 조합과 중복 수를 비교. 별도 정렬 지시가 없으면 결과 행 순서는 채점하지 않는다.',
'미매칭, NULL 키, 1:N, 빈 오른쪽 표, 키 대신 행 번호로 연결한 오답, 동일 열 이름 별칭.',
'두 표 랙, 키 연결선, 미매칭 빈칸, INNER·LEFT 선택기. 신규 전용 시안 제작.','SQL_JOIN.png')
game('SQ-04','SQL','서브쿼리 | 조건 속의 조건','신규','신규 씬 필요','SQ-01, SQ-02',
'안쪽 질의 결과가 바깥쪽 질의의 값 또는 집합으로 사용되는 관계를 이해한다.',
'전체 요청 분해 → 안쪽 질의 실행 → 단일 값·집합 확인 → 바깥 조건에 연결 → 최종 실행.',
['기초: 평균보다 큰 점수 조회','응용: IN으로 특정 부서 집합에 속한 기록 찾기','도전: 빈 집합과 단일 값·다중 행 구분'],
'점수 [60,80,100]에서 내부 AVG=80, 바깥 WHERE score>80 → 100인 행만 반환.',
'비상관 서브쿼리만 지원. 스칼라에는 한 행·한 열, IN에는 한 열 집합. EXISTS·상관 쿼리·NOT IN의 NULL 함정은 확장 범위.',
'안쪽 결과와 바깥 결과를 각각 검증. 스칼라에 다중 행을 연결하면 실행 전 형태 오류를 안내.',
'스칼라 다중 행, 빈 IN 집합, 평균과 같은 경계값, 내부 NULL 평균, 안쪽 질의 수정 후 재계산.',
'내부 계산 프레임, 결과 토큰, 외부 필터, 의존 화살표.','SQL_SUBQUERY.png')

game('DA-01','데이터 탐색','데이터 점검 | 관측 준비실','신규','신규 씬 필요','표의 행·열 이해',
'값을 바꾸기 전에 행·열·자료형·단위·결측 비율을 조사해 점검표를 완성한다.',
'데이터 사전 읽기 → 열 확대 관찰 → 자료형·단위 선택 → 결측 개수 계산 → 점검표 제출.',
['기초: 관측 단위와 행·열 개수 파악','응용: 숫자·문자·날짜와 단위 구분','도전: 결측 비율과 형식 이상 열 발견'],
'5행의 age 열이 [20, NULL, 30, 40, NULL]이면 결측 2개, 결측률 40%. 숫자 0은 결측이 아니다.',
'CSV 자동 추론만 믿지 않고 데이터 사전과 비교. 빈 문자열·NA 표식은 명시된 규칙으로만 결측 취급. 원본 수정 금지.',
'점검표의 개수·형식·단위·비율을 검증. 결측 비율은 표시 반올림 규칙을 적용해 허용 오차 0.1%p.',
'0과 결측, 숫자처럼 보이는 우편번호, 행 0개 비율 계산 불가, 날짜 형식 혼재, 원본 무변경.',
'원본 표, 자료형 태그, 단위 카드, 결측 게이지, 점검 장부.','DATA_PROFILE.png')
game('DA-02','데이터 탐색','데이터 정제 | 기록 수리 공방','기존 확장','DATA01_Explore','DA-01',
'결측·중복·형식 오류의 처리 기준을 선택하고 처리 전후 차이를 설명한다.',
'문제 행 표시 → 정제 기준 선택 → 미리보기 → 적용 → 제외·수정 기록과 남은 표 확인.',
['기초: 조건에 맞는 결측 행 제거','응용: 지정 키 기준으로 중복 제거','도전: 날짜·숫자 형식 표준화와 처리 순서 비교'],
'행 (1,A,10),(2,A,10),(3,B,NULL)에서 중복 기준이 group+value이면 첫 두 행 중 하나 유지. 이후 결측 제거 → 1행.',
'중복 키를 화면에 명시. 첫 등장 유지로 고정. NULL과 0 구분. 문자열 trim·형식 변환은 규칙 확인 후 적용; 임의 평균 대체는 제외.',
'남은 행 ID, 수정 값, 제외 사유를 비교. 처리 순서가 다르면 결과도 달라질 수 있으므로 파이프라인 순서를 기록.',
'ID만 다른 중복, 전체 행 중복과 키 중복 차이, 무효 날짜, 모든 행 제거, 취소 시 원본 복원.',
'문제 카드, 정제 게이트, 처리 이력, 전후 비교표. 기존 데이터 시안 활용.','DATA01_data_exploration.png')
game('DA-03','데이터 탐색','통계 비교 | 대표값 실험실','기존 요소 분리·확장','DATA01_Explore의 합계·평균','DA-01, DA-02',
'개수·평균·중앙값·범위를 비교하고 이상치가 대표값에 주는 영향을 해석한다.',
'집단과 지표 선택 → 값 정렬·계산 → 이상치 포함 여부 비교 → 근거를 골라 해석 제출.',
['기초: 개수·평균·범위 계산','응용: 홀수·짝수 개수의 중앙값','도전: 두 집단과 이상치 전후 비교'],
'[10,12,14,100]은 평균 34, 중앙값 13, 범위 90. 100을 제외하면 평균·중앙값 모두 12, 범위 4.',
'이상치는 자동 삭제하지 않고 비교 시나리오로만 제외. 유효 수치만 집계하고 제외 개수 표시. 중앙값은 정렬 후 중앙 두 값 평균.',
'계산값과 해석 근거를 함께 검사. 표시 소수 2자리, 수치 허용 오차 0.01. 데이터만으로 인과관계를 단정하는 결론은 거부.',
'빈 집단, 한 값, 짝수·홀수, 음수, 같은 평균 다른 분포, NULL 제외 분모, 이상치 무단 삭제.',
'두 집단 트레이, 수직선, 대표값 받침, 이상치 토큰, 비교표.','DATA_STATS.png')
game('DA-04','데이터 탐색','시각화 해석 | 차트 관측소','신규','신규 씬 필요','DA-01, DA-03',
'질문에 맞는 차트·축·집계를 선택하고, 차트의 근거로 제한된 결론을 제시한다.',
'질문 카드 확인 → 차트 선택 → 축·집계 지정 → 그래프 확인 → 근거 구간 표시 → 결론 선택.',
['기초: 범주별 합계는 막대그래프','응용: 시간 흐름은 선그래프와 날짜 순서','도전: 두 수치의 관계는 산점도, 상관과 인과 구분'],
'월별 판매량 [10,15,12]은 시간순 선그래프로 2월 최고를 읽는다. 키·몸무게 관계는 산점도로 관찰하며 원인이라고 단정하지 않는다.',
'축 이름·단위 필수. 막대는 0 기준선, 날짜는 시간순 정렬, 산점도는 원본 행의 x/y 쌍 보존. 선택 차트에 맞는 데이터 형식 검사.',
'차트 종류만이 아니라 축·집계·선택 근거·결론을 함께 채점. 의미상 동등한 유효 차트 설정은 허용.',
'축 뒤바꿈, 날짜 문자열 순서, 막대축 절단, 집계 중복, NULL 쌍 제외, 상관을 인과로 해석한 오답.',
'막대·선·산점도 이젤, 축·단위 카드, 근거 포인터, 결론 카드.','DATA_CHART.png')

assert len(G)==23
for cat,n in [('자료구조',9),('알고리즘',6),('SQL',4),('데이터 탐색',4)]:
    assert sum(g['category']==cat for g in G)==n

class Book:
    def __init__(self,path,version='1.0'):
        self.version=version
        self.c=canvas.Canvas(str(path),pagesize=(W,H))
        self.c.setTitle('Nodeverse - 23개 미니게임 기획 명세 v'+version)
        self.c.setAuthor('Nodeverse Project')
        self.page=0; self.y=0; self.headings=[]
    def start(self,kicker,title,subtitle='',color='#167a78'):
        if self.page:self.c.showPage()
        self.page+=1; c=self.c; self.color=HexColor(color)
        c.setFillColor(self.color); c.rect(0,H-10,W,10,fill=1,stroke=0)
        c.setFont('KRB',8); c.setFillColor(self.color); c.drawString(42,H-43,kicker)
        c.setFillColor(INK); c.setFont('KRB',23); c.drawString(42,H-78,title)
        c.setFont('KR',8.5); c.setFillColor(MUTED); c.drawString(42,H-100,subtitle)
        c.setStrokeColor(LINE); c.line(42,43,W-42,43)
        c.setFont('KR',7.5); c.drawString(42,29,'NODEVERSE  /  기획 제안 v'+self.version+'  /  2026.11.09')
        c.drawRightString(W-42,29,f'{self.page:02d}')
        self.y=H-126
        c.bookmarkPage(f'p{self.page}')
        c.addOutlineEntry(title,f'p{self.page}',level=0,closed=False)
        self.headings.append(title)
    def text(self,s,style=BODY,gap=9):
        p=Paragraph(escape(s).replace('\n','<br/>'),style); _,h=p.wrap(W-84,900)
        if self.y-h<58:raise ValueError(f'Overflow p{self.page}: {s[:35]} y={self.y} h={h}')
        p.drawOn(self.c,42,self.y-h);self.y-=h+gap
    def section(self,label,text):
        self.text(label,HEAD,gap=3);self.text(text,gap=9)
    def table(self,rows,widths,fs=8.2):
        st=ParagraphStyle('cell',parent=BODY,fontSize=fs,leading=fs+4)
        data=[[Paragraph(escape(str(x)),st) for x in row] for row in rows]
        t=Table(data,colWidths=widths,hAlign='LEFT')
        t.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('BACKGROUND',(0,0),(-1,0),HexColor('#eaf0f5')),('LINEBELOW',(0,0),(-1,0),.6,LINE),('LINEBELOW',(0,1),(-1,-1),.35,LINE),('TOPPADDING',(0,0),(-1,-1),7),('BOTTOMPADDING',(0,0),(-1,-1),7),('LEFTPADDING',(0,0),(-1,-1),7),('RIGHTPADDING',(0,0),(-1,-1),7)]))
        _,h=t.wrap(W-84,900)
        if self.y-h<58:raise ValueError(f'Table overflow {self.page}')
        t.drawOn(self.c,42,self.y-h);self.y-=h+13
    def image(self,path,x,y,w,h):
        preview=ROOT/'tmp'/'pdfs'/'embedded'/(Path(path).stem+'.jpg')
        if preview.exists():path=preview
        im=ImageReader(str(path));iw,ih=im.getSize();scale=min(w/iw,h/ih)
        self.c.drawImage(im,x+(w-iw*scale)/2,y+(h-ih*scale)/2,iw*scale,ih*scale,mask='auto')

def generate():
    dest=OUT/'Nodeverse_Minigame_Design_Spec_v1.0.pdf';b=Book(dest)
    b.start('GAME DESIGN DOCUMENT','미니게임 기획 명세','자료구조 · 알고리즘 · SQL · 데이터 탐색')
    b.c.setFillColor(HexColor('#eef6f6'));b.c.roundRect(42,505,W-84,190,12,fill=1,stroke=0)
    b.c.setFillColor(INK);b.c.setFont('KRB',43);b.c.drawString(63,628,'23 GAMES')
    b.c.setFont('KR',13);b.c.drawString(65,593,'개념을 조작하고, 결과로 확인하는 학습')
    b.c.setFont('KR',10);b.c.drawString(65,555,'자료구조 9  /  알고리즘 6  /  SQL 4  /  데이터 탐색 4')
    b.y=474
    b.section('문서 목적','게임별 목표, 행동 흐름, 3단계 레벨, 예제 정답, 제약, 판정, 검수 기준과 아트 요구를 개발 가능한 수준으로 정의한다.')
    b.section('문서 상태','사용자와 검토할 기획 제안 v1.0. 기존 15개 메뉴 항목을 바탕으로 23개 독립 게임으로 재구성한 목표 명세이며, 23개 모두의 구현 완료를 의미하지 않는다.')
    b.section('이번 산출물','게임 23종 상세 명세, 공통 플레이 규칙, 구현 대응표, 개발 순서, 기존 시안 5종과 신규 시안 9종. 시안은 검토용이며 최종 HUD·정답 숫자·상호작용 에셋은 분리 제작한다.')
    b.section('변경 경계','이번 작업은 문서·시안·다운로드 묶음 제작이다. 섬과 오브젝트의 배치 좌표, 실행 코드, 게임 저장 데이터는 변경하지 않는다.')

    b.start('01  /  CONTENTS','전체 구성과 읽는 법','게임별 상세 페이지는 동일한 항목 순서로 구성')
    b.table([['영역','범위','페이지'],['공통 명세','분류·진입·조작·판정·저장','3-4'],['자료구조','DS-01 ~ DS-09 / 9개','5-13'],['알고리즘','AL-01 ~ AL-06 / 6개','14-19'],['SQL','SQ-01 ~ SQ-04 / 4개','20-23'],['데이터 탐색','DA-01 ~ DA-04 / 4개','24-27'],['개발·검수','대응표, 우선순위, 완료 기준','28-30'],['이미지 시안','기존 5종 + 신규 9종 / 14장','31-37']],[100,315,96])
    b.section('상태 표기','기존 활용: 대응하는 실습이 존재하므로 목표 명세와 비교해 보완한다. 기존 확장: 기존 범위에 새 기능·레벨을 더한다. 기존 요소 분리·확장: 하나의 실습에 들어 있던 기능을 독립 게임으로 발전시킨다. 신규: 독립 씬과 핵심 플레이 구현이 필요하다.')
    b.section('기획 ID와 기존 파일 ID','DS-01, AL-01 등의 ID는 이 문서의 식별자다. 기존 ST01, DS09, ALG01 등 실행 ID를 바로 바꾸는 지시가 아니다. 실제 재편 시 저장 호환을 위한 별도 매핑을 둔다.')
    b.section('분량과 난이도 가정','초급 학습자를 기준으로 게임당 3개 레벨 묶음, 레벨당 3~7분을 목표로 한다. 총 69개는 목표 레벨 묶음 수이며, 방법별 하위 문제는 추가할 수 있다. 실제 소요 시간은 플레이테스트로 조정한다.')
    b.section('확장 범위','자료구조 종합 도전은 24번째 독립 게임으로 세지 않고 자료구조 완료 후 보너스 미션으로 연결한다. 동적 계획법·백트래킹·MST와 SQL 쓰기 질의는 이번 23종 범위에서 제외한다.')

    b.start('02  /  SHARED EXPERIENCE','진입과 공통 플레이','맵 배치를 유지하고 학습 경험을 통일')
    b.section('분야별 책임','자료구조는 저장 형태와 불변식, 알고리즘은 처리 절차와 상태 변화, SQL은 질의와 결과표, 데이터 탐색은 관찰·정제·해석 판단을 평가한다. 같은 집계나 탐색이 등장해도 완료 조건은 각 분야의 학습 목표를 따른다.')
    b.section('진입·복귀','각 섬 컴퓨터에서 E → 해당 분야 메뉴 → 게임 카드 → 레벨 선택 → 설명 → 실습 → 결과. Esc는 일시정지와 복귀 선택을 제공하고, 월드 복귀 시 진입 전 로봇 위치와 카메라를 복원한다. 기존 섬·건물·NPC 좌표는 유지한다.')
    b.section('입력 제안','마우스 선택을 기본으로 하고 기존 이동형 게임은 이동·접근 상호작용을 유지한다. 공통 버튼: 설명(H), 되돌리기(Z), 초기화(R), 메뉴(Esc). 다음 레벨(Enter)은 완료 후에만 활성화한다. 키 표기는 실제 구현과 대조해 확정한다.')
    b.section('한 레벨의 흐름','목표·원본·허용 연산 확인 → 한 단계 실행 → 변경 지점 강조 → 상태·기록 관찰 → 제출 또는 자동 완료 → 결과 해설 → 재시도·다음 단계. 처음 등장하는 규칙은 NPC 안내 또는 1회 예시 동작으로 설명한다.')
    b.section('화면 구성','상단: 목표와 현재 레벨. 중앙: 조작 보드. 옆판: 배열·포인터·질의·거리표 등 학습 상태. 하단: 연산 버튼과 기록. 완료 화면: 정답 근거, 오답 이유, 비교·이동 등 행동 통계. 화면이 작아지면 옆판을 접되 핵심 상태와 입력을 가리지 않는다.')
    b.section('접근성과 피드백','선택·오답·완료를 색만으로 구분하지 않고 윤곽·아이콘·짧은 문구를 함께 사용한다. 애니메이션 중 중복 입력을 막고 속도 조절·즉시 표시를 제공한다. 긴 텍스트는 스크롤 또는 접기 기능으로 읽을 수 있게 한다.')
    b.section('진행 공개','기초는 자유 진입. 응용·도전은 권장 선행 학습만 안내하고 강제 잠금은 기본으로 두지 않는다. 선행 개념을 놓친 경우 관련 게임으로 이동하는 링크를 제공한다.')

    b.start('03  /  SHARED RULES','판정·상태·결과 명세','학습 오류는 설명하고, 정답의 여러 형태는 인정')
    b.section('판정 원칙','단계형 게임은 현재 상태에서 허용된 행동인지 먼저 검사하고 실제 상태를 갱신한다. 제출형 게임은 원본 데이터에서 결과를 다시 계산한다. 화면에 정답처럼 보이는 배치만으로 성공시키지 않는다. 여러 유효 해가 있는 힙·경로·표 결과는 의미 동등성을 검사한다.')
    b.section('오류와 재시도','입력 오류는 원본을 변경하지 않고 이유·관련 상태를 표시한다. 문제 목표를 달성하지 못한 제출은 차이를 알려주되 정답 전체를 바로 노출하지 않는다. 재시도 횟수는 제한하지 않는다. 힌트는 개념 → 다음 판단 기준 → 예시 단계의 순서로 제공한다.')
    b.section('되돌리기·초기화','되돌리기는 마지막 유효 행동 전의 값·연결·인덱스·방문 상태·쿼리·선택을 함께 복원한다. 시도 횟수와 힌트 사용 기록은 유지한다. 초기화는 같은 문제의 초기 상태로 돌아가고, 새 문제 선택만 데이터 시드를 바꾼다.')
    b.section('결과와 평가','완료는 학습 목표 충족으로 판정하며 시간과 클릭 수는 참고 지표로만 사용한다. 결과에는 완료 레벨, 오류 유형, 힌트 사용, 비교·이동·방문 횟수를 표시한다. 효율성 평가는 같은 알고리즘·입력·연산 정의 안에서만 비교한다.')
    b.section('데이터와 재현성','각 문제는 problem_id, version, seed, initial_state, allowed_actions, expected_constraints를 가진다. 값이 같은 원소도 고유 ID로 식별한다. 수치는 원본 정밀도로 계산한 뒤 화면에서 반올림한다. SQL과 데이터 탐색의 NULL·중복·집계 규칙은 문제 설명에 노출한다.')
    b.section('저장·기록','로컬 저장은 기존 게임 ID와 연결한 완료·현재 레벨·설정 중심으로 확장한다. 행동 기록은 문제 ID·행동·전후 상태 요약·판정·시간을 사용한다. 문서 제작 중 외부 전송은 하지 않는다. 서버 연동은 기존 설정과 서비스 요구를 별도로 검토한다.')
    b.section('공통 수용 기준','정상 풀이 1개, 대표 오답 2개 이상, 빈 상태·경계값, 되돌리기, 초기화, 재진입, 월드 복귀를 게임별 확인한다. 1280×720과 1920×1080에서 텍스트 겹침·버튼 잘림·입력 가림이 없어야 한다. SQL 예제는 독립 계산 결과와 대조한다.')

    for g in G:
        b.start(g['id']+'  /  '+g['category'],g['title'],g['status']+'  |  대응: '+g['source']+'  |  권장 선행: '+g['prerequisite'],COLORS[g['category']])
        b.section('학습 목표',g['goal'])
        b.section('핵심 행동 흐름',g['loop'])
        b.text('레벨 구성',HEAD,gap=3)
        for i,s in enumerate(g['levels'],1):b.text(f'{i}. {s}',gap=3)
        b.y-=5
        b.section('예제 입력과 기대 결과',g['example'])
        b.section('규칙·허용 범위',g['rules'])
        b.section('성공·오답 판정',g['judge'])
        b.section('게임별 검수 항목',g['tests'])
        b.section('화면·에셋 요구',g['assets'])
        if g['art']:b.text('시안 파일: '+g['art'],SMALL,gap=3)

    b.start('04  /  IMPLEMENTATION MAP','기존 구현과 개발 범위','현재 존재하는 실행 파일을 기준으로 한 기획 대응표')
    b.table([['기획 ID','기존 대응','개발 범위'],['DS-01~05','ST01~05','기존 규칙·경계값·공통 UI 대조'],['DS-06~08','DS09 / ST07 / ST08','기존 트리·BST·힙 보완'],['DS-09','없음','그래프 구조 독립 게임 신규'],['AL-01~02','ALG02 / ALG01','선형 탐색·선택·삽입 정렬 확장'],['AL-03 / AL-06','없음','분할 정복 정렬·최단 경로 신규'],['AL-04~05','ST06 / ST09','순회·BFS·DFS 기존 활용'],['SQ-01','SQL01_Query','조회 게임으로 분리, 조건·LIMIT 확장'],['SQ-02~04','제한 JOIN 일부 존재','집계·JOIN·서브쿼리 독립 실습 개발'],['DA-01~04','DATA01_Explore','정제 재사용, 점검·통계·차트 분리 확장']],[100,160,251])
    b.section('현재 구현과 목표의 차이','현재 카탈로그는 자료구조 8, 알고리즘 4, SQL 1, 데이터 탐색 1, 종합 도전 1의 15개다. 이 문서는 네 분야 23개를 목표로 하며, 위 표의 기존 대응이 있다고 해서 상세 명세의 모든 기능이 구현된 것은 아니다.')
    b.section('근거 확인 범위','scripts/learning_catalog.gd, MINIGAME_GUIDE.md, scenes/stages 목록과 신규 실습 검증 스크립트를 참조했다. 이번 문서 작업에서 기존 10개 ST 게임 전체를 다시 플레이하거나 신규 기능을 개발·검증한 것으로 보지 않는다.')

    b.start('05  /  DELIVERY PLAN','권장 개발 순서와 완료 기준','순서는 제안이며 일정·인력 추정은 별도 산정')
    b.table([['단계','작업','완료 조건'],['1. 기반','공통 UI·문제 스키마·ID 매핑','기존 저장·월드 복귀 유지'],['2. 기존 보완','자료구조 8종, 순회·BFS·DFS','게임별 정상·오류·경계값 검수'],['3. 기초 확장','그래프 구조, 탐색·기본 정렬','구조와 알고리즘의 판정 분리'],['4. SQL','조회 → 집계 → JOIN → 서브쿼리','예제 결과·NULL·중복 처리 검증'],['5. 데이터','점검 → 정제 → 통계 → 차트','원본 보존·해석 근거 검증'],['6. 심화·마감','분할 정복 정렬·최단 경로·아트','전체 회귀 검사와 사용자 테스트']],[85,215,211])
    b.section('게임 하나의 개발 완료 조건','3개 목표 레벨 묶음, 설명·예제·오답 피드백, 실제 상태 기반 판정, 되돌리기·초기화, 로컬 진행 저장, 월드 진입·복귀, 게임별 검수 통과를 모두 만족한다. 최종 에셋 적용과 읽기 쉬운 화면 검수까지 끝나야 정식 완료로 표시한다.')
    b.section('학습 검증','입문자에게 설명 없이 첫 행동을 찾을 수 있는지, 오답 후 이유를 이해하는지, 완료 후 개념을 한 문장으로 설명할 수 있는지 관찰한다. 과도한 클릭·문구 길이·정답 추측 문제는 레벨과 화면을 조정해 해결한다.')
    b.section('구현 시 확정할 항목','키 배치와 이동형 게임의 입력 통일 수준, 문제 수·플레이 시간, SQL 자유 입력 지원 여부, 난이도 해금, 저장 버전 마이그레이션 방식은 실제 구현 단계에서 확정한다. 현 문서는 블록 조립과 고정 연습 데이터를 기본으로 한다.')

    b.start('06  /  ART HANDOFF','시안 구성과 제작 지침','기존 5장 재사용 + 신규 9장 / 총 14장')
    b.section('신규 9종의 선정 기준','이미 구현된 게임은 신규 배경 제작에서 제외했다. 새 독립 게임이면서 전용 시안이 없는 DS-09, AL-03, AL-06, SQ-02~04, DA-01, DA-03~04에 시안을 제작했다. 제한 JOIN·집계 기능이 기존 실습에 있더라도 독립 게임용 화면은 별도로 필요하다.')
    b.section('기존 시안의 역할','DS-06 트리 구조, AL-01 이진 탐색, AL-02 기본 정렬, SQ-01 SQL 조회, DA-02 정제의 기존 시안을 재사용한다. 기존 ST01~09의 실행 배경은 중복 생성하지 않으며, 이번 ZIP의 신규 시안 수에 포함하지 않는다.')
    b.section('시각 방향','현재 게임과 맞는 푸른 지붕·따뜻한 목재·크림색 석재·청록 바다의 장난감 같은 섬 공방을 유지한다. 조작 보드는 서로 겹치지 않게 구분하고, 기록·상태판을 놓을 여백을 확보한다. SD 로봇과 NPC는 실제 플레이 단계에서 별도 배치한다.')
    b.section('최종 에셋 전환','시안은 평면 합성 이미지다. 배경, 조작 소품, 선택 강조, 화살표, 정답 숫자, 텍스트, HUD를 분리해야 한다. 생성 이미지의 표·연결선·차트는 분위기 참고이며 런타임 판정의 데이터로 사용하지 않는다. 정확한 노선과 결과값은 게임 코드가 그린다.')
    b.section('파일과 추적성','ZIP의 images/new에 신규 9장, images/existing에 기존 5장을 저장한다. image_manifest.json은 게임 ID·제목·경로·신규 여부를 연결하고 prompts.json에는 이미지 생성 도구에 전달한 요청문을 보존한다. 이미지 생성은 기본 내장 도구를 사용했다.')
    b.section('이번 작업의 완료 범위','PDF와 PNG 시안 및 다운로드 ZIP을 제공한다. 실행 게임에 시안을 적용하거나 맵을 재배치하지 않는다. 문서의 신규 기능과 23개 메뉴 재편은 이후 개발 작업이다.')

    arts=[]
    for g in G:
        if not g['art']:continue
        p=(ART/g['art']) if (ART/g['art']).exists() else OLD/g['art']
        if not p.exists():raise FileNotFoundError(p)
        arts.append((g,p,p.parent==ART))
    assert len(arts)==14
    for n in range(0,len(arts),2):
        b.start('07  /  VISUAL CONCEPTS',f'게임 이미지 시안 {n//2+1:02d}','학습용 배경 콘셉트 / 최종 UI와 상호작용 요소는 별도 제작')
        for j,(g,p,new) in enumerate(arts[n:n+2]):
            top=H-135-j*310
            b.c.setFont('KRB',11);b.c.setFillColor(INK);b.c.drawString(42,top,g['id']+'  '+g['title'].split('|')[0].strip())
            b.c.setFont('KR',8);b.c.setFillColor(MUTED);b.c.drawRightString(W-42,top,'신규 제작' if new else '기존 시안 재사용')
            b.image(p,42,top-277,W-84,264)
            b.c.setFont('KR',7.5);b.c.drawString(42,top-291,p.name)
    assert b.page==37,b.page
    b.c.save()
    reader=PdfReader(str(dest));assert len(reader.pages)==37
    text='\n'.join(p.extract_text() or '' for p in reader.pages)
    for g in G:assert g['id'] in text and g['title'] in text,g['id']
    data={'version':'1.0','date':'2026-11-09','status':'기획 제안 / 구현 완료 선언 아님','games':G}
    (OUT/'minigame_spec_data.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    manifest=[dict(game_id=g['id'],title=g['title'],file='images/'+('new/' if new else 'existing/')+p.name,new=new) for g,p,new in arts]
    (OUT/'image_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    readme='''Nodeverse 미니게임 기획 패키지 v1.0\n작성일: 2026-11-09\n\n1. Nodeverse_Minigame_Design_Spec_v1.0.pdf: 네 분야 23개 게임, 37쪽 기획 명세\n2. images/new: 신규 시안 9장\n3. images/existing: 기존 시안 5장 재사용\n4. image_manifest.json: 게임과 이미지 대응표\n5. minigame_spec_data.json: 상세 명세의 수정 가능한 원본 데이터\n6. prompts/: 내장 이미지 생성 도구에 사용한 요청문\n\n기획은 목표 범위이며 23개 게임이 모두 구현되었다는 뜻이 아닙니다.\n시안은 검토용입니다. 최종 배경·소품·UI 분리와 실제 게임 적용은 포함하지 않습니다.\n기존 ST 게임의 실행 배경은 중복 제작하지 않았습니다.\n게임 코드, 섬과 오브젝트의 배치 좌표는 변경하지 않았습니다.\n'''
    (OUT/'PACKAGE_README.txt').write_text(readme,encoding='utf-8-sig')
    zpath=OUT/'Nodeverse_Minigame_Design_Package_v1.0.zip'
    with zipfile.ZipFile(zpath,'w',zipfile.ZIP_DEFLATED) as z:
        for p in [dest,OUT/'minigame_spec_data.json',OUT/'image_manifest.json',OUT/'PACKAGE_README.txt']:z.write(p,p.name)
        for g,p,new in arts:z.write(p,'images/'+('new/' if new else 'existing/')+p.name)
        for p in [OLD/'prompts.json',ART/'prompts.json']:
            if p.exists():z.write(p,'prompts/'+('existing_' if p.parent==OLD else 'new_')+'prompts.json')
    with zipfile.ZipFile(zpath) as z:
        assert z.testzip() is None
        assert len([n for n in z.namelist() if n.startswith('images/new/')])==9
        assert len([n for n in z.namelist() if n.startswith('images/existing/')])==5
    print(json.dumps(dict(pdf=str(dest),pages=b.page,games=len(G),images=len(arts),zip=str(zpath),zip_mb=round(zpath.stat().st_size/1024**2,2)),ensure_ascii=False))

if __name__=='__main__':generate()
