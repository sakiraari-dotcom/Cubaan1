"""Tambah kebenaran yang diperlukan ke AndroidManifest.xml selepas `flutter create`."""
import re

PATH = "android/app/src/main/AndroidManifest.xml"
PERMS = ["INTERNET", "ACCESS_COARSE_LOCATION", "ACCESS_FINE_LOCATION", "WAKE_LOCK"]

with open(PATH, encoding="utf-8") as f:
    s = f.read()

missing = [p for p in PERMS if f"android.permission.{p}" not in s]
if missing:
    lines = "".join(
        f'\n    <uses-permission android:name="android.permission.{p}"/>' for p in missing
    )
    s = re.sub(r"(<manifest[^>]*>)", lambda m: m.group(1) + lines, s, count=1)

s = s.replace('android:label="waktu_solat"', 'android:label="Waktu Solat"')

# Benarkan HTTP dalam rangkaian tempatan (TV pendua menyalin dari TV utama)
if "usesCleartextTraffic" not in s:
    s = s.replace("<application", '<application\n        android:usesCleartextTraffic="true"', 1)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(s)

print("AndroidManifest dikemas kini:", ", ".join(missing) or "tiada perubahan")
