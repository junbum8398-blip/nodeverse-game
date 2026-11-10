"""Merge user-provided originals with non-overlapping concepts, preserving PNG bytes."""
from pathlib import Path
import json,zipfile,hashlib,io
from PIL import Image
from pypdf import PdfReader
from build_minigame_spec import Book,G,ROOT,W,H,INK,MUTED,HEAD,SMALL,COLORS

OUT=ROOT/'output/pdf/merged_v1.1'
OUT.mkdir(parents=True,exist_ok=True)
SOURCE=Path('C:/Users/kingd/Desktop/NODEVERSE_자료구조_스테이지10장_NPC10종.zip')
OLD=ROOT/'reference/new_minigame_concepts'
NEW=ROOT/'reference/minigame_spec_concepts'
STEMS=['ST01_array','ST02_linked_list','ST03_stack','ST04_queue_deque','ST05_hash','ST06_binary_tree','ST07_bst','ST08_heap','ST09_graph','ST10_integrated']
TITLES=['배열','연결 리스트','스택','큐·덱','해시 테이블','트리 구조·트리 순회','이진 탐색 트리','힙·우선순위 큐','그래프 구조·BFS·DFS','자료구조 종합 도전']
original_map={'DS-01':0,'DS-02':1,'DS-03':2,'DS-04':3,'DS-05':4,'DS-06':5,'DS-07':6,'DS-08':7,'DS-09':8,'AL-04':5,'AL-05':8}
excluded={'DS09_tree_structure.png','DS_GRAPH.png'}
files={}; manifest=[]; stages=[]
def sha(data):return hashlib.sha256(data).hexdigest()
def add(name,data):
    assert name not in files
    files[name]=data
with zipfile.ZipFile(SOURCE) as src:
    for i,stem in enumerate(STEMS):
        names=[n for n in src.namelist() if n.startswith(stem+'_') and n.endswith('.png')]
        assert len(names)==1,(stem,names)
        entry=names[0];data=src.read(entry);target=f'images/user_stages/{stem}.png'
        add(target,data)
        ids=[k for k,v in original_map.items() if v==i]
        stages.append(dict(title=TITLES[i],ids=ids or ['BONUS'],file=target,origin='사용자 원본',sha256=sha(data),source_entry=entry))
    npcs=[]
    for name in src.namelist():
        if name.startswith('npc/') and name.endswith('.png'):
            target='images/user_npc/'+Path(name).name;data=src.read(name);add(target,data)
            npcs.append(dict(file=target,origin='사용자 원본 NPC',sha256=sha(data),source_entry=name))
    for name in ['generation-prompts.json','npc-generation-prompts.json','manifest.json','README.txt']:
        add('source_metadata/'+name,src.read(name))
assert len(npcs)==10

for g in G:
    if g['id'] in original_map:
        g['art']=stages[original_map[g['id']]]['file']
        continue
    if g['art']:
        name=g['art'];assert name not in excluded
        p=NEW/name if (NEW/name).exists() else OLD/name
        target='images/additional/'+name;data=p.read_bytes();add(target,data)
        stages.append(dict(title=g['title'].split('|')[0].strip(),ids=[g['id']],file=target,origin='추가 시안',sha256=sha(data)))
        g['art']=target
assert len(stages)==22
assert len([s for s in stages if s['origin']=='추가 시안'])==12
for folder,label,drop in [(OLD,'earlier',{'DS09_tree_structure'}),(NEW,'later',{'DS_GRAPH'})]:
    data=json.loads((folder/'prompts.json').read_text(encoding='utf-8'))
    # Different previous prompt schemas are preserved, with excluded prompts clearly removed.
    if isinstance(data,list):data=[x for x in data if x.get('id') not in drop]
    elif isinstance(data,dict):
        for key in ['images','prompts','jobs']:
            if isinstance(data.get(key),list):data[key]=[x for x in data[key] if x.get('id') not in drop]
        data['excluded_concepts']=sorted(drop)
    add('prompts/'+label+'_prompts.json',json.dumps(data,ensure_ascii=False,indent=2).encode('utf-8'))

# Local review assets are extracted only to a controlled workspace directory.
cache=ROOT/'tmp/pdfs/merged_assets';cache.mkdir(parents=True,exist_ok=True)
for s in stages:
    data=files[s['file']];p=cache/Path(s['file']).name;p.write_bytes(data)
    Image.open(io.BytesIO(data)).convert('RGB').save(p.with_suffix('.jpg'),quality=90,optimize=True)

pdf=OUT/'Nodeverse_Minigame_Design_Spec_v1.1_Merged.pdf'
b=Book(pdf,version='1.1')
b.start('MERGED EDITION  /  v1.1','미니게임 기획 명세','사용자 기존 시안 우선 통합본 / 2026.11.09')
b.section('통합 결과','자료구조·알고리즘·SQL·데이터 탐색의 23개 게임 기획과 스테이지 시안 22장, NPC 원본 10종을 한 패키지로 정리했다. 원본 PNG는 다시 그리거나 수정하지 않았다.')
b.table([['구분','수량','통합 원칙'],['사용자 스테이지','10장','ST01~ST10 원본 모두 유지'],['추가 스테이지','12장','직전 패키지 14장에서 겹치는 2장 제외'],['사용자 NPC','10종','원본 RGBA와 파일 내용 유지'],['제외한 시안','2장','별도 트리·그래프 구조 시안 제외']],[125,70,316])
b.section('겹치는 시안의 교체','DS09_tree_structure.png 대신 사용자 ST06_binary_tree를 사용한다. DS_GRAPH.png 대신 사용자 ST09_graph를 사용한다. 트리·그래프는 같은 배경을 구조 편집과 순회·탐색 모드에서 공유한다.')
b.section('구현과 문서의 관계','사용자가 클로드로 이미 구현한 미니게임을 우선 유지한다. 게임별 상세는 목표 기획이며, 실제 구현 상태를 이번 통합 작업에서 다시 검사한 것은 아니다. 기존 게임을 이 문서에 맞춰 전부 재개발하라는 뜻이 아니다.')
b.section('작업 경계','문서와 이미지 패키지를 통합했다. 게임 코드, 저장 데이터, 섬과 오브젝트 배치 좌표는 변경하지 않았다. 이전 ZIP은 이 통합본으로 대체해 사용한다.')

b.start('01  /  CONTENTS','전체 구성과 이미지 대응','같은 배경을 공유하는 게임은 이미지 파일도 하나로 관리')
b.table([['범위','내용','쪽'],['공통 명세','진입·조작·판정·저장','3-4'],['자료구조 9개','DS-01~DS-09','5-13'],['알고리즘 6개','AL-01~AL-06','14-19'],['SQL 4개','SQ-01~SQ-04','20-23'],['데이터 탐색 4개','DA-01~DA-04','24-27'],['통합 안내','원본 대응·개발 기준·파일 안내','28-30'],['스테이지 시안 22장','사용자 10장 + 추가 12장','31-41']],[125,305,81])
b.section('스테이지 수와 게임 수','사용자 ST06 한 장을 트리 구조·트리 순회에, ST09 한 장을 그래프 구조·BFS·DFS에 사용한다. ST10은 별도 분야가 아닌 자료구조 종합 보너스다. 따라서 스테이지 이미지 수와 게임 기획 수는 일치하지 않는다.')
b.section('상태 표기의 의미','상세 페이지의 기존 활용·확장·신규 표기는 최초 기획 작성 당시 파일 대응에 따른 분류다. 이후 클로드로 구현된 내용까지 반영한 완료 현황이 아니다. 개발 전 실제 구현과 대조하고 부족한 부분만 보완한다.')
b.section('식별자','DS-01·AL-01 등은 기획 ID다. ST01·ALG01 등 기존 실행 ID와 저장 기록은 유지하고 필요할 때 별도 매핑한다. 게임당 기초·응용·도전 3단계는 목표 레벨 구성으로, 실제 문제 수는 조정할 수 있다.')

b.start('02  /  SHARED EXPERIENCE','진입과 공통 플레이','기존 구현과 맵을 유지하며 필요한 부분만 보완')
for label,text in [
('분야별 책임','자료구조는 저장 형태와 불변식, 알고리즘은 처리 절차, SQL은 질의와 결과표, 데이터 탐색은 관찰·정제·해석 판단을 평가한다. 같은 배경이나 데이터라도 목표에 따라 조작과 판정을 구분한다.'),
('진입·복귀','섬 컴퓨터 E → 분야 메뉴 → 게임 선택 → 설명 → 실습 → 결과. 월드로 돌아오면 진입 전 위치와 카메라를 복원한다. 기존 섬·NPC·건물 좌표는 변경하지 않는다.'),
('조작 원칙','이미 구현된 이동형 게임의 이동·접근 상호작용을 유지한다. 클릭형 게임도 실제 상태를 조작하게 한다. 공통 제안 키는 H 설명, Z 되돌리기, R 초기화, Esc 메뉴, 완료 후 Enter 다음 단계다. 실제 키 배치는 구현과 대조한다.'),
('플레이 흐름','목표·원본·허용 연산 확인 → 한 단계 실행 → 변경 부분 강조 → 상태 관찰 → 제출 또는 완료 → 결과 해설. 첫 규칙은 NPC 안내나 예시 동작으로 설명한다.'),
('화면 구성','상단 목표, 중앙 조작 보드, 옆판 상태, 하단 연산·기록을 둔다. 결과에는 정답 근거·오답 이유·행동 통계를 표시한다. 원본 시안의 HUD는 구현 상황에 맞춰 별도 요소로 관리한다.'),
('접근성','색과 함께 윤곽·아이콘·문구로 상태를 구분한다. 애니메이션 중 중복 입력을 막고 속도 조절·즉시 표시를 제공한다. 긴 설명은 접기·스크롤로 읽게 한다.'),
('선행 학습','입문 게임은 자유 진입을 기본으로 한다. 관련 개념이 부족하면 선행 게임을 안내하되 강제 해금 조건은 별도로 정한다.')]:b.section(label,text)

b.start('03  /  SHARED RULES','판정·상태·결과 명세','완료 판정은 그림이 아닌 실제 학습 상태를 기준으로 한다')
for label,text in [
('정답 판정','단계형은 현재 상태에서 허용된 행동인지 검사한 뒤 갱신한다. 제출형은 원본으로 결과를 다시 계산한다. 힙·경로처럼 여러 정답이 있으면 의미 동등성을 인정한다.'),
('오류 처리','잘못된 입력은 상태를 바꾸지 않고 이유를 설명한다. 제출 오답에는 차이를 알려주고, 힌트는 개념 → 판단 기준 → 예시 단계 순으로 제공한다. 재시도 횟수는 제한하지 않는다.'),
('되돌리기·초기화','마지막 유효 행동 전의 값·연결·인덱스·방문·질의·선택을 함께 복원한다. 시도·힌트 기록은 유지한다. 초기화는 같은 문제의 시작 상태로 되돌린다.'),
('평가','시간과 클릭 수는 참고 지표다. 완료·오류 유형·힌트 사용·비교·이동·방문 횟수를 표시한다. 서로 다른 알고리즘의 성능을 비교할 때는 입력과 연산 정의를 함께 보여준다.'),
('재현성','문제 ID·버전·시드·초기 상태·허용 행동·기대 제약을 보존한다. 값이 같은 원소도 고유 ID를 둔다. 수치는 계산 후 반올림하며 NULL·중복·집계 기준을 화면에 명시한다.'),
('저장','기존 실행 ID와 진행 기록을 유지한다. 새 기획 ID와 저장 ID는 매핑한다. 이번 패키지 제작은 저장 변경이나 외부 전송을 수행하지 않는다.'),
('공통 검수','정상 풀이, 대표 오답, 빈 상태·경계값, 되돌리기·초기화·재진입·월드 복귀를 확인한다. 1280×720과 1920×1080에서 입력 가림·문구 잘림·겹침이 없어야 한다.')]:b.section(label,text)

for g in G:
    b.start(g['id']+'  /  '+g['category'],g['title'],g['status']+' (최초 기획 기준)  |  권장 선행: '+g['prerequisite'],COLORS[g['category']])
    b.section('학습 목표',g['goal']);b.section('핵심 행동 흐름',g['loop'])
    b.text('레벨 구성',HEAD,gap=3)
    for i,s in enumerate(g['levels'],1):b.text(f'{i}. {s}',gap=3)
    b.y-=5
    for label,key in [('예제 입력과 기대 결과','example'),('규칙·허용 범위','rules'),('성공·오답 판정','judge'),('게임별 검수 항목','tests')]:b.section(label,g[key])
    assets=g['assets']
    if g['id']=='DS-06':assets='사용자 ST06 계층형 자료실 원본을 공유한다. 구조 편집 모드의 연결 소켓·루트·리프 표식만 필요한 경우 추가한다.'
    if g['id']=='DS-09':assets='사용자 ST09 연결망 조사실 원본을 공유한다. 구조 편집 모드의 연결·방향·가중치 표시만 필요한 경우 추가한다.'
    g['assets']=assets
    b.section('화면·에셋 요구',assets)
    if g['art']:b.text('사용 시안: '+Path(g['art']).name,SMALL,gap=3)

b.start('04  /  ORIGINALS MAP','사용자 원본과 게임 대응','기존 10개 스테이지 이미지의 활용 위치')
b.table([['사용자 원본','기획 게임','활용'],['ST01~ST05','DS-01~DS-05','배열·리스트·스택·큐·해시'],['ST06_binary_tree','DS-06 / AL-04','트리 구조와 트리 순회 공유'],['ST07_bst','DS-07','이진 탐색 트리'],['ST08_heap','DS-08','힙·우선순위 큐'],['ST09_graph','DS-09 / AL-05','그래프 구조와 BFS·DFS 공유'],['ST10_integrated','보너스','자료구조 종합 도전']],[145,155,211])
b.section('별도 추가 시안 유지','배열 이진 탐색은 BST와 구분한다. 기본 정렬은 힙과 구분하고, 최단 경로는 가중치·거리표·경로 갱신이 필요하므로 추가 시안을 유지한다. SQL·데이터 탐색도 별도 주제다.')
b.section('제외 항목','직전 최종 패키지의 DS09_tree_structure.png와 DS_GRAPH.png를 통합 ZIP과 PDF에서 제외했다. 기존 작업 폴더의 원본 파일을 삭제하지는 않았으며, 배포용 통합본에는 포함하지 않았다.')
b.section('NPC','사용자가 제공한 NPC00~NPC09의 10개 PNG를 원본 그대로 포함했다. 새 NPC를 생성하거나 기존 캐릭터를 변경하지 않았다.')

b.start('05  /  DEVELOPMENT GUIDANCE','기존 구현 우선 적용','클로드로 완성한 미니게임을 유지하는 것을 기준으로 한다')
b.section('검토 순서','실제 실행 게임의 메뉴·기능·정답 판정 확인 → 이 문서와 대응 → 이미 구현된 내용 유지 → 부족한 기능·설명·이미지만 보완한다. 명세에 신규로 표기되어 있어도 현재 구현되어 있다면 재개발하지 않는다.')
b.section('개발이 필요한 경우의 순서','공통 상태·복귀·저장 확인 → 자료구조와 탐색의 경계값 보완 → SQL 조회·집계·JOIN·서브쿼리 → 데이터 점검·정제·통계·차트 → 분할 정복 정렬·최단 경로 순으로 검토한다. 개발 일정은 별도로 산정한다.')
b.section('게임별 완료 기준','실제 상태 기반 판정, 설명·예제·오답 피드백, 되돌리기·초기화, 진행 저장과 월드 복귀가 안정적으로 작동해야 한다. 게임별 명세의 경계값 검사와 화면 검수가 통과하면 완료로 표시한다.')
b.section('아트 적용','이미 구현된 게임은 기존 배경·오브젝트·상호작용을 유지한다. 새 시안은 부족한 게임의 방향을 정하는 참고 자료다. 시안에 맞추기 위해 맵 배치나 완성된 게임을 임의로 바꾸지 않는다.')
b.section('학습 확인','입문자가 첫 행동을 이해하는지, 오류 후 이유를 설명할 수 있는지, 완료 뒤 개념을 한 문장으로 말할 수 있는지 확인한다. 소요 시간과 난이도는 실제 플레이 결과로 조정한다.')

b.start('06  /  PACKAGE GUIDE','통합 파일 구성과 검증','원본 유지 · 중복 제외 · 다운로드 파일 일원화')
b.table([['폴더·파일','내용'],['images/user_stages/','사용자 원본 ST01~ST10 / 10장'],['images/user_npc/','사용자 원본 NPC00~NPC09 / 10종'],['images/additional/','겹치지 않는 추가 시안 / 12장'],['image_manifest.json','게임 대응·출처·파일 해시'],['minigame_spec_data.json','23개 게임의 상세 기획 데이터'],['prompts/','추가 시안 생성 요청 기록'],['source_metadata/','사용자 ZIP의 원본 설명·프롬프트·목록']],[180,331])
b.section('원본 보존','사용자 ZIP의 이미지 바이트와 통합본을 SHA-256으로 대조했다. 깨져 보이는 기존 한글 파일명은 ST01_array.png 같은 영문 식별자로 정리했으며 이미지 내용은 유지했다. 원본 ZIP 경로와 내부 이름은 대응표에 보존했다.')
b.section('수량과 중복','스테이지 PNG 22장과 NPC PNG 10종, 합계 32개다. 공유하는 ST06·ST09는 각각 한 파일만 넣었다. 제외한 트리·그래프 대체 시안은 ZIP에 없으며, 모든 파일 경로는 중복 없이 구성했다.')
b.section('사용 유의','기획 제안과 이미지 시안은 구현 완료 현황이 아니다. 원본 시안의 숫자·배치·HUD도 현재 게임과 대조해 적용한다. 이번 통합본은 게임 실행 파일이나 빌드 결과물을 포함하지 않는다.')

for n in range(0,len(stages),2):
    b.start('07  /  STAGE CONCEPTS',f'통합 스테이지 시안 {n//2+1:02d}','사용자 원본 우선 / 공유 배경은 한 번만 수록')
    for j,s in enumerate(stages[n:n+2]):
        top=H-135-j*310
        b.c.setFillColor(INK);b.c.setFont('KRB',11);b.c.drawString(42,top,' / '.join(s['ids'])+'  '+s['title'])
        b.c.setFillColor(MUTED);b.c.setFont('KR',8);b.c.drawRightString(W-42,top,s['origin'])
        b.image(cache/Path(s['file']).with_suffix('.jpg').name,42,top-277,W-84,264)
        b.c.setFont('KR',7.5);b.c.drawString(42,top-291,Path(s['file']).name)
assert b.page==41
b.c.save()
reader=PdfReader(str(pdf));assert len(reader.pages)==41
text='\n'.join(p.extract_text() or '' for p in reader.pages)
for g in G:assert g['id'] in text and g['title'] in text
meta={'version':'1.1','source_zip':str(SOURCE),'stage_count':22,'npc_count':10,'excluded_images':sorted(excluded),'stages':stages,'npcs':npcs}
add('image_manifest.json',json.dumps(meta,ensure_ascii=False,indent=2).encode('utf-8'))
add('minigame_spec_data.json',json.dumps({'version':'1.1','status':'기존 구현 우선 / 기획 제안','games':G},ensure_ascii=False,indent=2).encode('utf-8'))
readme='''Nodeverse 미니게임 기획·시안 통합본 v1.1\n\n사용자 원본 스테이지 10장 + 추가 시안 12장 + 사용자 NPC 10종.\n겹치는 DS09_tree_structure.png, DS_GRAPH.png는 제외했습니다.\n트리 구조·순회는 ST06, 그래프 구조·탐색은 ST09를 공유합니다.\n원본 이미지는 바이트를 유지하고 깨진 한글 파일명만 영문 ID로 정리했습니다.\nPDF 41쪽, 23개 게임 기획과 스테이지 이미지 22장을 포함합니다.\n클로드로 이미 구현된 미니게임을 우선 사용하고 없는 기능만 보완하세요.\n본 통합 작업은 게임 코드·맵 좌표·실행 에셋을 변경하지 않았습니다.\n직전 v1.0 ZIP 대신 이 v1.1 통합 ZIP을 사용하세요.\n'''
add('README.txt',readme.encode('utf-8-sig'))
add(pdf.name,pdf.read_bytes())
for name in ['image_manifest.json','minigame_spec_data.json','README.txt']:(OUT/name).write_bytes(files[name])
zpath=OUT/'Nodeverse_Minigame_Complete_Package_v1.1.zip'
with zipfile.ZipFile(zpath,'w',zipfile.ZIP_DEFLATED) as z:
    for name,data in files.items():z.writestr(name,data)
with zipfile.ZipFile(zpath) as z,zipfile.ZipFile(SOURCE) as src:
    assert z.testzip() is None
    assert len([n for n in z.namelist() if n.endswith('.png')])==32
    assert len(z.namelist())==len(set(z.namelist()))
    for s in stages[:10]+npcs:assert z.read(s['file'])==src.read(s['source_entry'])
    assert not any(Path(n).name in excluded for n in z.namelist())
print(json.dumps({'pdf':str(pdf),'zip':str(zpath),'pages':41,'stages':22,'npcs':10,'zip_mb':round(zpath.stat().st_size/1024**2,2)},ensure_ascii=False))
