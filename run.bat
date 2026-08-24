@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

if /i "%~1"=="--run" goto run_once

set "LAST_RUN_DATE="
set "RUN_AT="

echo 微软奖励脚本守护模式已启动。
echo 每天在 08:00-09:30 之间随机选择一个时间运行一次。
echo 在 08:00-09:30 之外启动本脚本会立即运行一次。
echo 关闭此窗口会停止守护。
echo 如需立即运行一次，请执行：run.bat --run
echo.

rem ===== 启动时判断 =====
for /f %%A in ('powershell -NoProfile -Command "(Get-Date).Hour*60+(Get-Date).Minute"') do set "NOW_MIN=%%A"
for /f %%A in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd"') do set "TODAY=%%A"

set "IN_WINDOW=0"
if !NOW_MIN! geq 480 if !NOW_MIN! lss 570 set "IN_WINDOW=1"

if "!IN_WINDOW!"=="1" (
    call :pick_random
    echo 当前在 08:00-09:30 窗口内，已随机选择 !RUN_AT_TIME! 开始运行。
) else (
    echo 当前不在 08:00-09:30 窗口内，立即运行一次...
    set "LAST_RUN_DATE=!TODAY!"
    call "%~f0" --run
    echo [!TODAY!] 本次运行结束。
    echo.
)

:loop
for /f %%A in ('powershell -NoProfile -Command "(Get-Date).Hour*60+(Get-Date).Minute"') do set "NOW_MIN=%%A"
for /f %%A in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd"') do set "TODAY=%%A"

if not "!LAST_RUN_DATE!"=="!TODAY!" (
    rem 今天还没运行：进入窗口后为今天随机选一个运行时间
    if not defined RUN_AT (
        set "IN_WINDOW=0"
        if !NOW_MIN! geq 480 if !NOW_MIN! lss 570 set "IN_WINDOW=1"
        if "!IN_WINDOW!"=="1" (
            call :pick_random
            echo [!TODAY!] 已随机选择 !RUN_AT_TIME! 运行。
        )
    )
    if defined RUN_AT (
        if !NOW_MIN! geq !RUN_AT! (
            echo [!TODAY!] 到达随机运行时间 !RUN_AT_TIME!，开始执行脚本...
            set "LAST_RUN_DATE=!TODAY!"
            set "RUN_AT="
            set "RUN_AT_TIME="
            call "%~f0" --run
            echo [!TODAY!] 本次运行结束。
            echo.
        )
    ) else (
        rem 已过 09:30 还未运行（例如电脑休眠错过窗口），立即补运行
        if !NOW_MIN! geq 570 (
            echo [!TODAY!] 已过运行窗口，立即补运行一次...
            set "LAST_RUN_DATE=!TODAY!"
            call "%~f0" --run
            echo [!TODAY!] 本次运行结束。
            echo.
        )
    )
)

timeout /t 60 /nobreak >nul
goto loop

:pick_random
rem 在当前时刻到 09:30 之间随机选一分钟，结果存到 RUN_AT（分钟数）和 RUN_AT_TIME（HH:MM）
for /f %%A in ('powershell -NoProfile -Command "$m=(Get-Date).Hour*60+(Get-Date).Minute; Get-Random -Minimum $m -Maximum 571"') do set /a "RUN_AT=%%A"
if defined RUN_AT (
    set /a "RUN_AT_H=!RUN_AT!/60"
    set /a "RUN_AT_M=!RUN_AT!%%60"
    if !RUN_AT_M! lss 10 set "RUN_AT_M=0!RUN_AT_M!"
    if !RUN_AT_H! lss 10 set "RUN_AT_H=0!RUN_AT_H!"
    set "RUN_AT_TIME=!RUN_AT_H!:!RUN_AT_M!"
) else (
    set "RUN_AT_TIME=未知"
)
exit /b

:run_once
cd /d "%~dp0"
if not exist "%~dp0logs" mkdir "%~dp0logs" >nul
if exist "%~dp0notify.ps1" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0notify.ps1" start
powershell -NoProfile -ExecutionPolicy Bypass -Command "$sw = New-Object System.IO.StreamWriter('%~dp0logs\last_run.log', $false, (New-Object System.Text.UTF8Encoding($false))); $sw.AutoFlush = $true; & npm start 2>&1 | ForEach-Object { Write-Host $_; $sw.WriteLine($_) }; $sw.Close(); exit $LASTEXITCODE"
set "EXIT_CODE=%ERRORLEVEL%"
if exist "%~dp0notify.ps1" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0notify.ps1" end %EXIT_CODE% "%~dp0logs\last_run.log"
exit /b %EXIT_CODE%
