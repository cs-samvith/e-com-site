@echo off
echo ========================================
echo User Service - Mock Mode
echo ========================================
echo.

if exist .env del .env

call venv\Scripts\activate.bat
python -m uvicorn app.main:app --reload --port 8080