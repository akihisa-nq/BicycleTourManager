@echo off

REM gnuplot.exe へのパス
if not defined GNUPLOT set GNUPLOT=

REM ruby.exe へのパス
if not defined RUBY set RUBY=

REM フォント ファイル (ttf や ttc) へのパス
if not defined FONT set FONT=

REM キャッシュを作成するディレクトリへのパス
if not defined BICYLE_TOUR_MANAGER_CACHE set BICYLE_TOUR_MANAGER_CACHE=

REM calibre2 に含まれる ebook-convert.exe へのパス
if not defined CALIBRE set CALIBRE=
