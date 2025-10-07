@echo off
REM ============================================================================
REM RenderDoc Injector - 游戏启动脚本示例
REM ============================================================================

echo ========================================
echo RenderDoc Game Launcher
echo ========================================
echo.

REM 配置：修改为你的游戏路径
set GAME_EXE=D:\BaiduNetdiskDownload\XJ06623\Into the Emberlands\Into The Emberlands.exe
REM 游戏参数（如果游戏不支持此参数，请留空或删除）
set GAME_ARGS=

REM 可选：指定RenderDoc路径（如果不在标准位置）
REM set RENDERDOC_PATH=C:\Program Files\RenderDoc

REM 设置捕获文件保存目录（在批处理文件所在目录的 Captures 文件夹）
set CAPTURE_DIR=%~dp0Captures
if not exist "%CAPTURE_DIR%" (
    echo Creating capture directory: %CAPTURE_DIR%
    mkdir "%CAPTURE_DIR%"
)

REM 检查游戏是否存在
if not exist "%GAME_EXE%" (
    echo ERROR: Game not found: %GAME_EXE%
    echo Please edit this batch file and set the correct GAME_EXE path.
    pause
    exit /b 1
)

echo Game: %GAME_EXE%
echo Args: %GAME_ARGS%
echo Capture folder: %CAPTURE_DIR%
echo.
echo Launching with RenderDoc...
echo.

REM 查找注入器 exe（支持多个可能的位置）
set INJECTOR_EXE=
if exist "%~dp0..\x64\Development\RenderDocInjector.exe" (
    set INJECTOR_EXE=%~dp0..\x64\Development\RenderDocInjector.exe
) else if exist "%~dp0..\x64\Release\RenderDocInjector.exe" (
    set INJECTOR_EXE=%~dp0..\x64\Release\RenderDocInjector.exe
) else if exist "%~dp0RenderDocInjector.exe" (
    set INJECTOR_EXE=%~dp0RenderDocInjector.exe
) else if exist "RenderDocInjector.exe" (
    set INJECTOR_EXE=RenderDocInjector.exe
)

if "%INJECTOR_EXE%"=="" (
    echo ERROR: Cannot find RenderDocInjector.exe
    echo.
    echo Please build the project first or copy RenderDocInjector.exe to:
    echo   - x64\Development\
    echo   - x64\Release\
    echo   - or this directory
    pause
    exit /b 1
)

echo Using injector: %INJECTOR_EXE%
echo.

REM 设置 RenderDoc 捕获路径环境变量
REM 注意：RenderDoc 默认使用 TEMP 目录，这里我们需要通过配置文件或启动参数来改变
REM 由于注入器还不支持设置捕获路径，我们先记录这个位置供后续使用
echo.
echo NOTE: RenderDoc will save captures to: %CAPTURE_DIR%
echo (You may need to move files from %%TEMP%%\RenderDoc manually for now)
echo.

REM 启动注入器
"%INJECTOR_EXE%" "%GAME_EXE%" %GAME_ARGS%

if errorlevel 1 (
    echo.
    echo ERROR: Failed to launch game with RenderDoc!
    echo Check renderdoc_injector.log for details.
    pause
    exit /b 1
)

echo.
echo ========================================
echo Game launched successfully!
echo ========================================
echo.
echo Hotkeys:
echo   F11        - Cycle active window
echo   F12/PrtScr - Capture frame
echo.
echo Captures are saved to:
echo   %%TEMP%%\RenderDoc\
echo.
echo Opening RenderDoc temp folder...
start "" explorer "%TEMP%\RenderDoc"
echo.
echo TIP: You can move captures to: %CAPTURE_DIR%
echo.

