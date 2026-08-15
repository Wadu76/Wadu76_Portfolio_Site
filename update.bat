@echo off
cd /d "%~dp0"
echo.
echo ============================================
echo   WADU76 portfolio - commit and push
echo ============================================
echo.
git add -A
git commit -m "site update" || echo (nothing to commit, pushing anyway)
echo.
echo === pushing to GitHub... ===
set retry=0
:push
git push
if %errorlevel%==0 goto ok
set /a retry+=1
if %retry% geq 5 goto fail
echo push failed, retrying in 5s...
timeout /t 5 /nobreak >nul
goto push
:ok
echo.
echo ============================================
echo   DONE. Vercel rebuilds in ~1 minute
echo ============================================
pause
exit /b 0
:fail
echo.
echo ============================================
echo   PUSH FAILED after 5 tries. Check network.
echo ============================================
pause
exit /b 1
