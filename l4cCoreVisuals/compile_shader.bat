@echo off
title Lost 4 Creed - Shader Compiler
echo ========================================
echo   L4C Shader Compiler - Bloom + Pixelation
echo ========================================
echo.

set SHADER_SRC=shaders\src\simple_bloom_ps2x.hlsl
set SHADER_OUT=shaders\fxc\simple_bloom_ps20b.vcs
set ADDON_ROOT=%CD%
set WORK_DIR=%TEMP%\l4c_shader_compile
set BIN_DIR=%WORK_DIR%\shadersrc\bin
set SHADER_VER=20b

if not exist "%BIN_DIR%\ShaderCompile.exe" (
    echo [ERROR] ShaderCompile.exe not found!
    echo Run this from the l4cCoreVisuals addon root folder.
    pause
    exit /b 1
)

echo [1/3] Copying source...
copy /Y "%SHADER_SRC%" "%WORK_DIR%\shadersrc\simple_bloom_ps2x.hlsl" >nul

echo [2/3] Compiling (ps_%SHADER_VER%)...
cd /d "%WORK_DIR%\shadersrc"
bin\ShaderCompile.exe /O 3 -ver %SHADER_VER% -shaderpath "%WORK_DIR%\shadersrc" "simple_bloom_ps2x.hlsl"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Compilation failed!
    pause
    exit /b %ERRORLEVEL%
)

echo [3/3] Deploying...
copy /Y "%WORK_DIR%\shadersrc\shaders\fxc\simple_bloom_ps%SHADER_VER%.vcs" "%ADDON_ROOT%\%SHADER_OUT%" >nul

echo.
echo ========================================
echo   DONE - Compiled: %date% %time%
echo   Output: %SHADER_OUT%
echo ========================================
echo.
echo   To test in L4D2:
echo   1. Restart map:  map c1m1_hotel
echo   2. Or change map: map c2m1_highway
echo.
pause
