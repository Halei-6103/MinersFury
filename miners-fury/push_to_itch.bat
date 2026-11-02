@echo off
REM Pushes the latest Windows export (the withCoop folder) to itch.io.
REM Your friends' itch app picks up the update automatically.
REM Steps: export from Godot into withCoop, then double-click this file.

set GAME=apahanta/miners-fury:windows
set BUILD=%~dp0withCoop

REM find butler: on PATH, or in C:\butler
set BUTLER=butler
where butler >nul 2>nul
if errorlevel 1 (
    if exist "C:\butler\butler.exe" (
        set BUTLER=C:\butler\butler.exe
    ) else (
        echo Couldn't find butler. Put butler.exe in C:\butler, or edit this file.
        pause
        exit /b 1
    )
)

if not exist "%BUILD%\Miners Fury.exe" (
    echo No build found in %BUILD%
    echo Export from Godot into the withCoop folder first.
    pause
    exit /b 1
)

echo Pushing %BUILD% to %GAME% ...
"%BUTLER%" push "%BUILD%" %GAME%
echo.
echo Done. Friends will get the update next time they open the itch app.
pause
