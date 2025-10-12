@echo off
REM ============================================================================
REM 快速测试脚本 - 启动游戏（使用注入器）
REM ============================================================================

echo ========================================
echo Quick Test - RenderDoc Injector
echo ========================================
echo.

REM 游戏路径（请根据需要修改）
set GAME_EXE=D:\Program Files\EndField Launcher\EndField Game\Endfield_TBeta_OS.exe
@REM set GAME_EXE=D:\BaiduNetdiskDownload\XJ06623\Into the Emberlands\Into The Emberlands.exe

REM 查找注入器
set INJECTOR=
if exist "%~dp0..\x64\Development\RenderDocInjector.exe" (
    set INJECTOR=%~dp0..\x64\Development\RenderDocInjector.exe
) else if exist "%~dp0RenderDocInjector.exe" (
    set INJECTOR=%~dp0RenderDocInjector.exe
)

if "%INJECTOR%"=="" (
    echo ERROR: RenderDocInjector.exe not found!
    echo Please build the project first.
    pause
    exit /b 1
)

echo Injector: %INJECTOR%
echo Game:     %GAME_EXE%
echo.

REM 显示当前配置的 DLL 名称
echo Current DLL name: renderdocX.dll
echo (Can be changed in RenderDocInjector.cpp - DLL_NAME macro)
echo.

REM 启动
"%INJECTOR%" "%GAME_EXE%"

if errorlevel 1 (
    echo.
    echo ========================================
    echo FAILED!
    echo ========================================
    pause
) else (
    echo.
    echo ========================================
    echo SUCCESS!
    echo ========================================
)

