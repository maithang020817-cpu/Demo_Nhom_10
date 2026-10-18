@echo off
chcp 65001 >nul
title Goi mon QR
cd /d "%~dp0server"
echo Dang mo server...
start "SERVER" cmd /k python app.py
timeout /t 4 >nul
echo Dang tao link Internet...
start "INTERNET" cmd /k ""C:\Program Files (x86)\cloudflared\cloudflared.exe" tunnel --url http://localhost:5000"
timeout /t 10 >nul
start http://localhost:5000/qr
echo.
echo Xong. Dang nhap admin / admin123 roi quet ma QR bang app.
echo Giu 2 cua so SERVER va INTERNET mo.
pause
