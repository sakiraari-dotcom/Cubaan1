# Waktu Solat — paparan jam & gambar keluarga

Aplikasi paparan penuh skrin untuk Windows (.exe) dan Android (.apk):

- Jam besar, tarikh Masihi dan Hijrah
- 7 waktu solat (Imsak, Subuh, Syuruk, Zohor, Asar, Maghrib, Isyak) di bawah, waktu seterusnya disorot dengan kiraan masa
- Gambar latar bertukar setiap beberapa saat (selang boleh ditetapkan)
- Zon JAKIM dikesan auto melalui lokasi peranti / Wi-Fi / internet, atau pilih sendiri
- Data waktu sebulan disimpan dalam peranti, jadi masih berfungsi bila internet terputus
- Skrin tidak padam; Windows: buka automatik bila PC dihidupkan (boleh dimatikan)

Sumber data: JAKIM e-Solat melalui API waktusolat.app.

## Cara dapatkan .exe dan .apk (GitHub Actions)

1. Buat repository baharu di GitHub (boleh private), contohnya `waktu-solat`.
2. Muat naik **semua** fail dalam folder ini, termasuk folder tersembunyi `.github`.
   - Cara paling mudah: GitHub Desktop, atau `git push`.
   - Jika guna "Upload files" di laman GitHub, pastikan folder `.github/workflows` turut dimuat naik.
3. Pergi ke tab **Actions**. Binaan "Bina EXE dan APK" berjalan sendiri (~10–15 minit).
4. Bila siap (tanda hijau), buka binaan itu dan muat turun di bahagian **Artifacts**:
   - `WaktuSolat-Windows` → `WaktuSolat-Setup.exe` (pemasang) dan versi portable (.zip)
   - `WaktuSolat-Android` → `WaktuSolat.apk`

Untuk pautan muat turun kekal (tanpa log masuk), buat tag versi:
`git tag v1.0.0 && git push --tags` — fail akan diterbitkan di **Releases**.

## Memasang

**Windows:** jalankan `WaktuSolat-Setup.exe`. Jika keluar amaran SmartScreen, pilih
*More info → Run anyway* (aplikasi tidak ditandatangani secara digital).
Untuk lokasi auto yang lebih tepat, hidupkan *Settings → Privacy & security → Location*.

**Android:** salin `WaktuSolat.apk` ke telefon dan buka. Benarkan
"pasang dari sumber tidak diketahui" bila diminta, kemudian benarkan akses lokasi.

## Penggunaan

- Gerakkan tetikus / sentuh skrin → butang ⚙ Tetapan muncul di penjuru kanan atas
- Windows: `F11` skrin penuh, `Esc` keluar skrin penuh, `S` buka tetapan
- Tetapan: tambah gambar atau pilih folder gambar (Windows), selang tukar gambar,
  format 12/24 jam, zon manual, buka automatik

## Bina di PC sendiri (pilihan)

Pasang Flutter (stable), kemudian dalam folder ini:

```
flutter create --org my.keluarga --project-name waktu_solat --platforms windows,android .
python tool/patch_android.py
flutter pub get
flutter build windows --release   # hasil: build\windows\x64\runner\Release\waktu_solat.exe
flutter build apk --release       # hasil: build\app\outputs\flutter-apk\app-release.apk
```
