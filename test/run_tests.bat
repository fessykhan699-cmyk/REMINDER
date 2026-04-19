@echo off
REM Uses C:\flutter (no-spaces SDK) to avoid objective_c hook path bug on Windows.
REM Run this instead of plain "flutter test" on machines where Flutter SDK path has spaces.
SET FLUTTER_ROOT=C:\flutter
"C:\flutter\bin\flutter.bat" test --no-pub --exclude-tags=native
