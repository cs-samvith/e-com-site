@echo off
REM Start User Service with automatic cleanup

echo ========================================
echo User Service
echo ========================================
echo.

REM Kill any existing process on port 8080
echo Checking for existing processes on port 8080...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8080 ^| findstr LISTENING') do (
    echo Killing existing process: %%a
    taskkill /F /PID %%a >nul 2>&1
)

echo.
echo Starting User Service on port 8080...
echo Press Ctrl+C to stop (will cleanup properly)
echo.

REM Activate venv
call venv\Scripts\activate.bat

REM Run service
python -m uvicorn app.main:app --reload --port 8080

REM Cleanup on exit
echo.
echo Cleaning up...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8080 ^| findstr LISTENING') do (
    taskkill /F /PID %%a >nul 2>&1
)
echo Service stopped.