@echo off
setlocal enabledelayedexpansion
REM ============================================================
REM  MySpire — Android 构建脚本
REM  用法: build_android.bat [debug^|release^|all]
REM  默认: all
REM ============================================================

REM === Godot CLI 检测 ===
set "GODOT="
if defined GODOT_PATH (
    set "GODOT=%GODOT_PATH%"
) else (
    where godot >nul 2>&1 && for /f "delims=" %%i in ('where godot') do set "GODOT=%%i"
)
if not defined GODOT (
    if exist "C:\Program Files\Godot\godot.exe" set "GODOT=C:\Program Files\Godot\godot.exe"
)
if not defined GODOT (
    if exist "C:\Program Files (x86)\Godot\godot.exe" set "GODOT=C:\Program Files (x86)\Godot\godot.exe"
)
if not defined GODOT (
    REM 尝试 scoop 安装路径
    for %%f in ("%USERPROFILE%\scoop\apps\godot-mono\current\godot.exe" ^
                "%USERPROFILE%\scoop\apps\godot\current\godot.exe") do (
        if exist "%%~f" set "GODOT=%%~f"
    )
)

if not defined GODOT (
    echo [ERROR] 未找到 Godot CLI。
    echo   方案 1: 将 godot.exe 加入系统 PATH
    echo   方案 2: 设置环境变量  set GODOT_PATH=C:\path\to\godot.exe
    exit /b 1
)

echo [INFO] Godot CLI: %GODOT%

REM === 路径设置 ===
set "PROJECT_DIR=%~dp0.."
set "DIST_DIR=%PROJECT_DIR%\build\dist"
if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"

REM === 构建模式 ===
set "MODE=%~1"
if "%MODE%"=="" set "MODE=all"

REM === 执行 ===
set "ERRORS=0"

if /i "%MODE%"=="debug"  call :build_debug  && goto :done
if /i "%MODE%"=="release" call :build_release && goto :done
if /i "%MODE%"=="all"     call :build_all    && goto :done

echo [ERROR] 未知模式: %MODE%
echo 用法: %~nx0 [debug^|release^|all]
exit /b 1

REM ============================================================
:build_debug
echo.
echo ========================================
echo  [1/2] Android Debug APK
echo ========================================
"%GODOT%" --headless --export-debug "Android Debug (APK)" --path "%PROJECT_DIR%"
if errorlevel 1 (
    echo [ERROR] Debug APK 导出失败
    set /a ERRORS+=1
    exit /b 1
)
if exist "%DIST_DIR%\MySpire-debug.apk" (
    echo [OK] %DIST_DIR%\MySpire-debug.apk
) else (
    echo [WARNING] 导出成功但未找到 APK 文件
    set /a ERRORS+=1
)
exit /b 0

REM ============================================================
:build_release
echo.
echo ========================================
echo  [2/2] Android Release AAB
echo ========================================

REM 检查 keystore
set "KEY_FILE=%PROJECT_DIR%\build\keystore\myspire_release.keystore"
if not exist "%KEY_FILE%" (
    echo [WARNING] Release keystore 不存在: %KEY_FILE%
    echo           请先运行: build\generate_keystore.bat
    echo           跳过 Release 构建...
    exit /b 1
)

"%GODOT%" --headless --export-release "Android Release (AAB)" --path "%PROJECT_DIR%"
if errorlevel 1 (
    echo [ERROR] Release AAB 导出失败
    set /a ERRORS+=1
    exit /b 1
)
if exist "%DIST_DIR%\MySpire-release.aab" (
    echo [OK] %DIST_DIR%\MySpire-release.aab
) else (
    echo [WARNING] 导出成功但未找到 AAB 文件
    set /a ERRORS+=1
)
exit /b 0

REM ============================================================
:build_all
call :build_debug
call :build_release
exit /b 0

REM ============================================================
:done
echo.
if %ERRORS% gtr 0 (
    echo [完成] 构建完成，但有 %ERRORS% 个错误。
) else (
    echo [完成] 所有 Android 构建成功！
)
echo 产物目录: %DIST_DIR%
exit /b %ERRORS%
