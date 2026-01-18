@echo off
REM Run Product Service in Mock Mode (No dependencies)

echo ========================================
echo Product Service - Mock Mode
echo ========================================
echo.
echo Running with:
echo   - In-memory mock database
echo   - No Redis (caching disabled)
echo   - No RabbitMQ (queue disabled)
echo   - No PostgreSQL (mock data)
echo.
echo Perfect for quick testing and learning!
echo.
echo Press Ctrl+C to stop the service
echo ========================================
echo.

REM Delete .env to force mock mode
if exist .env del .env

REM Activate venv and run
call venv\Scripts\activate.bat
python -m uvicorn app.main:app --reload --port 8081