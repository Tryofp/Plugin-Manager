# Changelog — Tryo Standalone Script Hub

## Unreleased — 16/11/2026
### Sound & View
- **UPDATE — MuteSound:** whitelist dipersempit ke suara checkpoint/respawn dan suara di dalam karakter player; musik, BGM, radio, boombox, jukebox, serta suara map lain ikut dimute.
- **UPDATE — MuteSound:** pemantauan suara baru mencakup Workspace dan SoundService, serta koneksi dibersihkan saat command dipanggil ulang atau mute dinonaktifkan.
- **Status pengujian:** Belum diuji di game; perlu konfirmasi apakah suara kresek-kresek sudah hilang dan tiga kategori suara tetap terdengar.

### Waypoint Radar
- **NEW — QUEST path checkpoint detection:** radar mengenali `Workspace.QUEST.CP<number>.Part` dan mencari `ProximityPrompt` pada Part maupun container CP/ancestor terkait. Aturan checkpoint lama (CP bernama, Summit, dan Checkpoint biasa) tetap dipertahankan.
- **NEW — QUEST summit detection:** radar mengenali `Workspace.QUEST.CPSUMMIT.Part` sebagai `SUMMIT`, dengan pencarian ProximityPrompt pada ancestor terkait.
- **Status pengujian:** CP dan Summit sudah dikonfirmasi terdeteksi di game.

Dokumen ini adalah sumber catatan perubahan untuk branch `beta2`.
Setiap fitur atau perbaikan yang siap diuji harus dicatat di sini. Sebelum rilis ke `main`,
bandingkan perubahan branch dengan dokumen ini, lalu perbarui riwayat versi pada
`Main.lua` agar tombol **Changelog!** menampilkan informasi yang sama.

## V0.6 — 15/11/2026
### Movement & Visual Update
- **UPDATE — WalkSpeed:** menggunakan `GetPropertyChangedSignal("WalkSpeed")` seperti loopws dan otomatis dipasang kembali setelah respawn.
- **NEW — No Fall Damage:** perlindungan jatuh tinggi berdasarkan jarak turun dari titik puncak, tanpa memperlambat lompatan normal.
- **UPDATE — Brightness & Ambient:** pengaturan brightness dan ambient lokal digabung dalam satu kontrol.
- **NEW — No Fog:** mengurangi fog dan efek Atmosphere yang sudah ada secara lokal.
- **NEW — Daylight:** mengatur waktu lingkungan ke siang hari secara lokal.
- **NEW — Disable Shadows:** menonaktifkan GlobalShadows secara lokal.
- **NEW — Disable Post FX:** menonaktifkan Bloom, Blur, Color Correction, Depth of Field, dan Sun Rays yang sudah ada.

## V0.5 — 15/11/2026
### Admin Detector Status Update
- **UPDATE — Admin Detector:** setelah pemindaian awal selesai tanpa menemukan admin atau staff, hub menampilkan notifikasi status aman.

## V0.4 — 15/11/2026
### Preset Manager
- **NEW — Preset Manager:** menyimpan, memuat, mengganti nama, dan menghapus preset.
- Lima slot tersedia sejak awal; pengguna dapat menambahkan slot tanpa batas.

## V0.3 — 15/11/2026
### UI & Waypoint Improvements
- **UPDATE — Responsive UI:** skala dan tata letak window menyesuaikan ukuran viewport perangkat.
- **UPDATE — Waypoint:** tampilan lebih ringkas dan responsif, termasuk penyesuaian bubble dan penomoran checkpoint biasa.

## V0.2 — 14/11/2026
### Camera Tools Update
- **UPDATE — Lock Kamera:** Force Unlock Camera menangani pergantian CurrentCamera dan memulihkan tipe kamera asal saat fitur dimatikan.

---

## Aturan pemeliharaan beta2
1. Catat setiap fitur baru, perubahan perilaku, dan perbaikan bug yang berdampak ke pengguna.
2. Tandai status pengujian: `Belum diuji`, `Lulus beta2`, atau `Perlu perbaikan`.
3. Jangan masukkan perubahan ke `main` sebelum ada persetujuan rilis.
4. Saat rilis, sinkronkan catatan ini dengan manifest `RELEASES` di `Main.lua`.
5. Versi terbaru ditulis paling atas. Jangan menghapus riwayat versi sebelumnya.
