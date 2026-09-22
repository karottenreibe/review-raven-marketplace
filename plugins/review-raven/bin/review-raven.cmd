@echo off
rem Run review raven from cmd.exe.
rem
rem Windows has no bash to rely on, so the download, the checksum and the cache
rem live in the PowerShell script beside this one rather than in lib/fetch.sh.
rem PowerShell ships with Windows; Git for Windows is not required.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0review-raven.ps1" %*
