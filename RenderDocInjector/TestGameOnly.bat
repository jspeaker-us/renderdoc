@echo off
REM ============================================================================
REM 测试游戏启动 - 不注入 DLL（用于对比测试）
REM ============================================================================

echo ========================================
echo Test Game Launch (No Injection)
echo ========================================
echo.

REM 游戏路径（请根据需要修改）
set GAME_EXE=D:\Program Files\EndField Launcher\EndField Game\Endfield_TBeta_OS.exe
set GAME_DIR=D:\Program Files\EndField Launcher\EndField Game

echo Game: %GAME_EXE%
echo.
echo Starting game WITHOUT DLL injection...
echo This is for testing if the game can start normally.
echo.

REM 检查游戏是否存在
if not exist "%GAME_EXE%" (
    echo ERROR: Game not found!
    pause
    exit /b 1
)

REM 启动游戏
cd /d "%GAME_DIR%"
start "" "%GAME_EXE%"

echo.
echo Game process started.
echo.
echo If game starts successfully, the injector should work too.
echo If game fails to start, there might be a problem with the game itself.
echo.

