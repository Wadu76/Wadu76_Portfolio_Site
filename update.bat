@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo.
echo ============================================
echo   WADU76 作品集 - 一键更新上线
echo ============================================
echo.

git add -A
git commit -m "update content %date% %time%"
git push

echo.
echo ============================================
echo   已完成，Vercel 约 1 分钟后自动构建上线
echo ============================================
pause
