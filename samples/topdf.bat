@echo off

call %~dp0\setup.bat

"%RUBY%" %~dp0\convert.rb %1
"%CALIBRE%" %~dp1\result.html %~dp1\route.pdf --input-encoding utf-8 --unit millimeter --override-profile-size --custom-size 210x148
