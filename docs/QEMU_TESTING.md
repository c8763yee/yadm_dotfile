# QEMU 全矩陣整合測試規格

本文件定義 `yadm_dotfile` 的 QEMU 整合測試契約。目標不是只確認 bootstrap「跑完」，而是驗證：

1. 每個 package-manager / OS group 的套件解析與安裝行為。
2. 每個 desktop profile 的正向或負向支援契約。
3. yadm alternate 是否產生正確 target。
4. HyDE 與 yadm 的 ownership 邊界是否維持不變。
5. bootstrap 是否可重跑、重開機後仍成立，而且不留下未追蹤的部署狀態。
6. GUI profile 是否至少能進入實際 desktop session，而不只確認套件存在。

現有 `.github/workflows/hydevm-preflight.yml` 是 **Arch + Hyprland 的快速前置測試**；它不能取代本文件的完整矩陣。

---

## 1. 測試邊界

### 1.1 OS group

目前 bootstrap 的 package manager 分支可抽象成四個 group：

| Group | `/etc/os-release ID` / 環境 | Package manager | 完整 Linux desktop target |
|---|---|---|---|
| Arch | `arch` | pacman + yay | 是 |
| Debian family | `debian`, `ubuntu`, `raspbian` | apt | 是；Raspbian 另做 ARM 補充測試 |
| Fedora | `fedora` | dnf | 是 |
| MSYS2 | `msys2` | pacman | 暫不納入目前 QEMU runner |

Debian family 的主要 QEMU 代表為 Debian；Ubuntu 必須至少再跑一次相容性 case。Raspbian 與 Debian/Ubuntu 共用 package resolver 分支，因此核心矩陣以 Debian family 為一組，另以 `qemu-system-aarch64` 做可選的 Raspberry Pi OS smoke test。

### 1.2 Desktop profile

測試四個 yadm class：

- `Base`
- `Kde`
- `Niri`
- `Hyprland`

目前程式的支援契約：

- `Base`：不安裝 desktop。
- `Kde`：程式沒有 distro 限制，因此 Arch、Debian family、Fedora 都是正向測試。
- `Niri`：只支援 Arch。
- `Hyprland`：只支援 Arch；Arch case 必須走真實 HyDE install/update path。

---

## 2. 完整測試矩陣

狀態定義：

- **PASS**：必須完整成功。
- **NEGATIVE**：必須明確拒絕，而且拒絕前不得留下該 profile 的半套設定。
- **XFAIL**：目前已知實作尚未符合最終契約；仍必須執行並保存失敗結果，不可直接 skip。
- **SUPPLEMENTAL**：不是主要 group gate，但用於提高相容性信心。

| OS group | Base | Kde | Niri | Hyprland |
|---|---:|---:|---:|---:|
| Arch | PASS | PASS | PASS | PASS |
| Debian family | PASS | PASS | NEGATIVE | NEGATIVE |
| Fedora | PASS | PASS | NEGATIVE | NEGATIVE |


另外增加：

| Case | 狀態 | 目的 |
|---|---|---|
| Ubuntu + Base | SUPPLEMENTAL PASS | 驗證 `ubuntu` alias |
| Ubuntu + Kde | SUPPLEMENTAL PASS | 驗證 apt/KDE 套件名稱 |
| Raspberry Pi OS arm64 + Base | SUPPLEMENTAL / future | 只測 Base；不納入目前 x86-64 runner |

### 2.1 不支援組合的規則

「不支援」不是 skip。

例如 Debian + Hyprland 必須測到：

1. 測試程式要求 `Hyprland`。
2. bootstrap 在任何 HyDE / Hyprland-specific mutation 前拒絕。
3. 不得建立 `~/HyDE`。
4. 不得留下 Hyprland package 的部分安裝狀態作為「成功」依據。
5. yadm tracked files 必須仍保持一致。

若程式只是輸出「僅支援 Arch，跳過」然後繼續執行其他 stage，這不算 negative test 通過；應列為 XFAIL / defect，直到 top-level profile validation 完成。

---


## 2.2 現階段 QEMU runner 範圍

目前實作的 `tests/run-qemu-matrix.sh` **只執行 x86-64**：

| OS | Base | KDE | Niri | Hyprland |
|---|---:|---:|---:|---:|
| Arch | PASS | PASS | PASS | PASS |
| Debian | PASS | PASS | NEGATIVE | NEGATIVE |
| Fedora | PASS | PASS | NEGATIVE | NEGATIVE |
| Ubuntu | SUPPLEMENTAL | SUPPLEMENTAL | — | — |

Raspberry Pi OS 後續只增加 `arm64 + Base` supplemental case；MSYS2 暫不使用。

runner 的儲存位置固定為：

```text
~/yadm_dotfile/tests/
├── images/    # 保留：下載好的 base images
├── vms/       # 暫存：目前 case 的 disposable VM disk
├── seeds/     # 暫存：cloud-init seed
├── logs/      # 保留：serial logs
├── results/   # 保留：manifest / QEMU command / runner result
└── ssh/       # 保留：測試用 SSH key
```

預設直接依矩陣順序執行：

```bash
./tests/run-qemu-matrix.sh
```

也可分組或單獨執行：

```bash
./tests/run-qemu-matrix.sh --list
./tests/run-qemu-matrix.sh --group arch
./tests/run-qemu-matrix.sh --case QEMU-ARCH-HYPRLAND
./tests/run-qemu-matrix.sh --from QEMU-DEBIAN-BASE
```

每個 case 都從 immutable base image 建立 disposable VM disk：Arch / Debian / Fedora 直接複製 qcow2；Ubuntu 因 base 為 `.img`，仍建立 qcow2 overlay。完成 guest 內測試後手動：

```bash
sudo poweroff
```

QEMU process 結束後 runner 會立即刪除該 case 的 `tests/vms/<CASE>.qcow2` 與 cloud-init seed，再直接啟動下一個 case。base image、logs 與 results 會保留。Arch / Debian / Fedora 的 VM disk 是獨立 qcow2 複本；Ubuntu 則是以原始 `.img` 為 backing file 的 qcow2 overlay。

## 3. Host 需求

建議 host 為 Arch Linux、Ubuntu、Fedora 或 NixOS；測試本身不依賴 host distro。

必要條件：

```text
x86_64 virtualization: Intel VT-x / AMD-V
/dev/kvm: readable and writable by current user
QEMU: qemu-system-x86_64, qemu-img
SSH client
curl
sha256sum
cloud-localds (Debian/Ubuntu/Fedora cloud image 建議)
```

檢查：

```bash
test -r /dev/kvm && test -w /dev/kvm
qemu-system-x86_64 --version
qemu-img --version
ssh -V
```

若沒有 KVM，可用 TCG 執行 package / alternate 測試，但 GUI desktop gate 不應以 TCG 結果作正式 PASS。

---

## 4. 測試映像政策

### 4.1 原則

不要把 mutable `latest` 當成測試紀錄的一部分。

每次測試：

1. 從官方來源解析映像。
2. 下載後記錄實際 URL。
3. 記錄 SHA256。
4. 建立 immutable base image。
5. Arch / Debian / Fedora：每個 case 將 qcow2 base 複製成 `tests/vms/<CASE>.qcow2`，QEMU 直接使用該複本。
6. Ubuntu：base 為 `.img`，每個 case 建立 qcow2 overlay。
7. 測試結束刪除 disposable VM disk，不修改 base image。

建議目錄：

```text
${XDG_CACHE_HOME:-$HOME/.cache}/yadm-qemu/
├── images/
├── overlays/
├── seed/
├── logs/
└── results/
```

### 4.2 官方來源

Arch Linux：

```text
https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-basic.qcow2
```

Debian：

```text
https://cloud.debian.org/images/cloud/trixie/latest/
```

選擇 `genericcloud amd64 qcow2`，並在 run manifest 中記錄完整檔名與 checksum。

Ubuntu：

```text
https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

Fedora：

```text
https://fedoraproject.org/cloud/download/
```

選擇當前 stable Fedora Cloud Base 的 x86_64 QEMU qcow2。不要在測試程式永久寫死 Fedora release number；將解析出的 URL 與 checksum 寫入 run manifest。

MSYS2：

需要一個使用者自行提供的 Windows qcow2 / raw base image，再於 guest 安裝 MSYS2。不要把 Windows image、license key 或帳密放進 repository。

---

## 5. 共用變數

所有 case 應記錄下列變數：

```bash
export TEST_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/yadm-qemu"
export REPO_URL="https://github.com/c8763yee/yadm_dotfile.git"
export REPO_BRANCH="refactor/yadm-ownership"
export TEST_USER="tester"
export VM_CPUS=4
export VM_MEMORY=8G
export SSH_KEY="$HOME/.ssh/yadm-qemu"
```

Case ID 格式：

```text
QEMU-<OSGROUP>-<PROFILE>
```

例如：

```text
QEMU-ARCH-HYPRLAND
QEMU-DEBIAN-KDE
QEMU-FEDORA-BASE
QEMU-MSYS2-NIRI
```

---

## 6. 共用 QEMU 啟動模板

### 6.1 Headless gate

Package、alternate、ownership 與 idempotency 測試優先用 headless：

```bash
qemu-system-x86_64 \
  -machine q35,accel=kvm \
  -cpu host \
  -m "$VM_MEMORY" \
  -smp "$VM_CPUS" \
  -drive "file=$VM_DISK,format=qcow2,if=virtio" \
  -netdev "user,id=net0,hostfwd=tcp::$SSH_PORT-:22" \
  -device virtio-net-pci,netdev=net0 \
  -display none \
  -serial "file:$SERIAL_LOG"
```

### 6.2 GUI gate

KDE、Niri、Hyprland 的最終 desktop session gate：

```bash
qemu-system-x86_64 \
  -machine q35,accel=kvm \
  -cpu host \
  -m "$VM_MEMORY" \
  -smp "$VM_CPUS" \
  -drive "file=$VM_DISK,format=qcow2,if=virtio" \
  -netdev "user,id=net0,hostfwd=tcp::$SSH_PORT-:22" \
  -device virtio-net-pci,netdev=net0 \
  -device virtio-vga-gl \
  -display gtk,gl=on,grab-on-hover=on \
  -serial "file:$SERIAL_LOG"
```

若 host GTK/OpenGL 不可用，可改用 VNC：

```bash
-device virtio-vga \
-display vnc=127.0.0.1:1
```

Hyprland / Niri 的 GUI PASS 必須優先使用 KVM + VirtIO GPU；純軟體 framebuffer 只可作安裝 smoke test。

---

## 7. Cloud-init guest

Debian、Ubuntu、Fedora 建議使用 cloud-init 建立固定測試使用者。

`user-data`：

```yaml
#cloud-config
users:
  - name: tester
    groups: [sudo, wheel]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - REPLACE_WITH_TEST_PUBLIC_KEY

ssh_pwauth: false
disable_root: true
```

建立 seed：

```bash
cloud-localds seed.img user-data meta-data
```

QEMU 加入：

```bash
-drive file=seed.img,format=raw,if=virtio
```

測試不要把固定 password 寫入 repository。Arch basic image 的首次啟動若使用 `arch/arch`，該密碼只能用於開啟 SSH；進入 SSH 後立即改成測試 sudoers / SSH key 模式。

---

## 8. Arch guest baseline

Arch case 與現有 HydeVM preflight 一致：guest 初始只補齊「執行測試所需」工具，不先安裝 bootstrap 自己應負責的套件。

允許預先安裝：

```bash
sudo pacman -Sy --needed --noconfirm openssh sudo yadm git
sudo systemctl enable --now sshd
```

禁止為了讓 bootstrap 過關而預先安裝：

```text
python
zsh
tmux
desktop packages
HyDE dependencies
waybar
Hyprland
Niri
KDE
```

這條規則可抓出 bootstrap 的 hidden dependency；例如 bootstrap 若在 `10-packages` 之前依賴 Python，就應該直接 FAIL。

---

## 9. Debian / Ubuntu / Fedora guest baseline

只安裝：

### Debian / Ubuntu

```bash
sudo apt-get update
sudo apt-get install -y git yadm openssh-server sudo
sudo systemctl enable --now ssh
```

### Fedora

```bash
sudo dnf install -y git yadm openssh-server sudo
sudo systemctl enable --now sshd
```

不得預先補 desktop package。

---

## 10. 共用 guest 測試流程

每個 Linux case 都依相同順序執行。

### T00：環境紀錄

```bash
cat /etc/os-release
uname -a
uname -m
command -v yadm
yadm --version
```

輸出寫入 `results/<case>/environment.txt`。

### T10：Clone，但不直接執行 bootstrap

```bash
yadm clone "$REPO_URL" \
  -b "$REPO_BRANCH" \
  --no-bootstrap
```

原因：測試要能在每一個 stage 中間檢查 invariant，不能只看 bootstrap 最後 exit code。

### T20：Static syntax gate

```bash
sh -n ~/.config/yadm/bootstrap

bash -n \
  ~/.config/yadm/lib/env.sh \
  ~/.config/yadm/lib/packages.sh \
  ~/.config/yadm/bootstrap.d/10-packages \
  ~/.config/yadm/bootstrap.d/20-desktop \
  ~/.config/yadm/bootstrap.d/30-user \
  ~/.config/yadm/bootstrap.d/40-system
```

任何 syntax error 都直接 FAIL。

### T30：Class / alternate gate

```bash
PROFILE=Base  # per case
yadm config local.class "$PROFILE"
yadm alt
```

驗證：

#### Base / Kde / Niri

必須存在：

```bash
test -f ~/.zshenv
test -f ~/.config/zsh/.zshenv
```

#### Hyprland

在 HyDE install 之前必須不存在：

```bash
test ! -e ~/.zshenv
test ! -e ~/.config/zsh/.zshenv
```

但 yadm preserve files 必須已存在：

```bash
test -f ~/.config/zsh/.zshrc
test -f ~/.config/zsh/plugin.zsh
test -f ~/.config/zsh/.p10k.zsh
```

#### Niri

```bash
test -f ~/.config/niri/config.kdl
test -f ~/.config/waybar/config.jsonc
test -f ~/.config/waybar/style.css
```

其他 profile：

```bash
test ! -e ~/.config/niri/config.kdl
```

### T40：Package resolver contract

先單獨驗證 parser，再真的安裝。

Arch guest：

```bash
. ~/.config/yadm/lib/env.sh
. ~/.config/yadm/lib/packages.sh

DISTRO=arch
resolve_packages ~/.config/yadm/packages/base.txt
```

Debian family 需在同一測試額外跑三個 parser identity：

```bash
for id in debian ubuntu raspbian; do
  DISTRO="$id"
  echo "===== $id ====="
  resolve_packages ~/.config/yadm/packages/base.txt
done
```

至少檢查：

```text
base-devel -> build-essential on Debian/Ubuntu
fd -> fd-find on Debian/Ubuntu/Fedora
ncurses -> distro-specific development package
openssl -> distro-specific development package
libelf -> distro-specific development package
pahole -> dwarves outside Arch
cronie -> cron on Debian/Ubuntu
```

### T50：Base package stage

```bash
bash ~/.config/yadm/bootstrap.d/10-packages \
  2>&1 | tee ~/10-packages.log
```

判定：

- exit code = 0。
- 不允許因 hidden dependency 失敗。
- 對應 distro package manager database 可查到 base package 已安裝。
- Arch 的 cronie service 必須 enabled。
- Fedora kernel debuginfo 若 repository 不提供，必須在 log 中能區分「optional repository unavailable」與真正 bootstrap failure。

### T60：Desktop stage

```bash
bash ~/.config/yadm/bootstrap.d/20-desktop \
  2>&1 | tee ~/20-desktop.log
```

不同 profile 的 assertion 見第 11 節。

### T70：User stage

```bash
bash ~/.config/yadm/bootstrap.d/30-user \
  2>&1 | tee ~/30-user.log
```

至少驗證：

```bash
test -f ~/.tmux.conf
test -f ~/.tmux.conf.local
test -d ~/.tmux/plugins/tpm
test -f ~/.config/yadm/crontab
```

Zsh：

```bash
TMUX=1 SSH_TTY= zsh -lic 'echo ZSH_OK'
```

必須輸出 `ZSH_OK` 且 exit 0。

### T80：System stage

```bash
bash ~/.config/yadm/bootstrap.d/40-system \
  2>&1 | tee ~/40-system.log
```

驗證：

```bash
systemctl --user daemon-reload
systemctl --user is-enabled power-monitor.service
test -x ~/.local/bin/power-monitor-read
test -x ~/.local/bin/power-monitor-daemon
```

任何 root binary 安裝位置與 service dependency 都要記錄。

### T90：Repository cleanliness

```bash
yadm status --short | tee ~/yadm-status.txt
```

允許的差異必須有明確理由。以下視為 FAIL：

- bootstrap 修改 yadm tracked config。
- HyDE 更新覆寫 yadm preserve files。
- 產生舊 `Config -> ~/.config` deployment symlink。
- tracked file 因 parser / formatter 被重寫。

### T100：Idempotency

第一次成功後：

```bash
find ~/.config/zsh ~/.config/waybar ~/.config/yadm \
  -type f -print0 | sort -z | xargs -0 sha256sum \
  > ~/before-second-run.sha256

YADM_CLASS="$PROFILE" yadm bootstrap \
  2>&1 | tee ~/bootstrap-second.log

find ~/.config/zsh ~/.config/waybar ~/.config/yadm \
  -type f -print0 | sort -z | xargs -0 sha256sum \
  > ~/after-second-run.sha256
```

再檢查：

```bash
yadm status --short
```

第二次執行不得因：

- `/tmp/yay` 已存在；
- service 已 enabled；
- HyDE 已 clone；
- TPM 已 clone；
- crontab managed block 已存在；

而失敗。

有意義的 runtime-generated file 可以變更，但必須排除在 immutable hash set 之外並在測試文件中列明。

### T110：Reboot persistence

```bash
sudo reboot
```

重新 SSH 後：

```bash
yadm config local.class
yadm status --short
TMUX=1 SSH_TTY= zsh -lic 'echo ZSH_AFTER_REBOOT_OK'
```

desktop profile 再執行 GUI gate。

---

## 11. Profile-specific assertions

### 11.1 Base

Base 不應安裝任何 desktop-specific stack。

必須：

```bash
test "$(yadm config local.class)" = Base
test -f ~/.zshenv
test -f ~/.config/zsh/.zshenv
test ! -e ~/.config/niri/config.kdl
test ! -d ~/HyDE
```

KDE / Niri / Hyprland package 是否已由 base image 預裝不能只靠 `command -v` 判斷；應以 bootstrap log 與 package transaction 判斷本次測試是否主動安裝。

### 11.2 KDE

Arch、Debian family、Fedora 都是正向 gate。

必須：

```bash
command -v plasmashell
systemctl is-enabled sddm
```

Plasmoid：

```bash
kpackagetool6 --type Plasma/Applet --show com.github.c8763yee.grubreboot
kpackagetool6 --type Plasma/Applet --show com.github.c8763yee.powermonitor
```

GUI login 後：

```bash
pgrep -x plasmashell
loginctl list-sessions
```

若 Debian/Fedora 套件名稱映射不足，這是 test failure，不是「該 distro 不支援」，因為目前程式沒有 KDE distro guard。

### 11.3 Niri

只有 Arch 為正向 gate。

安裝後：

```bash
command -v niri
test -f ~/.config/niri/config.kdl
test -f ~/.config/waybar/config.jsonc
test -f ~/.config/waybar/style.css
```

GUI session：

```bash
pgrep -x niri
pgrep -x waybar
journalctl --user -b --no-pager | tail -200
```

Debian/Fedora/MSYS2 case 必須跑 negative contract。

### 11.4 Hyprland / HyDE

只有 Arch 為正向 gate。

#### 安裝前

```bash
test ! -e ~/.zshenv
test ! -e ~/.config/zsh/.zshenv

plugin_before=$(sha256sum ~/.config/zsh/plugin.zsh | awk '{print $1}')
zshrc_before=$(sha256sum ~/.config/zsh/.zshrc | awk '{print $1}')
```

#### HyDE 安裝後

HyDE `sync` target 必須由 HyDE 產生：

```bash
cmp ~/.zshenv ~/HyDE/Configs/.zshenv
cmp ~/.config/zsh/.zshenv ~/HyDE/Configs/.config/zsh/.zshenv
```

yadm `preserve` files 必須 byte-for-byte 不變：

```bash
test "$plugin_before" = "$(sha256sum ~/.config/zsh/plugin.zsh | awk '{print $1}')"
test "$zshrc_before" = "$(sha256sum ~/.config/zsh/.zshrc | awk '{print $1}')"
```

Waybar user extension：

```bash
test -f ~/.config/waybar/modules/custom-powerdraw.jsonc
```

ownership gate：

```bash
test ! -L ~/.config/zsh
test ! -L ~/.config/waybar
```

若測試 branch 已完成 user-owned layout 改造，還必須驗證 bootstrap 不直接修改：

```text
~/.local/share/waybar/layouts/**
```

可在 desktop stage 前後對該目錄做 hash manifest。

Zsh：

```bash
TMUX=1 SSH_TTY= zsh -lic \
  'whence -w _gocker >/dev/null && echo ZSH_OK'
```

GUI session：

```bash
pgrep -x Hyprland
pgrep -x waybar
journalctl --user -b --no-pager | tail -300
```

---

## 12. Negative contract

### 12.1 Debian/Fedora + Niri/Hyprland

目標狀態應是「在 desktop mutation 前拒絕」。

測試紀錄至少保存：

```bash
yadm status --short
test ! -d ~/HyDE
find ~/.config -maxdepth 3 -type l -ls
```

目前若 bootstrap 僅印出「僅支援 Arch，跳過」後繼續 `30-user` / `40-system`，標記為 **XFAIL**，直到 profile validation 移到 bootstrap 最前面。

### 12.2 MSYS2

MSYS2 是 package-manager group，不是 systemd Linux target。

正向部分：

- `pkg_update`
- `pkg_install`
- `resolve_packages`
- tracked dotfile checkout
- alternate selection（不包含 Linux-only service assertions）

完整 bootstrap 目前應標為 XFAIL，因為：

- `systemctl`
- `chsh`
- Linux user systemd units
- desktop compositor
- `/etc/os-release` / Linux path assumptions

都不是 MSYS2 的完整系統契約。

Kde / Niri / Hyprland case 必須驗證將來的 top-level guard 能在 mutation 前拒絕。

---

## 13. GUI gate

Package install 成功不等於 desktop 成功。

每個支援 desktop 至少完成一次：

1. 以 GUI QEMU mode 重開 VM。
2. 在 display manager 登入 `tester`。
3. 確認 session process 存活 60 秒以上。
4. 由 SSH 收集：
   - `loginctl session-status`
   - compositor / shell process
   - `journalctl -b`
   - `journalctl --user -b`
5. Waybar profile 要確認 Waybar 存活。
6. 登出再登入一次，確認不是 only-first-login 成功。

Hyprland / Niri 若因 QEMU GPU 限制不能啟動，不得把 package-only 結果標成完整 PASS；應區分：

```text
INSTALL_PASS
GUI_ENV_BLOCKED
```

---

## 14. 測試產物

每個 case 都建立：

```text
results/QEMU-ARCH-HYPRLAND/
├── manifest.txt
├── environment.txt
├── qemu-command.txt
├── serial.log
├── 10-packages.log
├── 20-desktop.log
├── 30-user.log
├── 40-system.log
├── bootstrap-second.log
├── yadm-status.txt
├── packages.txt
├── journal-system.txt
├── journal-user.txt
└── result.txt
```

`manifest.txt`：

```text
CASE=
DATE=
HOST_KERNEL=
QEMU_VERSION=
KVM=
IMAGE_URL=
IMAGE_SHA256=
REPO_BRANCH=
REPO_COMMIT=
PROFILE=
RESULT=
```

`result.txt` 只能使用：

```text
PASS
FAIL
XFAIL
NEGATIVE_PASS
ENV_BLOCKED
```

不要使用沒有理由的 `SKIP`。

---

## 15. 建議執行順序

先跑便宜、容易定位問題的 case：

```text
1. Arch + Base
2. Arch + Niri
3. Arch + Kde
4. Arch + Hyprland
5. Debian + Base
6. Debian + Kde
7. Debian + Niri      (negative)
8. Debian + Hyprland  (negative)
9. Fedora + Base
10. Fedora + Kde
11. Fedora + Niri      (negative)
12. Fedora + Hyprland  (negative)
13. Ubuntu + Base      (supplemental)
14. Ubuntu + Kde       (supplemental)
15. Raspberry Pi OS arm64 + Base (future supplemental；不由目前 runner 執行)
```

Hyprland 放在 Arch 最後，因為 HyDE install 成本最高，而且它同時涵蓋最多 ownership assertions。

---

## 16. 與 HydeVM 的關係

HydeVM 仍可作為 Arch + Hyprland 的專用測試工具：

```text
HydeVM:
  快速驗證 HyDE upstream + yadm ownership
  只覆蓋 Arch/Hyprland

本文件的 QEMU matrix:
  驗證全部 OS group
  驗證 Base/KDE/Niri/Hyprland
  包含 negative contract
  包含 idempotency/reboot/GUI gate
```

現有 `.github/workflows/hydevm-preflight.yml` 應維持為快速 gate；完整矩陣若放進 CI，建議拆成 nightly/manual workflow，避免每次 push 都重新安裝四個 OS group 的 desktop 環境。

---

## 17. PR / merge gate

`refactor/yadm-ownership` 合併前最低標準：

- Arch + Base：PASS
- Arch + Kde：PASS
- Arch + Niri：PASS
- Arch + Hyprland：PASS
- Debian + Base：PASS
- Debian + Kde：PASS
- Fedora + Base：PASS
- Fedora + Kde：PASS
- 非 Arch Niri/Hyprland：至少已有可重現的 XFAIL，且不得被誤報為 PASS
- 第二次 bootstrap：所有正向 case PASS
- reboot persistence：所有正向 case PASS
- `yadm status --short`：沒有 bootstrap 導致的 tracked-file mutation
- HyDE sync/preserve ownership：PASS

MSYS2 full-bootstrap 與 Raspberry Pi OS GUI 不阻塞目前 Linux desktop refactor merge，但測試結果必須保留，不能從矩陣刪除。

---

## 18. 失敗分類

遇到失敗時，先分類，不要直接在測試腳本加 workaround。

```text
BOOTSTRAP_SYNTAX
HIDDEN_DEPENDENCY
PACKAGE_MAPPING
PROFILE_GUARD
YADM_ALTERNATE
HYDE_OWNERSHIP
WAYBAR_OWNERSHIP
ZSH_INIT
SERVICE
IDEMPOTENCY
REBOOT_PERSISTENCE
GUI_QEMU
UPSTREAM_IMAGE
HOST_ENVIRONMENT
```

只有 `GUI_QEMU`、`UPSTREAM_IMAGE`、`HOST_ENVIRONMENT` 可以在證據充足時標成 `ENV_BLOCKED`。其他分類都是 repository regression 或支援契約問題。

---

## 19. 參考

- HyDE HydeVM:
  https://github.com/HyDE-Project/HyDE/tree/master/Scripts/hydevm
- Arch Linux VM images:
  https://geo.mirror.pkgbuild.com/images/latest/
- Debian cloud images:
  https://cloud.debian.org/images/cloud/
- Ubuntu cloud images:
  https://cloud-images.ubuntu.com/
- Fedora Cloud:
  https://fedoraproject.org/cloud/download/
