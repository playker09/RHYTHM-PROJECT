@echo off
REM Build PatternTool.exe (needs Python 3.10+). Output: pattern-tool\PatternTool.exe
cd /d "%~dp0"
python -m pip install --quiet pyinstaller || goto :err
python -m PyInstaller --noconfirm --clean --onefile --noconsole --name PatternTool ^
  --add-data "%~dp0web;web" ^
  --distpath "%~dp0build\dist" --workpath "%~dp0build\work" --specpath "%~dp0build" launcher.py || goto :err
copy /y "build\dist\PatternTool.exe" "PatternTool.exe" >nul
echo.
echo Done: %~dp0PatternTool.exe
exit /b 0
:err
echo Build failed
exit /b 1
