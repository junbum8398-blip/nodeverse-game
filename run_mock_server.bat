@echo off
chcp 65001 > nul
title NODEVERSE Telemetry Mock Server
echo [NODEVERSE] 미니게임 데이터 수신 테스트 서버를 시작합니다...
python "%~dp0tools\mock_receiver_server.py" 8000
pause
