# 미니게임 구성과 플레이 안내

네 분야 23개 실습과 자료구조 종합 보너스 1개로 구성합니다. 실행 ID(ST01, DS09, ALG01 ...)는 진행 기록과 연결되어 있어 바꾸지 않고, 기획 ID(DS-01 ...)는 PDF 명세의 식별자입니다. 모든 실습은 ST01처럼 시안을 게임판으로 쓰고 로봇이 걸어 다닙니다.

| 기획 ID | 게임 | 실행 ID | 시안 배경 |
|---|---|---|---|
| DS-01 | 배열 | ST01 | ST01 |
| DS-02 | 연결 리스트 | ST02 | ST02 |
| DS-03 | 스택 | ST03 | ST03 |
| DS-04 | 큐·덱 | ST04 | ST04 |
| DS-05 | 해시 테이블 | ST05 | ST05 |
| DS-06 | 트리 구조 | DS09 | ST06 |
| DS-07 | 이진 탐색 트리 | ST07 | ST07 |
| DS-08 | 힙·우선순위 큐 | ST08 | ST08 |
| DS-09 | 그래프 구조 | DS10 | ST09 |
| AL-01 | 탐색 | ALG02 | ALG02 |
| AL-02 | 기본 정렬 | ALG01 | ALG01 |
| AL-03 | 분할 정복 정렬 | ALG03 | ALG03 |
| AL-04 | 트리 순회 | ST06 | ST06 |
| AL-05 | 그래프 탐색 | ST09 | ST09 |
| AL-06 | 최단 경로 | ALG04 | ALG04 |
| SQ-01 | 기록 조회 | SQL01 | SQL01 |
| SQ-02 | 그룹 집계 | SQL02 | SQL02 |
| SQ-03 | 테이블 연결 | SQL03 | SQL03 |
| SQ-04 | 서브쿼리 | SQL04 | SQL04 |
| DA-01 | 데이터 점검 | DATA02 | DATA02 |
| DA-02 | 데이터 정제 | DATA01 | DATA01 |
| DA-03 | 통계 비교 | DATA03 | DATA03 |
| DA-04 | 시각화 해석 | DATA04 | DATA04 |
| 보너스 | 자료구조 종합 | ST10 | ST10 |

## 조작

- 섬 컴퓨터에서 E를 누르면 그 섬 분야의 실습 목록만 열립니다. 다른 분야는 해당 섬의 컴퓨터로 가야 합니다. Esc 또는 '3D 월드로 복귀'로 진입 전 위치로 돌아옵니다.
- 공통: WASD 이동, E 상호작용, Z 되돌리기, R 초기화, H 도움말, Enter 다음 레벨, Esc 메뉴. 신규·확장 14종은 F로 힌트(개념 → 판단 기준 → 예시)를 봅니다.
- 트리: 부모와 자식에서 E를 누른 뒤 1 왼쪽, 2 오른쪽, 3 해제. 그래프: 출발과 도착에서 E를 누른 뒤 1 추가, 2 삭제, 3·4 비용 조절.
- 숫자 입력 칸은 E로 고른 뒤 숫자 키로 입력합니다. SQL 원본 기록은 작업장 카드에 표시되며 집어도 원본은 보존됩니다. 데이터 탐색의 표 보기 지점에서는 표를 크게 볼 수 있습니다.

## SQL 5x5 서랍 색칠 (Nodeverse_SQL_5x5_Design_Spec v2.0)

작은 로봇을 WASD로 한 칸씩 옮기고 E로 붓을 찍습니다. 붓 한 번이 SQL 한 연산이 되어 오른쪽 LIVE SQL과 결과가 즉시 바뀝니다. 숫자키로 도구를 고르고(3은 지우개), Z 취소, X 처음으로, F 힌트, Enter 제출입니다. 화면·색칠·SQL·결과는 `sql_query_model.gd`의 같은 상태에서 계산합니다.

## 파일

- 메뉴 목록: `scripts/learning_catalog.gd`, 메뉴 화면: `scripts/main_menu.gd`
- 걷기 실습 공통: `scripts/minigames/learning_lab.gd` (`scripts/play/walk_stage.gd`를 이어받음)
- 진행 기록: `user://minigame_progress.json`에 게임별 최고 별 수만 저장합니다. 계정·월드 저장 파일과 분리되어 있습니다.

## 검사

```bash
Godot --headless --path . --script res://scripts/tools/test_sql_drawer.gd
Godot --headless --path . --script res://scripts/tools/test_learning_labs.gd
Godot --headless --path . --script res://scripts/tools/test_lab_walk.gd
Godot --headless --path . --script res://scripts/tools/test_stage_rules.gd
Godot --path . --resolution 1280x720 res://scenes/AutoplayStages.tscn
```
