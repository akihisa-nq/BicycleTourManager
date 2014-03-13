@echo off

call %~dp0\setup.bat

"%RUBY%" %~dp0\gmap.rb %*
