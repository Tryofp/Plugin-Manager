# Tryo Script Hub

Standalone Roblox Script Hub — tidak membutuhkan Infinite Yield.

## Loader (Stable)

Jalankan script berikut melalui executor Roblox yang mendukung `game:HttpGet` dan `loadstring`:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/main/Main.lua"))()
```

Script Hub memuat UI, Runtime, dan seluruh fitur langsung dari branch `main`, sehingga pembaruan tidak memerlukan penggantian loader.

## Branch

- `main` — rilis stable Tryo Script Hub (standalone).
- `beta2` — staging/pengembangan Script Hub; perubahan diuji di sini sebelum dipromosikan.
- `beta` — jalur legacy Plugin Manager untuk Infinite Yield.

## Catatan kompatibilitas

Aset Plugin Manager lama masih dipertahankan di repository untuk kompatibilitas dan referensi. Loader stable di atas menggunakan `Main.lua`, `UI/Library.lua`, `Runtime/FeatureManager.lua`, dan modul di `Features/`; tidak bergantung pada Infinite Yield.
