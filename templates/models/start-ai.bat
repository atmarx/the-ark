@echo off
rem Start a language model from this drive.  See README.txt in this folder.
rem Usage: start-ai.bat [model-id | --list]
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-ai.ps1" %*
pause
