@echo off
REM Start Product Service with automatic cleanup
REM Handles Ctrl+C gracefully

echo ========================================
echo Product Service
echo ========================================
echo.

REM Kill any existing process on port 8081
echo Checking for existing processes on port 8081...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8081 ^| findstr LISTENING') do (
    echo Killing existing process: %%a
    taskkill /F /PID %%a >nul 2>&1
)

echo.
echo Starting Product Service on port 8081...
echo Press Ctrl+C to stop (will cleanup properly)
echo.

REM Activate venv
call venv\Scripts\activate.bat

REM Set trap for Ctrl+C (cleanup on exit)
REM Run service
python -m uvicorn app.main:app --reload --port 8081

REM When Ctrl+C is pressed, this runs:
echo.
echo Cleaning up...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8081 ^| findstr LISTENING') do (
    taskkill /F /PID %%a >nul 2>&1
)
echo Service stopped.