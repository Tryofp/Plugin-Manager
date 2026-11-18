# Changelog — Tryo Standalone Script Hub

## V1.1 — 18/11/2026
### Collaborative Public Map & Waypoint Filter
- **NEW — UPDATE Public Map:** pemain dapat memperbarui data checkpoint pada peta publik yang sudah ada. Seluruh daftar CP diganti mengikuti SAVED terbaru, termasuk jika jumlah CP bertambah atau berkurang.
- **UPDATE — Satu peta per PlaceId:** setiap map memiliki satu data publik bersama. Upload pertama menetapkan uploader asli; upload ulang oleh siapa pun ditolak dan tidak membuat salinan baru.
- **NEW — Editor terakhir:** nama uploader asli tetap dipertahankan, sementara editor terakhir beserta waktu edit disimpan terpisah dan ditampilkan kepada semua pemain saat daftar Public Map dimuat atau di-refresh.
- **FIX — Deteksi upload duplikat:** pemeriksaan awal mencegah POST berulang untuk map yang sudah ada dan menghindari jalur redirect yang sebelumnya dapat memunculkan HTTP 405.
- **FIX — Ignore keywords:** Radar mengabaikan nama objek yang mengandung `Pilih`, `ikan`, `maks`, `max`, dan `penggiling` tanpa membedakan huruf besar/kecil.
- **Status pengujian:** alur UPDATE dan tampilan editor lintas pemain telah dikonfirmasi pengguna di beta2. Pemeriksaan source dilakukan sebelum promosi; pengujian tambahan pada beragam map tetap disarankan.

## V1.0 — 17/11/2026
### Waypoint Radar — Deteksi & Performa
- **FIX — Model checkpoint:** filter kandidat Model menerima nama seperti `CP1`, `Stage 2`, `WP3`, `Pos1`, `Ring1`, serta nama angka saja agar container checkpoint tidak terlewat.
- **UPDATE — Nomor checkpoint desimal:** parser mendukung `CP1.1`, `CP 1.1`, `CP-1.1`, `CP_1.1`, `Stage 2.5`, dan `WP3.1`. Nomor desimal tetap menjadi identitas terpisah.
- **PERFORMANCE — Pemindaian bertahap:** UI dibangun secara asynchronous, scan Workspace memberi yield berkala, refresh dan render Radar dilakukan per batch, serta pencocokan SAVED menggunakan spatial bucket.
- **FIX — Upload Public Map:** persiapan data, konversi CFrame, encoding, dan HTTP dipindahkan ke worker. Konversi rute dilakukan per batch agar tombol/UI tidak tertahan saat rute berisi banyak CP.
- **FIX — Cold-start upload:** pencarian nama Place Roblox dipanaskan di background. Upload memakai nama yang sudah tersimpan di cache atau fallback PlaceId, bukan menunggu lookup katalog saat tombol ditekan.
- **UPDATE — Changelog RGB:** tulisan Changelog! memakai animasi RGB bertransisi halus.

### Status Rilis
- Perubahan beta2 dipromosikan ke branch main sebagai V1.0.
- Pemeriksaan struktur dan sinkronisasi source dilakukan setelah pembaruan.
- Pengujian langsung di dalam game tetap disarankan, terutama untuk variasi map dan rute Public Map berukuran besar.

## V0.9 — 17/11/2026
### Waypoint Radar & Public Map
- **UPDATE — Checkpoint biasa:** `Workspace.Checkpoint.Checkpoint` kini dikenali dan diberi nomor CP1, CP2, dan seterusnya berdasarkan urutan ketinggian.
- **KEEP — Deteksi lama:** deteksi checkpoint bernomor dan seluruh aturan Summit, termasuk `Workspace.QUEST.CPSUMMIT.Part`, tetap dipertahankan.
- **NEW — AuraCP route detection:** radar mengenali checkpoint rute AuraCP dengan nomor desimal tanpa mengubah klasifikasi Summit.
- **NEW — Public Map:** integrasi Firestore untuk pencarian rute, metadata nama Place Roblox, katalog lintas map, validasi PlaceId, serta unggah, ambil, dan hapus rute.

## V0.8 — 16/11/2026
### Preset Manager
- **FIX — Interactable preset:** seluruh tujuh status Interactable (PPESP, ITP, DESP, CDESP, TESP, ITESP, dan LOOT) kini ikut disimpan dan dipulihkan melalui pengendali masing-masing.
- **FIX — Toggle indicators:** indikator hijau/abu-abu pada ketujuh Interactable disinkronkan setelah preset dimuat. Fitur yang gagal atau terkunci Maintenance tidak ditampilkan sebagai aktif.

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
- **NEW — Disable Post FX:** menonaktifkan Bloom, Blur, Color Correction, Depth of Field, dan Sun Rays yang sudah ada secara lokal.

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
- **UPDATE — Waypoint:** tampilan lebih ringkas dan responsif, termasuk penyesuaian bubble dan tab.

## V0.2 — 14/11/2026
### Camera Tools Update
- **UPDATE — Lock Kamera:** Force Unlock Camera menangani pergantian CurrentCamera dan memulihkan tipe kamera asal saat fitur dimatikan.
