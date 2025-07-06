# 🩺 system-health-fedora

**system-health-fedora** adalah skrip Bash sederhana untuk memantau kesehatan sistem Fedora. Output dari skrip ini dapat disimpan dalam bentuk **log**, **HTML**, maupun **PDF**, cocok digunakan untuk diagnosa cepat atau dokumentasi sistem.

---

## 📁 Struktur File

* `check.sh` — Skrip utama pengecekan sistem
* `output.log` — Log eksekusi mentah
* `output.html` — Output HTML (via `aha`)
* `check.pdf` — Laporan PDF (via `wkhtmltopdf`)

---

## ⚙️ Instalasi & Penggunaan

### 1. Berikan izin eksekusi:

```bash
chmod +x check.sh
```

### 2. Instal dependensi:

```bash
sudo dnf install -y \
  fastfetch \
  util-linux \
  sysstat \
  pciutils \
  iproute \
  procps-ng \
  coreutils \
  findutils \
  grep \
  gawk \
  sed \
  smartmontools \
  upower \
  lm_sensors \
  lsof \
  bash-completion \
  hostname \
  lshw \
  tree \
  systemd \
  initscripts \
  util-linux-script \
  aha \
  wkhtmltopdf

sudo dnf install sysstat fastfetch smartmontools upower pciutils iproute mailx lm_sensors btrfs-progs xfsprogs e2fsprogs acpi cpupower

```

### 3. Jalankan skrip:

```bash
sudo ./check.sh
```

### 4. Simpan log dan buat laporan:

```bash
sudo script -q -c "./check.sh" output.log
aha < output.log > output.html
wkhtmltopdf --enable-local-file-access output.html check.pdf
```

---

## 📜 Lisensi

Lisensi: Apache 2.0

---

## 👤 Pengembang

Project ini dikembangkan oleh [SecretDiscorder](https://github.com/SecretDiscorder).

Kontribusi dan masukan sangat diterima! 🚀
