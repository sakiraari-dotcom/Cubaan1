# Waktu Solat — paparan untuk rumah dan masjid

Satu aplikasi untuk Windows (.exe) dan Android (.apk), dengan dua mod.

## Mod Rumah
- Jam besar, tarikh Masihi dan Hijrah, 7 waktu solat, kiraan masa ke waktu seterusnya
- Gambar keluarga bertukar sebagai latar

## Mod Masjid / Surau
- Jadual azan dan iqamah (minit iqamah berlainan bagi setiap waktu), nama waktu dalam Jawi
- Skrin kiraan iqamah, skrin gelap semasa solat berjemaah, mod khutbah Jumaat
- Slaid: teks (kuliah/program), poster bergambar, berita kematian
- Pengumuman bergerak + peringatan puasa sunat automatik (Isnin, Khamis, Ayyamul Bidh)
- Ayat harian bergilir (boleh diubah), QR DuitNow dan kutipan tabung Jumaat
- Bunyi beep / fail azan sendiri, skrin rehat waktu malam
- **Kawalan dari telefon**: panel web dalam aplikasi, tanpa server awan
- **Banyak TV**: TV pendua menyalin kandungan TV utama secara automatik

Sumber waktu solat: JAKIM e-Solat melalui API waktusolat.app. Data sebulan disimpan dalam peranti.

## Kawalan dari telefon (Mod Masjid)
1. Di TV, buka **Tetapan** (gerakkan tetikus / tekan `S`), pilih **Masjid / Surau**, kemudian **Simpan**.
2. Buka Tetapan semula: kod QR, alamat (cth. `http://192.168.1.20:8765`) dan **PIN** dipaparkan.
3. Telefon mesti disambung ke **Wi-Fi yang sama** dengan TV. Imbas QR, masukkan PIN.
4. Ubah kandungan, tekan **Simpan & hantar ke TV**.

Windows: kali pertama aplikasi dibuka, Windows Firewall akan bertanya — pilih **Allow** (rangkaian Private)
supaya telefon boleh sambung ke panel.

**Banyak TV:** pada TV kedua, Tetapan → Peranan TV → *TV pendua*, isi IP dan PIN TV utama.
Ia menyalin kandungan setiap minit. Urus kandungan hanya di TV utama.

## Cara dapatkan .exe dan .apk (GitHub Actions)
1. Muat naik **semua** fail folder ini ke repository GitHub (termasuk `.github`, `lib`, `assets`, `tool`).
2. Tab **Actions** → binaan "Bina EXE dan APK" berjalan sendiri (~10–15 minit).
3. Muat turun di bahagian **Artifacts**:
   - `WaktuSolat-Windows-Setup` → pemasang `.exe`
   - `WaktuSolat-Windows-Portable` → folder dengan `waktu_solat.exe` (jalan terus tanpa pasang)
   - `WaktuSolat-Android` → `WaktuSolat.apk`

## Memasang
**Windows:** jalankan `WaktuSolat-Setup.exe`. Jika keluar amaran SmartScreen, pilih *More info → Run anyway*.
**Android:** salin `WaktuSolat.apk` ke telefon/TV box, buka, benarkan "pasang dari sumber tidak diketahui" dan akses lokasi.

## Pintasan (Windows)
`F11` skrin penuh · `Esc` keluar skrin penuh · `S` tetapan

## Bina di PC sendiri (pilihan)
```
flutter create --org my.keluarga --project-name waktu_solat --platforms windows,android .
python tool/patch_android.py
flutter pub get
flutter build windows --release
flutter build apk --release
```
