@echo off
setlocal enabledelayedexpansion
REM ============================================================
REM  MySpire — 全平台构建脚本
REM  用法: build_all.bat [android^|ios^|all]
REM  默认: all (当前平台可执行的构建)
REM ============================================================

set "SCRIPT_DIR=%~dp0"
set "MODE=%~1"
if "%MODE%"=="" set "MODE=all"

set "ERRORS=0"

if /i "%MODE%"=="android" goto :android
if /i "%MODE%"=="ios" goto :ios_export
if /i "%MODE%"=="all" goto :all

echo [ERROR] 未知模式: %MODE%
echo 用法: %~nx0 [android^|ios^|all]
exit /b 1

REM ============================================================
:android
echo.
echo ##################################################
echo #              Android 构建
echo ##################################################
call "%SCRIPT_DIR%build_android.bat" all
if errorlevel 1 set /a ERRORS+=1
goto :done

REM ============================================================
:ios_export
echo.
echo ##################################################
echo #              iOS Xcode 工程导出
echo ##################################################
echo [提示] iOS IPA 编译需要 macOS + Xcode，此脚本仅导出 Xcode 工程。
echo        完整构建请将项目传到 macOS 运行: ./build_ios.sh all
echo.

REM 检测 Godot
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
    echo [ERROR] 未找到 Godot CLI。设置 GODOT_PATH 环境变量。
    set /a ERRORS+=1
    goto :done
)

set "PROJECT_DIR=%SCRIPT_DIR%.."
set "IOS_DIR=%PROJECT_DIR%\build\ios"
if not exist "%IOS_DIR%" mkdir "%IOS_DIR%"

"%GODOT%" --headless --export-debug "iOS (Xcode Project)" --path "%PROJECT_DIR%"
if errorlevel 1 (
    echo [ERROR] iOS Xcode 工程导出失败
    set /a ERRORS+=1
) else (
    echo [OK] Xcode 工程已导出到: %IOS_DIR%\MySpire.xcodeproj
)
goto :done

REM ============================================================
:all
call :android
call :ios_export
goto :done

REM ============================================================
:done
echo.
if %ERRORS% gtr 0 (
    echo [完成] 构建完成，但有 %ERRORS% 个错误。
) else (
    echo [完成] 所有构建成功！
)
exit /b %ERRORS%
