-- Badge lifecycle: UpdateTimestamp remains the feature history; visibility and clears are controlled by Metadata in Sheet.gs.
local LoaderData = {
        BadgeColor = "green",
        BadgeText = "Update!",}

-- ==========================================================
-- 🛠️ GUDANG MASTER DATA (SEMUA FITUR SERAGAM & INDEPENDEN)
-- ==========================================================
local SharedFeatures = {
    -- 1. Interactable Sub-Features
    ITP = {
        FeatureId = "fid_itp",
        Name = "ITP",
        Desc = "Memunculkan window berisikan list objek yang bisa diteleport",
        Cmd = "itp",
        UnCmd = "",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/Interactable",
        UpdateTimestamp = "091120260333, 86400"
    },
    PPESP = {
        FeatureId = "fid_ppesp",
        Name = "PPESP",
        Desc = "Masukan 1 nama objek untuk filter, kosongkan kolom untuk mendeteksi semua Objek",
        Cmd = "proximityesp",
        UnCmd = "unproximityesp",
        NeedInput = true,
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/Interactable",
        UpdateTimestamp = ""
    },
    CDESP = {
        FeatureId = "fid_cdesp",
        Name = "CDESP",
        Desc = "Masukan 1 nama objek untuk filter, kosongkan kolom untuk mendeteksi semua Objek",
        Cmd = "clickdetectoresp",
        UnCmd = "unclickdetectoresp",
        NeedInput = true,
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/Interactable",
        UpdateTimestamp = ""
    },
    DESP = {
        FeatureId = "fid_desp",
        Name = "DESP",
        Desc = "Masukan 1 nama objek untuk filter, kosongkan kolom untuk mendeteksi semua Objek",
        Cmd = "dooresp",
        UnCmd = "undooresp",
        NeedInput = true,
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/Interactable", -- ⚠️ Koma yang tadinya kurang udah ditambahin di sini
        UpdateTimestamp = ""
    },
    ITESP = {
        FeatureId = "fid_itesp",
        Name = "ITESP",
        Desc = "Masukan 1 nama objek untuk filter, kosongkan kolom untuk mendeteksi semua Objek",
        Cmd = "itemtouchesp",
        UnCmd = "untouchinterestesp",
        NeedInput = true,
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/Interactable",
        UpdateTimestamp = ""
    },
    LOOT = {
        FeatureId = "fid_loot",
        Name = "LOOT",
        Desc = "Memunculkan Box dan Nama ESP Item dengan interact Custom",
        Cmd = "loot",
        UnCmd = "unloot",
        NeedInput = true,
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/Interactable",
        UpdateTimestamp = ""
    },
    TESP = {
        FeatureId = "fid_tesp",
        Name = "TESP",
        Desc = "Memunculkan ESP Trigger / Scene Event",
        Cmd = "touchinterestesp",
        UnCmd = "untouchinterestesp",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/Interactable",
        UpdateTimestamp = ""
    },

    -- 2. ESP Player Sub-Features
    PESP = {
        FeatureId = "fid_pesp",
        Name = "Player ESP",
        Desc = "Menampilkan ESP Body dan mama Player",
        Cmd = "pesp",
        UnCmd = "unloadColorESP",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/colorESP",
        UpdateTimestamp = ""
    },
    EESP = {
        FeatureId = "fid_eesp",
        Name = "Enemy ESP",
        Desc = "Menampilkan ESP Musuh dan NPC",
        Cmd = "eesp",
        UnCmd = "unloadColorESP",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/colorESP",
        UpdateTimestamp = ""
    },

    -- 3. Waypoint & Teleport Sub-Features
    SCP = {
        FeatureId = "fid_scp",
        Name = "Radar Checkpoint",
        Desc = "Menampilkan Checkpoint yang belum di sentuh",
        Cmd = "scp",
        UnCmd = "",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/Waypoint",
        UpdateTimestamp = "091120262315, 86400",
        BadgeColor = "green",
        BadgeText = "Update!"
    },
    CPN = {
        FeatureId = "fid_cpn",
        BadgeColor = "green",
        BadgeText = "Update!",
        Name = "CP & Waypoint",
        Desc = "Menampilkan Checkpoint atau Waypoint",
        Cmd = "cpn",
        UnCmd = "",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/Waypoint",
        UpdateTimestamp = "091120262315, 86400"
    },
    PlayerTeleport = {
        FeatureId = "fid_playerteleport",
        Name = "Teleport to Player",
        Desc = "Teleport ke player dengan cepat ( Jika dalam Jangkauan )",
        Cmd = "tp",
        UnCmd = "",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/PlayerTeleport",
        UpdateTimestamp = "091120260255, 86400"
    },

    -- 4. Sound & View Sub-Features
    Spectator = {
        BadgeColor = "green",
        BadgeText = "Update!",
        FeatureId = "fid_spectator",
        Name = "Spectator",
        Desc = "Menonton dan menguping target dari jauh ( Jika dalam Jangkauan )",
        Cmd = "spectate",
        UnCmd = "",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/SoundandView",
        UpdateTimestamp = "101120260036, 86400"
    },
    MuteSound = {
        FeatureId = "fid_mutesound",
        BadgeColor = "green",
        BadgeText = "Update!",
        Name = "Mute Sound",
        Desc = "Membisukan suara Latar Belakang Map",
        Cmd = "mutesound",
        UnCmd = "unmutesound",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/SoundandView",
        UpdateTimestamp = "101120260036, 86400"
    },
    PlayMusic = {
        BadgeColor = "green",
        BadgeText = "Update!",
        FeatureId = "fid_playmusic",
        Name = "Play Music",
        Desc = "Mendengarkan musik",
        Cmd = "playmusic",
        UnCmd = "stopmusic",
        NeedInput = true,
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/MusicTimeML",
        UpdateTimestamp = "091120261116, 86400"
    },

    -- 5. Fun Sub-Features & Standalone Tools
    TPitem = {
        FeatureId = "fid_tpitem",
        Name = "Teleport to Item",
        Desc = "tidak untuk semua map, hanya untuk Map yang bertema merapihkan barang",
        Cmd = "rgrab",
        UnCmd = "",
        ExecutionMode = "standalone",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/TPitem",
        UpdateTimestamp = "091120261054, 86400",
        BadgeText = "Update!",
        BadgeColor = "green"
    },
    Clickinspector = {
        FeatureId = "fid_clickinspector",
        Name = "Inspector",
        Desc = "Menemukan sebuah jalur path parent-child sebuah Part",
        Cmd = "mobileinspector",
        UnCmd = "",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Tools/clickinspector",
        UpdateTimestamp = "091120260314, 86400"
    },
    AntiAFK = {
        FeatureId = "fid_antiafk",
        Name = "Anti AFK",
        Desc = "Membuat karakter tidak terpental saat Afk 20 menit di Map",
        Cmd = "antiafk",
        UnCmd = "unantiafk",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Tools/AntiAFK",
        UpdateTimestamp = ""
    },

    -- 6. Rejoin Sub-Features
    AutoSave = {
        FeatureId = "fid_autosave",
        Name = "Auto Save",
        Desc = "Auto save Place ID dan Job ID ketika berpindah tempat",
        Cmd = "autosaveserver",
        UnCmd = "",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/LastRejoin",
        UpdateTimestamp = "081120262105, 86400",
        BadgeText = "Update!",
        BadgeColor = "green"
    },
    SaveServer = {
        FeatureId = "fid_saveserver",
        Name = "Save Server",
        Desc = "Menyimpan Place ID dan Job ID secara manual",
        Cmd = "saveserver",
        UnCmd = "",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/LastRejoin",
        UpdateTimestamp = "081120262105, 86400",
        BadgeText = "Update!",
        BadgeColor = "green"
    },
    LastRejoin = {
        FeatureId = "fid_lastrejoin",
        Name = "Last Rejoin",
        Desc = "Aktifkan untik Rejoin di server terakhir",
        Cmd = "rejoinlast",
        UnCmd = "",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/LastRejoin",
        UpdateTimestamp = "081120262105, 86400"
    },
    SmartRejoin = {
        FeatureId = "fid_smartrejoin",
        Name = "Smart Rejoin",
        Desc = "Aktifkan untuk Rejoin ketika diconnect secara Real Time",
        Cmd = "smartrj",
        UnCmd = "smartrj",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/SmartRejoin",
        UpdateTimestamp = ""
    },

    -- 7. Aimbot Sub-Features
    Aimbot = {
        FeatureId = "fid_aimbot",
            BadgeColor = "green",
            BadgeText = "Update!",
        Name = "Aimbot",
        Desc = "Mengaktifkan/Menonaktifkan Aimbot",
        Cmd = "startaimbot",
        UnCmd = "stopaimbot",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/SimpleAimbot",
        UpdateTimestamp = "091120260421, 86400"
    },
    SetRadius = {
        FeatureId = "fid_setradius",
            BadgeColor = "green",
            BadgeText = "Update!",
        Name = "Set Radius",
        Desc = "Menentukan Radius Aimbot",
        Cmd = "setradius",
        UnCmd = "",
        NeedInput = true,
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/SimpleAimbot",
        UpdateTimestamp = "091120260421, 86400"
    },

    -- 8. F1Lock Sub-Features
    F1Lock = {
        FeatureId = "fid_f1lock",
        Name = "F1LOCK",
        Desc = "Bind Shift Lock to F1",
        Cmd = "f1lock",
        UnCmd = "unlockedcam",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/F1Lock",
        UpdateTimestamp = ""
    },

    -- 9. Anti Effect Group Sub-Features
    Anchor = {
        BadgeColor = "green",
        BadgeText = "Update!",
        FeatureId = "fid_anchor",
        Name = "Anchor ( Hanya Visual )",
        Desc = "Untuk menghentikan Part yang bergoyang",
        Cmd = "anchor",
        UnCmd = "unanchor",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Tools/AntiEffect",
        UpdateTimestamp = "111120260227, 86400"
    },
    AntiShake = {
        BadgeColor = "green",
        BadgeText = "Update!",
        FeatureId = "fid_antishake",
        Name = "Anti Shake",
        Desc = "Untuk menghentikan Kamera yang bergoyang",
        Cmd = "antishake",
        UnCmd = "unshake",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Tools/AntiEffect",
        UpdateTimestamp = "111120260227, 86400"
    },
    AntiWind = {
        BadgeColor = "green",
        BadgeText = "Update!",
        FeatureId = "fid_antiwind",
        Name = "Anti Wind ( Client Side )",
        Desc = "Untuk menghentikan Angin yang menggeser karakter",
        Cmd = "antiwind",
        UnCmd = "unwind",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Tools/AntiEffect",
        UpdateTimestamp = "111120260227, 86400"
    },
    AntiTrigger = {
        BadgeColor = "green",
        BadgeText = "Update!",
        FeatureId = "fid_antitrigger",
        Name = "Anti Trigger",
        Desc = "Untuk mematikan Trigger dalam map",
        Cmd = "antitrigger",
        UnCmd = "untrigger",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Tools/AntiEffect",
        UpdateTimestamp = "111120260227, 86400"
    },

    -- 10. Standalone Tools Lainnya
    Fullbright = {
        BadgeColor = "green",
        BadgeText = "Update!",
        FeatureId = "fid_fullbright",
        Name = "Full Bright",
        Desc = "Membuat game menjadi terang, sudah termasuk anti kabut dan shadow",
        Cmd = "fullbright",
        UnCmd = "fullbright",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Tools/Fullbright",
        UpdateTimestamp = "121120260114, 86400"
    },
    InstantPrompt = {
        FeatureId = "fid_instantprompt",
        Name = "Instant Prompts",
        Desc = "Always instant interaction",
        Cmd = "instantprompts",
        UnCmd = "uninstantprompts",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Tools/InstanPrompt",
        UpdateTimestamp = ""
    },
    WalkSpeed = {
        BadgeColor = "green",
        BadgeText = "Update!",
        FeatureId = "fid_walkspeed",
        Name = "Walk Speed",
        Desc = "Masukan angka speed yang kami mau, misal 20 ( tergantung map )",
        Cmd = "ws",
        UnCmd = "unws",
        NeedInput = true,
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Tools/WalkSpeed",
        UpdateTimestamp = "101120260014, 86400"
    },
    InfiniteJump = {
        FeatureId = "fid_infinitejump",
        Name = "Infinite Jump",
        Desc = "Melompat tanpa batas dan Melampauinyaaaa...",
        Cmd = "infjump",
        UnCmd = "uninfjump",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Tools/InfiniteJump",
        UpdateTimestamp = ""
    },
    AdminDetect = {
        FeatureId = "fid_admindetect",
        BadgeColor = "green",
        BadgeText = "Update!",
        Name = "Admin Detect",
        Desc = "Mendeteksi Owner dan Admin, tunggu beberapa detik setelah Execute",
        Cmd = "cad",
        UnCmd = "",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Tools/AdminDetect",
        UpdateTimestamp = "091120262346, 86400"
    },
    Noclip = {
        FeatureId = "fid_noclip",
        Name = "Noclip",
        Desc = "Menembus Objek yang ada di depan, tapi agak lebih pinter dikit",
        Cmd = "noclip",
        UnCmd = "unnoclip",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Tools/Noclip",
        UpdateTimestamp = ""
    },
    CodeFinder = {
        FeatureId = "fid_codefinder",
        Name = "Code Finder",
        Desc = "Menemukan Code angka dan Huruf",
        Cmd = "code",
        UnCmd = "",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Tools/CodeFinder",
        UpdateTimestamp = ""
    }
}

-- ==========================================================
-- 📂 STRUKTUR TAB UTAMA (SUDAH RINGKAS & BERSIH)
-- ==========================================================
LoaderData.Tabs = {
    { Name = "Main", DataKey = "Main" },
    { Name = "Gunung", DataKey = "Gunung" },
    { Name = "Horor", DataKey = "Horor" },
    { Name = "Tools", DataKey = "Tools" },
    { Name = "KAMING SUN", DataKey = "" }
}

LoaderData.Main = {    
    {
        Name = "ESP Player",
        Desc = "Player & Enemy ESP",
        RawUrl = "",
        SubFeatures = {
            SharedFeatures.PESP,
            SharedFeatures.EESP
        }
    },
    {
        Name = "Teleport",
        Desc = "Waypoint & Teleport",
        RawUrl = "",
        SubFeatures = {
            SharedFeatures.SCP,
            SharedFeatures.CPN,
            SharedFeatures.PlayerTeleport,
            SharedFeatures.TPitem
        }
    },
    {
        BadgeColor = "green",
        BadgeText = "Update!",
        UpdateTimestamp = "091120260255, 86400",
        Name = "Sound & View Manage",
        Desc = "Mengatur suara di map dan memutar Lagu",
        RawUrl = "",
        SubFeatures = {
            SharedFeatures.Spectator,
            SharedFeatures.MuteSound,
            SharedFeatures.PlayMusic
        }
    },
    {
        Name = "Rejoin ( Public Server )",
        Desc = "Rejoin Manage ( Tidak Support game Berlobby )",
        RawUrl = "",
        SubFeatures = {
            SharedFeatures.AutoSave,
            SharedFeatures.SaveServer,
            SharedFeatures.LastRejoin,
            SharedFeatures.SmartRejoin
        }
    },
    {
            BadgeColor = "green",
            BadgeText = "Update!",
            UpdateTimestamp = "091120260421, 86400",
        Name = "Simple Aimbot",
        Desc = "Aimbot Untuk Map yang mempunyai fitur Shooter",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/SimpleAimbot",
        SubFeatures = {
            SharedFeatures.Aimbot,
            SharedFeatures.SetRadius
        }
    },
    {
        Name = "F1Lock ( Khusus Keyboard )",
        Desc = "Mengubah Shift Lock ke F1",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/F1Lock",
        SubFeatures = {
            SharedFeatures.F1Lock
        }
    }
}

LoaderData.Gunung = {
    {
        Name = "Teleport",
        Desc = "Waypoint & Teleport",
        RawUrl = "",
        SubFeatures = {
            SharedFeatures.SCP,
            SharedFeatures.CPN,
            SharedFeatures.PlayerTeleport
        }
    },
    SharedFeatures.InfiniteJump,
    SharedFeatures.InstantPrompt,
    SharedFeatures.PESP,
    {
        Name = "Interactable / ITP",
        Desc = "Memunculkan ESP Objek berdasarkan Promot, Touch, Click, Pintu atau Trigger",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/Interactable",
        SubFeatures = {
            SharedFeatures.ITP,
            SharedFeatures.PPESP,
            SharedFeatures.CDESP,
            SharedFeatures.DESP,
            SharedFeatures.ITESP,
            SharedFeatures.TESP
        }
    },
    SharedFeatures.WalkSpeed,
    {
        Name = "Sound & View Manage",
        Desc = "Mengatur suara di map dan memutar Lagu",
        RawUrl = "",
        SubFeatures = {
            SharedFeatures.Spectator,
            SharedFeatures.MuteSound,
            SharedFeatures.PlayMusic
        }
    }
}

LoaderData.Horor = {
    {
        Name = "Interactable / ITP",
        Desc = "Memunculkan ESP Objek berdasarkan Promot, Touch, Click, Pintu atau Trigger",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/Interactable",
        SubFeatures = {
            SharedFeatures.ITP,
            SharedFeatures.PPESP,
            SharedFeatures.CDESP,
            SharedFeatures.DESP,
            SharedFeatures.ITESP,
            SharedFeatures.TESP
        }
    },
    {
        Name = "Color ESP",
        Desc = "Player & Enemy ESP",
        RawUrl = "https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/beta/Plugin/colorESP",
        SubFeatures = {
            SharedFeatures.PESP,
            SharedFeatures.EESP
        }
    },
    SharedFeatures.Fullbright,
    SharedFeatures.InstantPrompt,
    SharedFeatures.MuteSound,
    SharedFeatures.InfiniteJump,
    SharedFeatures.WalkSpeed,
    SharedFeatures.Noclip,
    SharedFeatures.CodeFinder
}

LoaderData.Tools = {
    SharedFeatures.Fullbright,
    SharedFeatures.InstantPrompt,
    SharedFeatures.WalkSpeed,
    SharedFeatures.InfiniteJump,
    SharedFeatures.AdminDetect,
    SharedFeatures.Noclip,
    SharedFeatures.CodeFinder,
    SharedFeatures.AntiAFK,
    SharedFeatures.Clickinspector,
    {
        Name = "Effect",
        Desc = "Menghentikan Effect dan Part yang bandel",
        RawUrl = "",
        SubFeatures = {
            SharedFeatures.Anchor,
            SharedFeatures.AntiShake,
            SharedFeatures.AntiWind,
            SharedFeatures.AntiTrigger
        }
    }
}

return LoaderData