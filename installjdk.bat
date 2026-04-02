@echo off
title JDK 自动安装与环境配置工具（可自定义路径）
chcp 936 >nul
setlocal enabledelayedexpansion

::  ---------- 管理员权限自动提升 ----------
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo 请求管理员权限...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
    pushd "%CD%"
    CD /D "%~dp0"

::  ---------- 管理员权限获取完成 ----------

echo ========================================
echo     JDK 自动下载与环境配置脚本
echo         (兼容 Windows 7 及以上)
echo ========================================
echo.

::  ---------- 确定JDK安装路径 ----------
set "INSTALL_DIR="

:: 检查是否有命令行参数（自定义路径）
if not "%~1"=="" (
    set "CUSTOM_PATH=%~1"
    echo 使用用户指定的安装路径: !CUSTOM_PATH!
    set "INSTALL_DIR=!CUSTOM_PATH!"
) else (
    echo 未指定安装路径，尝试使用默认路径...
    :: 检查D盘是否存在
    if exist D:\ (
        set "INSTALL_DIR=D:\Java"
        echo D盘存在，默认安装到 D:\Java
    ) else (
        set "INSTALL_DIR=C:\Program Files\Java"
        echo D盘不存在，默认安装到 C:\Program Files\Java
    )
)

echo 最终安装目录: !INSTALL_DIR!
echo.

:: 检测系统版本（仅显示，不阻断）
ver | find "5.1" > nul && echo 检测到 Windows XP（可能无法运行最新JDK，请手动安装）
ver | find "6.1" > nul && echo 检测到 Windows 7
ver | find "6.2" > nul && echo 检测到 Windows 8
ver | find "6.3" > nul && echo 检测到 Windows 8.1
ver | find "10.0" > nul && echo 检测到 Windows 10/11
echo.

:: 检测系统架构（32位/64位）
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set "ARCH=x64"
    echo 系统架构：64位
) else if "%PROCESSOR_ARCHITECTURE%"=="x86" (
    set "ARCH=x86"
    echo 系统架构：32位
) else (
    echo 无法识别系统架构，将默认使用32位版本
    set "ARCH=x86"
)
echo.

:: 设置JDK下载相关变量
set "JDK_VERSION=21"
set "JDK_URL="
set "JDK_FILE=jdk-%JDK_VERSION%_windows-%ARCH%.zip"
set "TEMP_DIR=%TEMP%\JDK_Setup"
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"
cd /d "%TEMP_DIR%"

:: 步骤1：下载JDK
echo 正在获取最新 JDK %JDK_VERSION% (%ARCH%) 下载地址...
echo 本脚本使用 Adoptium (Eclipse Temurin) 开源JDK

if "%ARCH%"=="x64" (
    set "JDK_URL=https://github.com/adoptium/temurin%JDK_VERSION%-binaries/releases/latest/download/OpenJDK%JDK_VERSION%U-jdk_x64_windows_hotspot.zip"
) else (
    set "JDK_URL=https://github.com/adoptium/temurin%JDK_VERSION%-binaries/releases/latest/download/OpenJDK%JDK_VERSION%U-jdk_x86-32_windows_hotspot.zip"
)

echo 下载链接: %JDK_URL%
echo 开始下载...

bitsadmin /transfer "JDKDownload" /download /priority high "%JDK_URL%" "%TEMP_DIR%\%JDK_FILE%"

if not exist "%TEMP_DIR%\%JDK_FILE%" (
    echo 下载失败，尝试使用备用下载方式...
    certutil -urlcache -f "%JDK_URL%" "%JDK_FILE%"
)

if not exist "%JDK_FILE%" (
    echo 下载失败，请检查网络连接或手动下载JDK
    pause
    exit /b 1
)
echo 下载完成！
echo.

:: 步骤2：解压JDK
echo 正在解压 JDK 到 !INSTALL_DIR!...
if not exist "!INSTALL_DIR!" mkdir "!INSTALL_DIR!"

:: 使用PowerShell被禁用，使用VBS解压
echo 创建解压脚本...
>"%TEMP_DIR%\unzip.vbs" echo Set fso = CreateObject("Scripting.FileSystemObject")
>>"%TEMP_DIR%\unzip.vbs" echo If Not fso.FolderExists("!INSTALL_DIR:\=\\!") Then fso.CreateFolder("!INSTALL_DIR:\=\\!")
>>"%TEMP_DIR%\unzip.vbs" echo Unzip "%TEMP_DIR:\=\\%\%JDK_FILE%" "!INSTALL_DIR:\=\\!"
>>"%TEMP_DIR%\unzip.vbs" echo Sub Unzip(zipFile, targetFolder)
>>"%TEMP_DIR%\unzip.vbs" echo   Set shell = CreateObject("Shell.Application")
>>"%TEMP_DIR%\unzip.vbs" echo   Set files = shell.NameSpace(zipFile).Items
>>"%TEMP_DIR%\unzip.vbs" echo   shell.NameSpace(targetFolder).CopyHere files, 20
>>"%TEMP_DIR%\unzip.vbs" echo End Sub

cscript //nologo "%TEMP_DIR%\unzip.vbs"

:: 查找解压后的JDK目录名
cd /d "!INSTALL_DIR!"
for /d %%i in (jdk-* jdk* temurin-* OpenJDK*) do (
    set "JAVA_HOME_DIR=%%i"
    goto :found
)

echo 无法定位JDK目录，请手动检查 !INSTALL_DIR!
pause
exit /b 1

:found
set "JAVA_HOME=!INSTALL_DIR!\!JAVA_HOME_DIR!"
echo JDK 解压完成，路径：!JAVA_HOME!
echo.

:: 步骤3：配置环境变量 
echo 正在配置系统环境变量...

:: 设置 JAVA_HOME 
echo 设置 JAVA_HOME=!JAVA_HOME!
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v JAVA_HOME /t REG_SZ /d "!JAVA_HOME!" /f

:: 更新 Path 变量（添加 %%JAVA_HOME%%\bin）
echo 更新 Path 变量...
for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path ^| findstr /i "Path"') do (
    set "CURRENT_PATH=%%b"
)

:: 检查是否已经包含JAVA_HOME
echo !CURRENT_PATH! | findstr /i "java" > nul
if !errorlevel! equ 0 (
    echo Path 中似乎已包含 Java 路径，为避免重复，请手动检查
) else (
    set "NEW_PATH=!CURRENT_PATH!;%%JAVA_HOME%%\bin"
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path /t REG_EXPAND_SZ /d "!NEW_PATH!" /f
)

:: 设置 CLASSPATH（可选，现代Java开发通常不需要）
echo 设置 CLASSPATH
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v CLASSPATH /t REG_SZ /d ".;%%JAVA_HOME%%\lib\dt.jar;%%JAVA_HOME%%\lib\tools.jar" /f

echo 环境变量配置完成！
echo.

:: 步骤4：广播环境变量变更（通知系统）
echo 通知系统环境变量已变更...
wmic ENVIRONMENT where "name='PATH'" set VariableValue="!NEW_PATH!" >nul 2>&1

>"%TEMP%\refresh_env.vbs" echo Set WSHShell = CreateObject("WScript.Shell")
>>"%TEMP%\refresh_env.vbs" echo WSHShell.SendKeys "{ESC}" 2>nul
>>"%TEMP%\refresh_env.vbs" echo WSHShell.Run "cmd /c set", 0, True
cscript //nologo "%TEMP%\refresh_env.vbs" 2>nul
del "%TEMP%\refresh_env.vbs"

:: 步骤5：验证安装
echo.
echo 验证 JDK 安装...
echo 请在新打开的命令提示符中运行以下命令：
echo   java -version
echo   javac -version
echo.
echo 当前会话的环境变量尚未更新，如需立即使用，请运行：
echo   set JAVA_HOME=!JAVA_HOME!
echo   set Path=%%JAVA_HOME%%\bin;%%Path%%
echo.

start cmd /k "echo JDK环境已配置 & echo 请运行 java -version 验证 & cd /d %USERPROFILE%"

:: 清理临时文件
cd /d "%TEMP%"
rmdir /s /q "%TEMP_DIR%" 2>nul

echo.
echo JDK 安装与配置脚本执行完毕！
echo 建议重启计算机以确保所有环境变量生效 
pause
exit /b 0