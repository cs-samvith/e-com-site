@echo off
REM Stop all microservices
REM Run from: C:\mygit\e-com-site

echo ========================================
echo Stopping All Services
echo ========================================
echo.

echo [1/4] Checking running services...
echo.

REM Check Product Service (port 8081)
netstat -ano | findstr :8081 >nul 2>&1
if %errorlevel%==0 (
    echo   Product Service running on port 8081
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8081 ^| findstr LISTENING') do (
        echo   Killing PID: %%a
        taskkill /F /PID %%a >nul 2>&1
    )
) else (
    echo   Product Service not running
)
echo.

REM Check User Service (port 8080)
netstat -ano | findstr :8080 >nul 2>&1
if %errorlevel%==0 (
    echo   User Service running on port 8080
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8080 ^| findstr LISTENING') do (
        echo   Killing PID: %%a
        taskkill /F /PID %%a >nul 2>&1
    )
) else (
    echo   User Service not running
)
echo.

REM Check Frontend (port 3000)
netstat -ano | findstr :3000 >nul 2>&1
if %errorlevel%==0 (
    echo   Frontend running on port 3000
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr :3000 ^| findstr LISTENING') do (
        echo   Killing PID: %%a
        taskkill /F /PID %%a >nul 2>&1
    )
) else (
    echo   Frontend not running
)
echo.

echo [2/4] Killing any remaining Python processes...
tasklist | findstr python.exe >nul 2>&1
if %errorlevel%==0 (
    REM Only kill Python processes from our venvs
    wmic process where "name='python.exe' and commandline like '%%uvicorn%%'" delete 2>nul
    echo   Python/uvicorn processes killed
) else (
    echo   No Python processes found
)
echo.

echo [3/4] Killing any remaining Node processes...
tasklist | findstr node.exe >nul 2>&1
if %errorlevel%==0 (
    wmic process where "name='node.exe' and commandline like '%%next%%'" delete 2>nul
    echo   Node/Next.js processes killed
) else (
    echo   No Node processes found
)
echo.

echo [4/4] Verifying ports are free...
echo.

netstat -ano | findstr :8081 >nul 2>&1
if %errorlevel%==0 (
    echo   ⚠ Port 8081 still in use
) else (
    echo   ✓ Port 8081 is free
)

netstat -ano | findstr :8080 >nul 2>&1
if %errorlevel%==0 (
    echo   ⚠ Port 8080 still in use
) else (
    echo   ✓ Port 8080 is free
)

netstat -ano | findstr :3000 >nul 2>&1
if %errorlevel%==0 (
    echo   ⚠ Port 3000 still in use
) else (
    echo   ✓ Port 3000 is free
)

echo.
echo ========================================
echo All services stopped!
echo ========================================
echo.
pause