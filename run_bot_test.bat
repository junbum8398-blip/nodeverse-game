@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ============================================================
echo   NODEVERSE 시나리오 기반 자동화 봇(시뮬레이터) 기능 검증 실행
echo ============================================================
python tools\run_scenario_verification.py --scenario scenarios\default_full_scenario.json
if exist "output\reports\NODEVERSE_자동화봇_테스트결과서.pdf" (
    start "" "output\reports\NODEVERSE_자동화봇_테스트결과서.pdf"
)
pause
