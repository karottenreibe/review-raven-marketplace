@echo off
rem Run review raven from cmd.exe by delegating to the bash launcher.
rem
rem The download and its checksum verification stay in lib/fetch.sh rather than
rem being reimplemented here. A second copy of the verification step is exactly
rem where a security bug would go unnoticed, and Git Bash is already a practical
rem prerequisite for Claude Code's Bash tool on Windows.
setlocal
for %%I in (bash.exe) do set "BASH=%%~$PATH:I"
if not defined BASH (
  if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH=%ProgramFiles%\Git\bin\bash.exe"
)
if not defined BASH (
  echo review-raven: bash is required to run this launcher. Install Git for Windows. 1>&2
  exit /b 1
)
"%BASH%" "%~dp0review-raven" %*
