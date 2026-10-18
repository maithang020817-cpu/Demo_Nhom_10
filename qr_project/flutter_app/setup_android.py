"""Chay SAU `flutter create .` de bat quyen Internet, Camera va HTTP (khong ma hoa).
    python setup_android.py
"""
import re
import sys

PATH = "android/app/src/main/AndroidManifest.xml"
try:
    s = open(PATH, encoding="utf-8").read()
except FileNotFoundError:
    sys.exit("Khong thay " + PATH + " - hay chay `flutter create .` truoc.")

perms = ""
for p in ("INTERNET", "CAMERA"):
    if f"android.permission.{p}" not in s:
        perms += f'    <uses-permission android:name="android.permission.{p}"/>\n'
if perms:
    s = re.sub(r"(<manifest[^>]*>\n?)", lambda m: m.group(1) + perms, s, count=1)
if "usesCleartextTraffic" not in s:
    s = s.replace("<application", '<application\n        android:usesCleartextTraffic="true"', 1)
open(PATH, "w", encoding="utf-8").write(s)
print("Da cap nhat", PATH)
