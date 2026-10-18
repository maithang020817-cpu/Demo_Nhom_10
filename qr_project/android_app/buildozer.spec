[app]
title = Goi mon QR
package.name = qrorder
package.domain = org.sinhvien
source.dir = .
source.include_exts = py,png,jpg,kv,xml
version = 1.0
requirements = python3,kivy==2.3.0,pillow,qrcode,pypng
orientation = portrait
fullscreen = 0
android.permissions = INTERNET
android.api = 33
android.minapi = 24
android.archs = arm64-v8a
android.accept_sdk_license = True
android.extra_manifest_application_arguments = ./extra_manifest_application_arguments.xml

[buildozer]
log_level = 2
warn_on_root = 1
