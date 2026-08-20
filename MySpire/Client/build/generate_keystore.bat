@echo off
setlocal enabledelayedexpansion
REM ============================================================
REM  MySpire — Android Release Keystore 生成器
REM  用途: 生成用于 AAB 签名的 keystore 文件
REM  前置: 需安装 JDK (keytool 命令可用)
REM ============================================================

set "PROJECT_DIR=%~dp0.."
set "KEY_DIR=%PROJECT_DIR%\build\keystore"
set "KEY_FILE=%KEY_DIR%\myspire_release.keystore"
set "ALIAS=myspire"
set "VALIDITY=36500"

REM === 检查 keytool ===
where keytool >nul 2>&1
if errorlevel 1 (
    echo [ERROR] 未找到 keytool — 请先安装 JDK。
    echo         下载: https://adoptium.net/
    exit /b 1
)

REM === 检查是否已存在 ===
if exist "%KEY_FILE%" (
    echo [WARNING] Keystore 已存在: %KEY_FILE%
    set /p "OVERWRITE=是否覆盖? (y/N): "
    if /i not "!OVERWRITE!"=="y" (
        echo [取消] 未修改现有 keystore。
        exit /b 0
    )
    del "%KEY_FILE%"
)

REM === 创建目录 ===
if not exist "%KEY_DIR%" mkdir "%KEY_DIR%"

REM === 密码输入 ===
echo.
echo === MySpire Release Keystore 生成 ===
echo.
echo 请设置 keystore 密码 (至少 6 位):
set /p "STORE_PASS=  Keystore 密码: "
if "!STORE_PASS!"=="" (
    echo [ERROR] 密码不能为空
    exit /b 1
)
echo 请确认密码:
set /p "STORE_PASS2=  确认密码: "
if not "!STORE_PASS!"=="!STORE_PASS2!" (
    echo [ERROR] 两次密码不一致
    exit /b 1
)

REM === 生成 keystore ===
echo.
echo [生成中] 正在创建 keystore ...
keytool -keyalg RSA -genkeypair ^
    -alias %ALIAS% ^
    -keypass "!STORE_PASS!" ^
    -keystore "%KEY_FILE%" ^
    -storepass "!STORE_PASS!" ^
    -validity %VALIDITY% ^
    -keysize 2048 ^
    -dname "CN=MySpire, OU=GameDev, O=MySpire, L=Unknown, ST=Unknown, C=CN"

if errorlevel 1 (
    echo [ERROR] Keystore 生成失败
    exit /b 1
)

echo.
echo [OK] Keystore 生成成功!
echo   文件: %KEY_FILE%
echo   别名: %ALIAS%
echo   有效期: %VALIDITY% 天
echo.
echo 下一步: 编辑 export_presets.cfg 中的 keystore/release_password
echo         填入刚才设置的密码
exit /b 0
