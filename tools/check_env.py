#!/usr/bin/env python3
import os
import shutil
import subprocess

checks = [
    ("git", ["git", "--version"]),
    ("java", ["java", "-version"]),
    ("adb", ["adb", "version"]),
]

print("PET VO HAN - ENV CHECK")
print("=" * 32)
for name, command in checks:
    path = shutil.which(command[0])
    if not path:
        print(f"[MISSING] {name}")
        continue
    try:
        p = subprocess.run(command, capture_output=True, text=True, timeout=5)
        output = (p.stdout or p.stderr).splitlines()
        detail = output[0] if output else path
        print(f"[OK] {name}: {detail}")
    except Exception as exc:
        print(f"[ERROR] {name}: {exc}")

print("\nPaths:")
print("JAVA_HOME =", os.environ.get("JAVA_HOME", "<not set>"))
print("ANDROID_HOME =", os.environ.get("ANDROID_HOME", "<not set>"))
print("ANDROID_SDK_ROOT =", os.environ.get("ANDROID_SDK_ROOT", "<not set>"))
