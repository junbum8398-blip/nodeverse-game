# NODEVERSE 3D 맵 직접 수정 가이드

3D 월드는 에디터에 미리 배치된 씬이 아니라, 게임을 시작할 때 **`scripts/nodeverse_world.gd` 코드가 섬·소품·NPC를 하나씩 만들어 배치**합니다.
그래서 `scenes/NodeverseWorld.tscn`을 에디터로 열어도 섬이 보이지 않습니다. 맵을 바꾸려면 아래 코드의 숫자를 고치면 됩니다.

- 편집: `open_editor.bat` → 파일 시스템에서 `scripts/nodeverse_world.gd` 더블클릭 (메모장·VS Code로 고쳐도 됩니다)
- 확인: `play_game.bat` 실행 (저장 후 다시 실행해야 반영돼요)

> **로딩 속도(월드 굽기)**: 한 번 만든 월드는 `%APPDATA%\Godot\app_userdata\NODEVERSE 3D Assets\world_bake.scn`에 저장돼서 다음 실행부터 약 2~3초 만에 열립니다.
> 스크립트·에셋 파일을 고치면 자동으로 감지해서 **고친 직후 첫 실행만 약 15~17초** 걸리고(다시 굽기), 그다음부터 다시 빨라집니다. 이상하면 위 두 파일(`world_bake.scn`, `world_bake.json`)을 지우면 처음부터 다시 만듭니다.

---

## 1. 좌표 규칙

| 축 | 뜻 |
|---|---|
| `x` | + 동쪽(SQL 섬 쪽), − 서쪽(자료구조 섬 쪽) |
| `z` | + 남쪽(입문 섬 쪽), − 북쪽(알고리즘·종합 도전 섬 쪽) |
| `y` | 높이. 섬 바닥 높이는 상수 `TOP`(= 1.0)를 그대로 쓰면 됩니다 |
| 회전 | 도(degree) 단위, 위에서 볼 때 Y축 회전 |

**좌표 찾는 법:** 게임 플레이 중 **F3** 키 → 화면에 `위치 Vector3(-12.6, TOP, 17.0)` 형태로 로봇의 현재 좌표가 표시됩니다.
원하는 자리로 로봇을 걸어가서 그 값을 그대로 코드에 붙여 넣으면 됩니다. (**1~7** 키는 섬 빠른 이동)

---

## 2. 무엇을 어디서 고치나

`nodeverse_world.gd` 안에서 `Ctrl+F`로 아래 이름을 찾으세요.

| 바꾸고 싶은 것 | 찾을 이름 | 설명 |
|---|---|---|
| 섬 위치·크기·모양 | `const ISLANDS` | `center`(섬 중심 x,z), `rx`/`rz`(가로/세로 반지름), `seed`(가장자리 울퉁불퉁한 모양 – 숫자 바꾸면 모양이 바뀜) |
| 섬끼리 잇는 다리 | `func _build_bridges` | `_edge_point(섬중심, 방향)`으로 양쪽 섬 가장자리를 찾아 `arch_bridge(..., 폭, ...)`로 연결 |
| 섬 위의 건물·소품 | `func _build_main_island`, `_build_ds_island`, `_build_algo_island`, `_build_sql_island`, `_build_intro_island`, `_build_data_island`, `_build_challenge_island` | 섬마다 함수 하나 |
| 돌길(통로) | 각 섬 함수 안의 `_path(...)` | 점들을 이은 돌길. 길 위에는 나무가 자동으로 안 생김 |
| 나무 자동 배치 | `func _build_nature` | 섬 가장자리에 자동으로 심음. 특정 자리에 나무가 안 생기게 하려면 아래 `_reserve` 사용 |
| NPC 위치·방향·대사 | `const NPC_DEFS` | `pos`, `rot`, `dialog` |
| 컴퓨터(2D 미니게임) 위치 | `var computer_positions` | 좌표 추가하면 컴퓨터가 하나 더 생김 |
| 섬 빠른 이동(1~7키) 도착점 | `KEY_1` ~ `KEY_7` | `teleport_to(Vector3(...))` |
| 타이틀 화면 투어 카메라 | `const TOUR_WAYPOINTS` | `focus`(바라볼 점), `yaw`/`pitch`/`dist` |
| 화면 위 섬 이름 판정 경계 | `func _zone_of` | 섬을 옮기면 여기 경계 숫자도 같이 맞춰 주세요 |

---

## 3. 소품 하나 배치하기 (가장 많이 쓰는 줄)

```gdscript
_spawn("에셋이름", Vector3(x, TOP, z), 회전각도, 크기, 충돌여부)
```

예) 입문 섬 안내판:

```gdscript
_spawn("OBJ41_sign_intro", Vector3(-12.6, TOP, 17.0), 45.0, 1.0, true)
```

- **에셋 이름**: `scenes/assets/` 폴더의 파일 이름에서 `.tscn`을 뺀 것 (예: `21_tree_short`, `06_lamp`, `OBJ02_cottage_blue`)
  - 어떤 에셋이 있는지 눈으로 보려면 `open_showcase.bat` (에셋 갤러리)
- **충돌여부** `true`: 로봇이 통과 못 함 / `false`: 통과 가능(바닥 장식 등)
- **지우기**: 그 줄 맨 앞에 `#`을 붙이면 꺼집니다 (나중에 `#`만 지우면 되살아남)
- **옮기기**: `Vector3(x, TOP, z)` 숫자만 바꾸기

### 나무가 생기지 않게 자리 비우기

```gdscript
_reserve(Vector2(x, z), 반지름)   # 예: _reserve(Vector2(-13.2, 13.2), 1.6)
```

`_build_nature`보다 먼저 실행되는 섬 함수 안에 넣어야 효과가 있어요 (섬 함수들은 모두 먼저 실행됩니다).

### 충돌 상자만 따로 두기 (보이지 않는 벽)

```gdscript
_collider(Vector3(x, TOP + 0.5, z), Vector3(가로, 높이, 세로))
```

---

## 4. NPC 옮기기

`const NPC_DEFS`에서 해당 NPC의 `pos`, `rot`만 바꾸면 됩니다.

```gdscript
{
	"id": "NPC01_array_keeper",       # 모델: scenes/npc/NPC01_array_keeper.tscn
	"name": "배열 관리자",              # 머리 위·대화창 이름
	"pos": Vector3(-18.5, TOP, -1.5), # 위치
	"rot": 90.0,                      # 바라보는 방향(도)
	"dialog": "..."                   # E 로 말 걸었을 때 대사 (\n 은 줄바꿈)
},
```

NPC 모델 자체를 바꾸려면 `models/npc/<id>.glb`를 교체한 뒤 아래 두 개를 순서대로 실행하세요 (부품 합치기 → NPC 씬 다시 만들기).

```bash
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://scripts/tools/merge_npc_parts.gd
python tools/write_npc_v2_scenes.py
```

---

## 5. 주의할 점

- **물 추락 방지**는 발밑에 땅이 있는지로 판단해요. 섬을 옮기거나 다리를 지우면 그 길로는 못 가게 됩니다(빠지지는 않음).
- 섬 `center`를 바꾸면 그 섬의 소품·NPC·컴퓨터 좌표, `_build_bridges`의 섬 중심 값, `_zone_of` 경계, 빠른 이동 좌표도 함께 옮겨야 해요.
- 소품을 바다 위(섬 밖)에 두면 떠 있게 보입니다. F3 좌표로 섬 안인지 확인하세요.
- 실행했는데 섬이 안 나오고 멈추면 콘솔(검은 창)에 빨간 `SCRIPT ERROR` 줄이 뜹니다. 대개 괄호·쉼표 빠짐이에요. 방금 고친 줄을 확인하세요.
- 고치기 전에 `backup_3d_project.bat`로 백업해 두면 안전해요.

---

## 6. 2D 스테이지(ST01)는 에디터에서 바로 편집

`scenes/stages/ST01_Array.tscn`은 일반 Godot 씬이라 에디터에서 드래그로 옮길 수 있어요.

- `Field/World/Slot0~4`, `Tray`, `Bin`: 상호작용 지점 (Area2D)
- `Field/World/Npc`: 보관소 관리인 위치
- `Field/Walls/Boundary`: 로봇이 걸을 수 있는 경계 (다각형 점을 드래그)

주의: `python tools/write_play_scenes.py`를 다시 실행하면 이 씬을 새로 만들면서 에디터에서 고친 내용을 덮어씁니다. 에디터로 고친 뒤에는 그 스크립트를 실행하지 마세요.
