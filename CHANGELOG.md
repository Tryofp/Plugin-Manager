# Changelog — Tryo Standalone Script Hub

## V0.9 — 17/11/2026
### Waypoint Radar & Public Map
- **UPDATE — Checkpoint biasa:** `Workspace.Checkpoint.Checkpoint` kini dikenali dan diberi nomor CP1, CP2, dan seterusnya berdasarkan urutan ketinggian.
- **KEEP — Deteksi lama:** deteksi checkpoint bernomor dan seluruh aturan Summit, termasuk `Workspace.QUEST.CPSUMMIT.Part`, tetap dipertahankan.
- **NEW — AuraCP route detection:** radar mengenali checkpoint rute AuraCP dengan nomor desimal tanpa mengubah klasifikasi Summit.
- **NEW — Public Map:** integrasi Firestore untuk pencarian rute, metadata nama Place Roblox, katalog lintas map, validasi PlaceId, serta unggah, ambil, dan hapus rute.

Catatan rilis resmi untuk branch `main`. Riwayat terbaru berada di bagian atas dan disinkronkan
dengan manifest `RELEASES` di `Main.lua`.

## V0.8 — 16/11/2026
### Preset Manager
- **FIX — Interactable preset:** seluruh tujuh status Interactable (PPESP, ITP, DESP, CDESP, TESP, ITESP, dan LOOT) kini ikut disimpan dan dipulihkan melalui pengendali masing-masing.
- **FIX — Toggle indicators:** indikator hijau/abu-abu pada ketujuh Interactable kini disinkronkan setelah preset dimuat. Fitur yang gagal atau terkunci Maintenance tidak ditampilkan sebagai aktif.

### Waypoint Radar
- **UPDATE — QUEST checkpoints:** radar mengenali `Workspace.QUEST.CP<number>.Part` dan mencari `ProximityPrompt` pada Part maupun container CP/ancestor terkait.
- **UPDATE — QUEST Summit:** radar mengenali `Workspace.QUEST.CPSUMMIT.Part` sebagai SUMMIT dan mencari prompt pada ancestor terkait.
- **Status pengujian:** deteksi CP dan Summit telah dikonfirmasi berjalan di game.

### Sound & View
- **UPDATE — MuteSound:** seluruh objek Sound di Workspace dan SoundService dimute tanpa pengecualian, termasuk suara karakter, checkpoint, dan respawn. Berlaku untuk fitur standalone dan command legacy.
- **UPDATE — Sound monitoring:** suara baru yang ditambahkan ke Workspace atau SoundService ikut dimute; koneksi pemantauan dibersihkan saat mute dinonaktifkan.
- **Catatan pengujian:** mute total sudah diterapkan pada source, tetapi pengujian ulang untuk memastikan gejala audio kresek telah teratasi masih diperlukan.

## V0.7 — 15/11/2026
### Changelog & Tab Organization
- **NEW — Changelog!:** riwayat versi dibuka melalui jendela khusus yang dapat di-scroll, dengan kartu terpisah untuk setiap versi dan rincian perubahannya.
- **UPDATE — No Fall Damage:** dipindahkan dari tab Horor ke Tools agar lebih mudah ditemukan.
- **UPDATE — Visual Environment:** kini tersedia di tab Gunung dan tetap tersedia di tab Horor.

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

## Aturan pemeliharaan beta2
1. Catat setiap fitur baru, perubahan perilaku, dan perbaikan bug yang berdampak ke pengguna.
2. Tandai status pengujian: `Belum diuji`, `Lulus beta2`, atau `Perlu perbaikan`.
3. Jangan masukkan perubahan ke `main` sebelum ada persetujuan rilis.
4. Saat rilis, sinkronkan catatan ini dengan manifest `RELEASES` di `Main.lua`.
5. Versi terbaru ditulis paling atas. Jangan menghapus riwayat versi sebelumnya.
