# Task & Slash

> **Pomodoro × Hack & Slash** — Produktif sambil bertarung.

**Task & Slash** adalah game 2.5D action berbasis sistem Pomodoro. Selama sesi fokus, player bekerja/belajar. Ketika timer habis, gerbang arena terbuka dan player harus menghadapi gelombang musuh sebelum kembali ke meja kerja.

---

## 🎮 Gameplay Loop

```
Main Menu → Cafe (FOCUS) → [timer habis] → Cafe (READY) → [Enter] → Arena (ACTION) → [babak selesai] → Summary → Cafe
```

| Fase | Deskripsi |
|---|---|
| **FOCUS** | Timer fokus berjalan. Kerjakan pekerjaan kamu. |
| **READY** | Timer habis. Tekan Enter untuk masuk ke arena. |
| **ACTION** | Fase combat. Kalahkan semua gelombang musuh. |

---

## 🕹️ Kontrol

| Tombol | Aksi |
|---|---|
| `←` / `→` | Gerak kiri/kanan |
| `Space` | Lompat |
| `Shift` | Dash (i-frames aktif selama dash) |
| `Enter` | Serang / Counter Dash (saat enemy charging) |
| `Esc` | Pause |

---

## ⚔️ Sistem Combat

### Tipe Musuh
| Tipe | Warna | HP | Kecepatan | Charge Window | Skor |
|---|---|---|---|---|---|
| Melee | Merah | 3 | Normal | 0.75 dtk | +10 |
| Ranged | Biru | 2 | Lambat | 0.90 dtk | +25 |
| Fast | Oranye | 1 | 2× Cepat | 0.40 dtk | +15 |

### Sistem Serangan
- **Soft Lock-On**: Player otomatis menghadap musuh terdekat setiap frame.
- **Dash Attack**: Saat menyerang, player melakukan dash kecil ke arah musuh terkunci.
- **Area Splash**: Enemy di sekitar target utama (radius 1.8u) juga terkena damage.

### Mechanic Khusus
| Mechanic | Cara | Efek |
|---|---|---|
| **Counter Dash** | Tekan Enter saat melihat flash kuning musuh | Dash ke samping musuh, AoE damage, knockback |
| **Dodge** | Tekan Shift sebelum serangan mengenai | I-frames aktif, serangan melewati player |

### Telegraph System
Setiap musuh menampilkan **flash cahaya** sebelum menyerang (0.4–0.9 detik tergantung tipe). Maksimal **2 musuh** bisa charging secara bersamaan — sisanya menunggu giliran.

---

## 📊 Sistem Progres

- **Wave Scaling**: Setiap wave menambah jumlah musuh. Fast Enemy muncul mulai wave 3.
- **Combo System**: Serangan beruntun meningkatkan multiplier damage (max 3×).
- **Score**: Akumulasi skor per sesi berdasarkan tipe musuh yang dikalahkan.
- **Post-Combat Summary**: Setelah sesi ACTION selesai, ditampilkan ringkasan statistik sebelum kembali ke Cafe.

---

## ⚙️ Pengaturan

Dapat diakses dari Main Menu → Pengaturan:
- **Durasi Fokus** (menit): Panjang sesi kerja sebelum masuk combat.
- **Durasi Combat** (menit): Batas waktu fase ACTION.
- **Volume**: Master, BGM, SFX.

Pengaturan disimpan otomatis ke `user://settings.cfg`.

---

## 🏗️ Struktur Proyek

```
Task-and-Slash/
├── Scenes/
│   ├── MainMenu.tscn        # Layar utama
│   ├── Cafe.tscn            # Fase fokus & ready
│   ├── World.tscn           # Fase combat / arena
│   ├── SettingsMenu.tscn    # Pengaturan
│   ├── enemy.tscn           # Musuh melee (merah)
│   ├── ranged_enemy.tscn    # Musuh jarak jauh (biru)
│   ├── fast_enemy.tscn      # Musuh cepat (oranye)
│   ├── projectile.tscn      # Proyektil ranged
│   ├── attack_flash.tscn    # Telegraph visual musuh
│   ├── damage_number.tscn   # Floating damage / text
│   └── death_burst.tscn     # Efek mati musuh
│
├── Scripts/
│   ├── game_manager.gd      # [Autoload] State machine & timer global
│   ├── audio_manager.gd     # [Autoload] Sistem volume & konfigurasi audio
│   ├── scene_transition.gd  # [Autoload] Fade antar scene
│   ├── player.gd            # Karakter player (lock-on, counter dash, combo)
│   ├── enemy.gd             # AI musuh melee
│   ├── ranged_enemy.gd      # AI musuh jarak jauh
│   ├── world_manager.gd     # Manajer wave, HUD, pause, summary
│   ├── cafe_manager.gd      # Manajer fase Cafe
│   ├── main_menu.gd         # UI main menu
│   ├── settings_menu.gd     # UI pengaturan
│   ├── camera.gd            # Kamera + screen shake
│   ├── projectile.gd        # Logika proyektil
│   ├── damage_number.gd     # Floating label (damage, PARRY!, DODGE!, dll.)
│   ├── death_burst.gd       # VFX kematian musuh
│   └── attack_flash.gd      # VFX telegraph musuh
│
└── Assets/                  # Aset visual & audio (WIP)
```

---

## 🛠️ Tech Stack

- **Engine**: [Godot 4.5](https://godotengine.org/)
- **Bahasa**: GDScript
- **Platform Target**: Web (Browser) — dimainkan langsung di [itch.io](https://itch.io)

---

## 🚀 Cara Memainkan

### 🌐 Versi Web (Itch.io)

> **Main langsung di browser — tidak perlu install apapun.**
>
> 🔗 **[Klik di sini untuk memainkan di itch.io](https://p-esc.itch.io/task-and-slash)**

Rekomendasi browser: Chrome / Firefox versi terbaru.

### 🛠️ Menjalankan dari Source Code

1. Clone repo ini
2. Buka [Godot 4.5+](https://godotengine.org/download)
3. Import proyek dari folder root
4. Jalankan scene `res://Scenes/MainMenu.tscn`

Untuk export ke Web:
```
Project → Export → Web (HTML5) → Export Project
```

---

## 📋 Status Pengembangan

| Sistem | Status |
|---|---|
| State machine (FOCUS/READY/ACTION) | ✅ Selesai |
| Combat dasar (attack, dash, combo) | ✅ Selesai |
| Telegraph + Counter Dash | ✅ Selesai |
| 3 tipe musuh | ✅ Selesai |
| Wave progression | ✅ Selesai |
| HUD (HP, kills, combo, wave, score) | ✅ Selesai |
| Post-combat summary | ✅ Selesai |
| Settings menu (timer + audio) | ✅ Selesai |
| Scene fade transition | ✅ Selesai |
| Death burst VFX | ✅ Selesai |
| Hit flash + damage numbers | ✅ Selesai |
| Soft lock-on system | ✅ Selesai |
| Pause menu (World & Cafe) | ✅ Selesai |
| Sprite / Animasi karakter | 🔲 Belum |
| BGM & SFX | 🔲 Belum |
| Boss enemy | 🔲 Belum |

---

## 📝 Lisensi

[MIT License](LICENSE) — bebas digunakan dan dimodifikasi.
