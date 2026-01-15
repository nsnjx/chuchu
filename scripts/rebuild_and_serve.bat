@echo off
REM Flutter Web Rebuild and Serve Script (Windows)
REM Usage: scripts\rebuild_and_serve.bat

setlocal enabledelayedexpansion

echo === Flutter Web Rebuild and Serve ===
echo.

REM 1. Stop old server
echo Step 1: Stopping old server...
taskkill /F /IM python.exe /FI "WINDOWTITLE eq http.server*" 2>nul
if errorlevel 1 (
    echo No running server found
) else (
    echo Stopped old server
)
timeout /t 1 /nobreak >nul

REM 2. Flutter build
echo.
echo Step 2: Flutter Web build...
call flutter build web --release
if errorlevel 1 (
    echo ❌ Flutter build failed!
    exit /b 1
)
echo ✅ Flutter build completed

REM 3. Run optimization script
echo.
echo Step 3: Running optimization script...
call node scripts\optimize_web_build.js
if errorlevel 1 (
    echo ❌ Optimization script failed!
    exit /b 1
)
echo ✅ Optimization completed

REM 4. Start server
echo.
echo Step 4: Starting server...
cd build\web
start /B python -m http.server 8080 >nul 2>&1
timeout /t 2 /nobreak >nul

echo ✅ Server started
echo.
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo 🌐 Access URL: http://localhost:8080
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo.
echo 📝 Tips:
echo    - Stop server: End python.exe process in Task Manager
echo.

pause
