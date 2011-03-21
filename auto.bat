:: auto.bat - Launcher for Microsoft Windows.
:: Copyright (C) 2010-2011 Xelhua Development Group, et al.
:: Released under the terms stated in doc/LICENSE.
:: Clone of `auto`, since Windows likes Batch, not sh.

@echo off

set pidfile=bin/auto.pid

if "%1" == "" goto errparams
if "%1" == "start" goto start
if "%1" == "status" goto status
else goto errparams

:errparams
echo.
echo Usage: auto.bat (start|status) [force]
:end

:start
echo.
if exist "%pidfile" (
    if "%2" == "force" (
        echo Starting Auto. . .
        perl bin/auto
    )
    else (
        echo Auto appears to be running already. Run `auto.bat start force` to start anyway.
    )
)
else (
    echo Starting Auto. . .
    perl bin/auto
)
:end

:status
echo.
if exist "%pidfile" (
    echo Status: Auto appears to be running.
)
else (
    echo Status: Auto appears to not be running.
)
:end
