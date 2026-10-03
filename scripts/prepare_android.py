from pathlib import Path
import re

manifest = Path('android/app/src/main/AndroidManifest.xml')
text = manifest.read_text(encoding='utf-8')

for permission in [
    '<uses-permission android:name="android.permission.INTERNET" />',
    '<uses-permission android:name="android.permission.CAMERA" />',
]:
    if permission not in text:
        text = text.replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">', '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    ' + permission)

text = re.sub(r'android:label="[^"]*"', 'android:label="Smark Mart"', text, count=1)
manifest.write_text(text, encoding='utf-8')

# Keep Android package identity aligned with Firebase Android registration.
build_kts = Path('android/app/build.gradle.kts')
if build_kts.exists():
    b = build_kts.read_text(encoding='utf-8')
    b = re.sub(r'applicationId\s*=\s*"[^"]+"', 'applicationId = "com.hh.smart_mart"', b)
    b = re.sub(r'namespace\s*=\s*"[^"]+"', 'namespace = "com.hh.smart_mart"', b)
    build_kts.write_text(b, encoding='utf-8')

build_gradle = Path('android/app/build.gradle')
if build_gradle.exists():
    b = build_gradle.read_text(encoding='utf-8')
    b = re.sub(r'applicationId\s+["\'][^"\']+["\']', 'applicationId "com.hh.smart_mart"', b)
    b = re.sub(r'namespace\s+["\'][^"\']+["\']', 'namespace "com.hh.smart_mart"', b)
    build_gradle.write_text(b, encoding='utf-8')

print('Android prepared for com.hh.smart_mart with camera + internet permissions.')
