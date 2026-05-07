This is a Prototype. That means all of it created using AI.
# Task & Slash

> **Pomodoro × Hack & Slash** — Produktif sambil bertarung.

**Task & Slash** adalah game 2.5D action berbasis sistem Pomodoro. Selama sesi fokus, player bekerja/belajar sambil mencatat tugas. Ketika timer habis, gerbang arena terbuka dan player harus menghadapi gelombang musuh sebelum kembali ke meja kerja.

---

## 🎮 Gameplay Loop

```
Main Menu → Cafe (FOCUS) → [timer habis] → Cafe (READY) → [Enter] → Arena (ACTION) → [babak selesai] → Summary → Cafe
```

| Fase | Deskripsi |
|---|---|
| **FOCUS** | Timer fokus berjalan. Kerjakan tugasmu dan catat di Task List. |
| **READY** | Timer habis. Tekan Enter untuk masuk ke arena. |
| **ACTION** | Fase combat. Kalahkan semua gelombang musuh. |
| **LONG BREAK** | Setelah 4 sesi FOCUS, sinyal istirahat panjang diberikan. |

---

## 🕹️ Kontrol

| Tombol | Aksi |
|---|---|
| `A` / `D` | Gerak kiri/kanan |
| `Space` | Lompat |
| `Shift` | Dash (i-frames aktif) — **Bullet Time** saat ada ancaman |
| `Enter` | Serang / **Counter Dash** (saat enemy charging) |
| `Esc` | Pause |

---

## ⚔️ Sistem Combat

### Tipe Musuh
| Tipe | Warna | HP | Kecepatan | Charge Window | Skor |
|---|---|---|---|---|---|
| Melee | Merah | 3 | Normal | 0.75 dtk | +10 |
| Ranged | Biru | 2 | Lambat | 0.90 dtk | +25 |
| Fast | Oranye | 1 | 2× Cepat | 0.40 dtk | +15 |
| **Boss** | **Ungu/Emas** | **20** | **Sedang** | **1.0–1.6 dtk** | **+100** |

### Sistem Serangan
- **Soft Lock-On**: Player otomatis menghadap musuh terdekat setiap frame.
- **Dash Attack**: Saat menyerang, player melakukan dash kecil ke arah musuh terkunci.
- **Area Splash**: Enemy di sekitar target utama (radius 1.8u) juga terkena damage.
- **Charge Interrupt**: Enemy yang kena hit saat charging kehilangan giliran serangan + masuk cooldown penuh. Flash telegraph langsung menghilang.

### Mechanic Khusus
| Mechanic | Cara | Efek |
|---|---|---|
| **Counter Dash** | Tekan Enter saat melihat flash kuning musuh | Dash ke samping, AoE damage, knockback, cinematic slowmo + zoom |
| **Dodge** | Tekan Shift sebelum serangan mengenai | I-frames aktif, serangan melewati player |
| **Bullet Time** | Dash saat ada musuh charging / proyektil mendekat | Dunia melambat sesaat — player bisa "melihat" ancaman |
| **Parry Knockback** | Berhasil Counter Dash musuh biasa | Musuh terpental jauh (boss tidak terpengaruh) |

### Telegraph System
Setiap musuh menampilkan **flash cahaya** sebelum menyerang (0.4–1.6 detik tergantung tipe). Maksimal **2 musuh biasa** bisa charging bersamaan — sisanya antre.

---

## 👹 Boss Enemy

Boss muncul setiap **wave ke-5** (wave 5, 10, 15, ...). Ukuran 1.5× lebih besar, berwarna ungu bercahaya.

### Pola Serangan Boss (Acak Berbobot)
| Tipe | Peluang | Deskripsi |
|---|---|---|
| Melee | ~50% | Serangan jarak dekat biasa |
| Ranged | ~30% | Tembak proyektil ke arah player |
| ⚡ **Shockwave** | ~20% | Serangan khusus — **tidak bisa di-parry atau di-dodge** |

### Shockwave Attack
- **Indikator**: Boss berpendar **oranye terang** + muncul teks `⚡ SHOCKWAVE!`
- **Charge time**: 1.6 detik (lebih lama dari serangan biasa — ada waktu untuk lari)
- **Efek saat kena**: `-15 HP` + **knockback besar** terlepas dari parry/dash
- **Cara menghindari**: Lari menjauhi boss hingga jarak > 3.5 unit sebelum charge selesai

---

## 📊 Sistem Progres

- **Wave Scaling**: Setiap wave menambah jumlah dan HP musuh. Fast enemy mulai wave 3, Boss mulai wave 5.
- **Combo System**: Serangan beruntun meningkatkan multiplier damage. Combo ke-3 → finisher 2× damage.
- **Heal Drop**: 30% chance player mendapat +15 HP saat musuh mati.
- **Score & Highscore**: Skor akumulasi per sesi, disimpan permanen ke disk.
- **Post-Combat Summary**: Statistik sesi (kills, wave, skor, highscore) + tombol kembali ke Cafe.
- **Riwayat Sesi**: Jumlah sesi Pomodoro yang selesai ditampilkan di Main Menu.

---

## 📋 Task List (Fitur Pomodoro)

Panel task list tersedia di sisi kanan layar **selama fase FOCUS**:
- **Tambah tugas**: Ketik di kolom input → tekan `+` atau `Enter`
- **Centang tugas**: Klik checkbox saat tugas selesai
- **Hapus tugas**: Klik tombol `✕`
- Tugas disimpan otomatis ke `user://tasks.json` dan tetap ada setelah game ditutup.

---

## ⚙️ Pengaturan

Dapat diakses dari Main Menu → Pengaturan:
- **Durasi Fokus** (1–60 menit): Panjang sesi kerja sebelum masuk combat.
- **Durasi Combat** (1–15 menit): Batas waktu fase ACTION.
- **Volume**: Master, BGM, SFX (bus terpisah).

Pengaturan disimpan otomatis ke `user://settings.cfg`.

---

## 🏗️ Struktur Proyek

```
Task-and-Slash/
├── Scenes/
│   ├── MainMenu.tscn        # Layar utama + stats sesi
│   ├── Cafe.tscn            # Fase fokus, task list & ready
│   ├── World.tscn           # Fase combat / arena
│   ├── SettingsMenu.tscn    # Pengaturan
│   ├── enemy.tscn           # Musuh melee (merah)
│   ├── ranged_enemy.tscn    # Musuh jarak jauh (biru)
│   ├── fast_enemy.tscn      # Musuh cepat (oranye)
│   ├── boss_enemy.tscn      # Boss (ungu/emas) — wave 5, 10, 15...
│   ├── projectile.tscn      # Proyektil ranged & boss
│   ├── attack_flash.tscn    # Telegraph visual musuh
│   ├── damage_number.tscn   # Floating damage / teks status
│   └── death_burst.tscn     # Efek mati musuh
│
├── Scripts/
│   ├── game_manager.gd      # [Autoload] State machine, timer, slowmo, sesi
│   ├── audio_manager.gd     # [Autoload] BGM/SFX bus, play_bgm(), play_sfx()
│   ├── scene_transition.gd  # [Autoload] Fade antar scene
│   ├── player.gd            # Player: lock-on, counter dash, combo, bullet time
│   ├── enemy.gd             # AI musuh melee + interrupt_charge()
│   ├── ranged_enemy.gd      # AI musuh jarak jauh + interrupt_charge()
│   ├── boss_enemy.gd        # AI boss: random attack, shockwave unblockable
│   ├── world_manager.gd     # Wave spawning, HUD, pause, summary, highscore
│   ├── cafe_manager.gd      # Fase Cafe: timer, task list, warning animation
│   ├── main_menu.gd         # UI main menu + stats & intro animation
│   ├── settings_menu.gd     # UI pengaturan
│   ├── camera.gd            # Kamera: smooth follow, screen shake, FOV zoom
│   ├── projectile.gd        # Logika proyektil
│   ├── damage_number.gd     # Floating label (damage, COUNTER!, DODGE!, dll.)
│   ├── death_burst.gd       # VFX kematian musuh
│   └── attack_flash.gd      # VFX telegraph musuh
│
└── Assets/                  # Aset visual & audio (WIP)
```

---

## 🛠️ Tech Stack

- **Engine**: [Godot 4.5](https://godotengine.org/)
- **Bahasa**: GDScript
- **Renderer**: OpenGL Compatibility (optimal untuk hardware lama)
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

> ⚠️ **Catatan Testing**: `focus_duration` di `main_menu.gd` saat ini di-override ke **10 detik** untuk keperluan pengujian. Hapus baris tersebut sebelum build produksi.

Untuk export ke Web:
```
Project → Export → Web (HTML5) → Export Project
```

---

## 📋 Status Pengembangan

| Sistem | Status |
|---|---|
| State machine (FOCUS/READY/ACTION) | ✅ Selesai |
| Long break setelah 4 sesi | ✅ Selesai |
| Persistensi sesi & highscore | ✅ Selesai |
| Task list UI (tambah/centang/hapus) | ✅ Selesai |
| Combat dasar (attack, dash, combo) | ✅ Selesai |
| Telegraph + Counter Dash | ✅ Selesai |
| Charge interrupt on hit | ✅ Selesai |
| Bullet time (dodge near threat) | ✅ Selesai |
| Counter Dash cinematic (FOV zoom + slowmo) | ✅ Selesai |
| Parry knockback (non-boss) | ✅ Selesai |
| 3 tipe musuh biasa | ✅ Selesai |
| Boss enemy (wave 5, 10, 15...) | ✅ Selesai |
| Boss: random attack pattern | ✅ Selesai |
| Boss: Shockwave unblockable | ✅ Selesai |
| Wave progression + HP scaling | ✅ Selesai |
| Heal drop on kill (30%) | ✅ Selesai |
| HUD (HP, kills, combo, wave, score) | ✅ Selesai |
| Post-combat summary + highscore | ✅ Selesai |
| Settings menu (timer + audio) | ✅ Selesai |
| AudioManager (BGM + SFX bus) | ✅ Selesai |
| Scene fade transition | ✅ Selesai |
| Death burst VFX | ✅ Selesai |
| Hit flash + damage numbers | ✅ Selesai |
| Critical hit damage styling | ✅ Selesai |
| Soft lock-on system | ✅ Selesai |
| Pause menu (World & Cafe) | ✅ Selesai |
| Main menu intro animation | ✅ Selesai |
| Sprite / Animasi karakter | 🔲 Belum |
| BGM & SFX assets | 🔲 Belum |
| Daze/Stagger bar system | 🔲 Belum |
| Energy/SP + EX Special Attack | 🔲 Belum |
| Boss multi-phase | 🔲 Belum |

---

## 📝 Lisensi

[MIT License](LICENSE) — bebas digunakan dan dimodifikasi.
