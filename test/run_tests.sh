#!/bin/bash
# Uses C:\flutter (no-spaces SDK) to avoid objective_c hook path bug on Windows.
FLUTTER_ROOT="/c/flutter" /c/flutter/bin/flutter.bat test --no-pub --exclude-tags=native
