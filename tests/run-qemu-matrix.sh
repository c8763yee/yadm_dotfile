#!/usr/bin/env bash
set -Eeuo pipefail

TEST_ROOT="${YADM_QEMU_TEST_ROOT:-$HOME/yadm_dotfile/tests}"
IMAGES_DIR="$TEST_ROOT/images"
VMS_DIR="$TEST_ROOT/vms"
SEEDS_DIR="$TEST_ROOT/seeds"
LOGS_DIR="$TEST_ROOT/logs"
RESULTS_DIR="$TEST_ROOT/results"
SSH_DIR="$TEST_ROOT/ssh"

VM_MEMORY="${VM_MEMORY:-8G}"
VM_CPUS="${VM_CPUS:-4}"
SSH_PORT="${SSH_PORT:-2222}"
QEMU_DISPLAY="${QEMU_DISPLAY:-gtk}"
QEMU_VNC_DISPLAY="${QEMU_VNC_DISPLAY:-1}"
AUTO_DOWNLOAD="${AUTO_DOWNLOAD:-1}"
FEDORA_RELEASE="${FEDORA_RELEASE:-44}"

REPO_URL="${REPO_URL:-https://github.com/c8763yee/yadm_dotfile.git}"
REPO_BRANCH="${REPO_BRANCH:-refactor/yadm-ownership}"
TEST_USER="${TEST_USER:-tester}"

MATRIX=(
  "QEMU-ARCH-BASE|arch|Base|PASS"
  "QEMU-ARCH-NIRI|arch|Niri|PASS"
  "QEMU-ARCH-KDE|arch|Kde|PASS"
  "QEMU-ARCH-HYPRLAND|arch|Hyprland|PASS"
  "QEMU-DEBIAN-BASE|debian|Base|PASS"
  "QEMU-DEBIAN-KDE|debian|Kde|PASS"
  "QEMU-DEBIAN-NIRI|debian|Niri|NEGATIVE"
  "QEMU-DEBIAN-HYPRLAND|debian|Hyprland|NEGATIVE"
  "QEMU-FEDORA-BASE|fedora|Base|PASS"
  "QEMU-FEDORA-KDE|fedora|Kde|PASS"
  "QEMU-FEDORA-NIRI|fedora|Niri|NEGATIVE"
  "QEMU-FEDORA-HYPRLAND|fedora|Hyprland|NEGATIVE"
  "QEMU-UBUNTU-BASE|ubuntu|Base|SUPPLEMENTAL"
  "QEMU-UBUNTU-KDE|ubuntu|Kde|SUPPLEMENTAL"
)

SELECT_CASE=""
SELECT_GROUP=""
START_FROM=""
CURRENT_VM=""
CURRENT_SEED=""

mkdir -p "$IMAGES_DIR" "$VMS_DIR" "$SEEDS_DIR" "$LOGS_DIR" "$RESULTS_DIR" "$SSH_DIR"

cleanup_current() {
  if [[ -n "$CURRENT_VM" ]]; then
    rm -f -- "$CURRENT_VM"
  fi
  if [[ -n "$CURRENT_SEED" ]]; then
    rm -f -- "$CURRENT_SEED"
  fi
  CURRENT_VM=""
  CURRENT_SEED=""
}

on_interrupt() {
  echo
  echo "Interrupted: deleting the current disposable VM."
  cleanup_current
  exit 130
}

trap cleanup_current EXIT
trap on_interrupt INT TERM

usage() {
  cat <<'EOF'
Usage:
  tests/run-qemu-matrix.sh
  tests/run-qemu-matrix.sh --list
  tests/run-qemu-matrix.sh --group arch
  tests/run-qemu-matrix.sh --case QEMU-ARCH-HYPRLAND
  tests/run-qemu-matrix.sh --from QEMU-DEBIAN-BASE

Options:
  --list             Print the x86-64 matrix and exit.
  --group OS         Run one group: arch, debian, fedora, ubuntu.
  --case ID          Run only one case.
  --from ID          Start at ID and continue to the end.
  --display MODE     gtk (default), vnc, or headless.
  --no-download      Do not download missing base images.
  -h, --help         Show this help.

Storage:
  ~/yadm_dotfile/tests/images/   Persistent base images.
  ~/yadm_dotfile/tests/vms/      Disposable per-case qcow2 overlays.
  ~/yadm_dotfile/tests/seeds/    Disposable cloud-init seeds.
  ~/yadm_dotfile/tests/logs/     QEMU serial logs.
  ~/yadm_dotfile/tests/results/  Per-case manifests.

After you finish a case, power off the guest normally. When QEMU exits,
the case overlay is deleted immediately and the next selected case starts.

Environment overrides:
  VM_MEMORY=8G
  VM_CPUS=4
  SSH_PORT=2222
  QEMU_DISPLAY=gtk|vnc|headless
  QEMU_EXTRA_ARGS='...'
  FEDORA_RELEASE=44
  ARCH_BASE_IMAGE=/path/to/image.qcow2
  DEBIAN_BASE_IMAGE=/path/to/image.qcow2
  FEDORA_BASE_IMAGE=/path/to/image.qcow2
  UBUNTU_BASE_IMAGE=/path/to/image.img
EOF
}

list_matrix() {
  printf '%-26s %-9s %-10s %s
' CASE OS PROFILE CONTRACT
  printf '%-26s %-9s %-10s %s
' ---- -- ------- --------
  local row id os profile contract
  for row in "${MATRIX[@]}"; do
    IFS='|' read -r id os profile contract <<<"$row"
    printf '%-26s %-9s %-10s %s
' "$id" "$os" "$profile" "$contract"
  done
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing host command: $1" >&2
    return 1
  }
}

preflight() {
  require_cmd qemu-system-x86_64
  require_cmd qemu-img
  require_cmd curl
  require_cmd sha256sum
  require_cmd awk
  require_cmd sed

  if [[ ! -r /dev/kvm || ! -w /dev/kvm ]]; then
    echo "WARNING: /dev/kvm is unavailable; QEMU will use TCG."
    echo "Desktop GUI results from TCG must not be treated as a formal PASS."
  fi
}

ensure_ssh_key() {
  local key="$SSH_DIR/id_ed25519"
  if [[ ! -f "$key" ]]; then
    require_cmd ssh-keygen
    ssh-keygen -q -t ed25519 -N "" -f "$key"
  fi
  printf '%s
' "$key"
}

download_to() {
  local url="$1"
  local target="$2"

  if [[ -f "$target" ]]; then
    [[ -f "$target.sha256" ]] || sha256sum "$target" >"$target.sha256"
    return 0
  fi

  if [[ "$AUTO_DOWNLOAD" != "1" ]]; then
    echo "Missing base image and downloads are disabled: $target" >&2
    return 1
  fi

  echo "Downloading base image:" >&2
  echo "  $url" >&2
  echo "  -> $target" >&2
  local partial="$target.part"
  curl -fL --retry 3 --continue-at - "$url" -o "$partial"
  mv -f -- "$partial" "$target"
  sha256sum "$target" >"$target.sha256"
}

resolve_debian_url() {
  local root="https://cloud.debian.org/images/cloud/trixie/latest/"
  local file

  file=$(curl -fsSL "$root" |
    sed -n 's/.*href="\([^"]*genericcloud-amd64[^"]*\.qcow2\)".*/\1/p' |
    sort -V |
    tail -n1)

  [[ -n "$file" ]] || return 1
  printf '%s%s
' "$root" "$file"
}

resolve_fedora_url() {
  local root="https://download.fedoraproject.org/pub/fedora/linux/releases/$FEDORA_RELEASE/Cloud/x86_64/images/"
  local file

  file=$(curl -fsSL "$root" |
    sed -n 's/.*href="\([^"]*Cloud-Base-Generic[^"]*x86_64\.qcow2\)".*/\1/p' |
    sort -V |
    tail -n1)

  [[ -n "$file" ]] || return 1
  printf '%s%s
' "$root" "$file"
}

base_image_for() {
  local os="$1"
  local override=""
  local target=""
  local url=""

  case "$os" in
    arch)
      override="${ARCH_BASE_IMAGE:-}"
      target="$IMAGES_DIR/arch-base.qcow2"
      url="https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-basic.qcow2"
      ;;
    debian)
      override="${DEBIAN_BASE_IMAGE:-}"
      target="$IMAGES_DIR/debian-trixie-genericcloud-amd64.qcow2"
      url=$(resolve_debian_url)
      ;;
    fedora)
      override="${FEDORA_BASE_IMAGE:-}"
      target="$IMAGES_DIR/fedora-$FEDORA_RELEASE-cloud-base-x86_64.qcow2"
      url=$(resolve_fedora_url)
      ;;
    ubuntu)
      override="${UBUNTU_BASE_IMAGE:-}"
      target="$IMAGES_DIR/ubuntu-noble-cloudimg-amd64.img"
      url="https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-amd64.img"
      ;;
    *)
      echo "Unsupported runner OS: $os" >&2
      return 1
      ;;
  esac

  if [[ -n "$override" ]]; then
    [[ -f "$override" ]] || {
      echo "Base image override does not exist: $override" >&2
      return 1
    }
    printf '%s
' "$override"
    return 0
  fi

  download_to "$url" "$target"
  printf '%s
' "$target"
}

image_format() {
  qemu-img info "$1" | awk -F': ' '/^file format:/ { print $2; exit }'
}

create_overlay() {
  local base="$1"
  local overlay="$2"
  local format

  format=$(image_format "$base")
  [[ -n "$format" ]] || {
    echo "Unable to determine base image format: $base" >&2
    return 1
  }

  rm -f -- "$overlay"
  qemu-img create -q -f qcow2 -F "$format" -b "$base" "$overlay"
}

create_cloud_seed() {
  local id="$1"
  local os="$2"
  local profile="$3"
  local contract="$4"
  local seed="$SEEDS_DIR/$id.img"
  local work="$SEEDS_DIR/$id.d"
  local key pub groups service

  require_cmd cloud-localds
  key=$(ensure_ssh_key)
  pub=$(cat "$key.pub")

  case "$os" in
    fedora)
      groups="wheel"
      service="sshd"
      ;;
    debian|ubuntu)
      groups="sudo"
      service="ssh"
      ;;
    *)
      return 1
      ;;
  esac

  rm -rf -- "$work" "$seed"
  mkdir -p "$work"

  cat >"$work/user-data" <<EOF
#cloud-config
users:
  - name: $TEST_USER
    groups: [$groups]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - $pub

ssh_pwauth: false
disable_root: true
package_update: true
packages:
  - git
  - yadm
  - openssh-server
  - sudo

write_files:
  - path: /etc/yadm-qemu-case
    permissions: '0644'
    content: |
      CASE=$id
      OS=$os
      PROFILE=$profile
      CONTRACT=$contract
      REPO_URL=$REPO_URL
      REPO_BRANCH=$REPO_BRANCH

runcmd:
  - [ systemctl, enable, --now, $service ]
EOF

  cat >"$work/meta-data" <<EOF
instance-id: $id
local-hostname: ${id,,}
EOF

  cloud-localds "$seed" "$work/user-data" "$work/meta-data"
  rm -rf -- "$work"
  printf '%s
' "$seed"
}

display_args() {
  local profile="$1"

  case "$QEMU_DISPLAY" in
    gtk)
      if [[ "$profile" == "Base" ]]; then
        printf '%s
' "-device" "virtio-vga" "-display" "gtk"
      else
        printf '%s
' "-device" "virtio-vga-gl" "-display" "gtk,gl=on,grab-on-hover=on"
      fi
      ;;
    vnc)
      printf '%s
' "-device" "virtio-vga" "-display" "vnc=127.0.0.1:$QEMU_VNC_DISPLAY"
      ;;
    headless)
      printf '%s
' "-display" "none" "-vga" "none"
      ;;
    *)
      echo "Unknown display mode: $QEMU_DISPLAY" >&2
      return 1
      ;;
  esac
}

print_guest_steps() {
  local id="$1"
  local os="$2"
  local profile="$3"
  local contract="$4"

  cat <<EOF

Guest test target:
  CASE=$id
  PROFILE=$profile
  CONTRACT=$contract

After the guest has networking and yadm/git installed:

  yadm clone "$REPO_URL" -b "$REPO_BRANCH" --no-bootstrap
  yadm config local.class "$profile"
  yadm alt

  sh -n ~/.config/yadm/bootstrap
  bash -n ~/.config/yadm/lib/env.sh \
    ~/.config/yadm/lib/packages.sh \
    ~/.config/yadm/bootstrap.d/10-packages \
    ~/.config/yadm/bootstrap.d/20-desktop \
    ~/.config/yadm/bootstrap.d/30-user \
    ~/.config/yadm/bootstrap.d/40-system

Follow docs/QEMU_TESTING.md for the assertions for this case.
EOF

  if [[ "$os" == "arch" ]]; then
    cat <<'EOF'

Arch basic-image initial login:
  arch / arch

One-time baseline inside this disposable VM:
  sudo pacman -Sy --needed --noconfirm openssh sudo yadm git
  sudo systemctl enable --now sshd
EOF
  else
    local key="$SSH_DIR/id_ed25519"
    cat <<EOF

cloud-init creates:
  user: $TEST_USER
  sudo: passwordless
  metadata: /etc/yadm-qemu-case

From another host terminal:
  ssh -i "$key" -p "$SSH_PORT" -o StrictHostKeyChecking=no \
    "$TEST_USER@127.0.0.1"
EOF
  fi

  cat <<'EOF'

When this case is finished:
  sudo poweroff

The runner waits for QEMU to exit, deletes the disposable qcow2,
then immediately starts the next selected case.
EOF
}

write_manifest() {
  local result_dir="$1"
  local id="$2"
  local os="$3"
  local profile="$4"
  local contract="$5"
  local base="$6"
  local overlay="$7"

  mkdir -p "$result_dir"
  {
    echo "CASE=$id"
    echo "DATE=$(date --iso-8601=seconds)"
    echo "HOST_KERNEL=$(uname -srmo)"
    echo "QEMU_VERSION=$(qemu-system-x86_64 --version | head -n1)"
    echo "KVM=$([[ -r /dev/kvm && -w /dev/kvm ]] && echo yes || echo no)"
    echo "BASE_IMAGE=$base"
    echo "BASE_SHA256=$(sha256sum "$base" | awk '{print $1}')"
    echo "VM_OVERLAY=$overlay"
    echo "REPO_URL=$REPO_URL"
    echo "REPO_BRANCH=$REPO_BRANCH"
    echo "PROFILE=$profile"
    echo "OS=$os"
    echo "CONTRACT=$contract"
  } >"$result_dir/manifest.txt"
}

launch_case() {
  local id="$1"
  local os="$2"
  local profile="$3"
  local contract="$4"
  local base="$5"
  local overlay="$6"
  local seed="$7"
  local result_dir="$8"
  local serial="$LOGS_DIR/$id.serial.log"
  local -a args display extra

  if [[ -r /dev/kvm && -w /dev/kvm ]]; then
    args=(-machine q35,accel=kvm -cpu host)
  else
    args=(-machine q35,accel=tcg -cpu max)
  fi

  args+=(
    -name "$id"
    -m "$VM_MEMORY"
    -smp "$VM_CPUS"
    -drive "file=$overlay,format=qcow2,if=virtio"
    -netdev "user,id=net0,hostfwd=tcp::$SSH_PORT-:22"
    -device "virtio-net-pci,netdev=net0"
    -serial "file:$serial"
  )

  if [[ -n "$seed" ]]; then
    args+=(-drive "file=$seed,format=raw,if=virtio,readonly=on")
  fi

  mapfile -t display < <(display_args "$profile")
  args+=("${display[@]}")

  if [[ -n "${QEMU_EXTRA_ARGS:-}" ]]; then
    read -r -a extra <<<"$QEMU_EXTRA_ARGS"
    args+=("${extra[@]}")
  fi

  printf '%q ' qemu-system-x86_64 "${args[@]}" >"$result_dir/qemu-command.txt"
  printf '
' >>"$result_dir/qemu-command.txt"

  print_guest_steps "$id" "$os" "$profile" "$contract"

  qemu-system-x86_64 "${args[@]}"
}

run_case() {
  local row="$1"
  local id os profile contract
  local result_dir base overlay seed="" status=0

  IFS='|' read -r id os profile contract <<<"$row"
  result_dir="$RESULTS_DIR/$id"
  overlay="$VMS_DIR/$id.qcow2"

  echo
  echo "================================================================"
  echo "Starting $id"
  echo "OS=$os  PROFILE=$profile  CONTRACT=$contract"
  echo "================================================================"

  base=$(base_image_for "$os") || {
    echo "Unable to prepare base image for $id" >&2
    return 1
  }

  create_overlay "$base" "$overlay"
  CURRENT_VM="$overlay"

  if [[ "$os" != "arch" ]]; then
    seed=$(create_cloud_seed "$id" "$os" "$profile" "$contract")
    CURRENT_SEED="$seed"
  fi

  write_manifest "$result_dir" "$id" "$os" "$profile" "$contract" "$base" "$overlay"

  set +e
  launch_case "$id" "$os" "$profile" "$contract" "$base" "$overlay" "$seed" "$result_dir"
  status=$?
  set -e

  echo
  echo "QEMU exited for $id with status $status"
  echo "Deleting disposable VM: $overlay"
  cleanup_current
  rm -f -- "$seed"

  {
    echo "QEMU_EXIT_STATUS=$status"
    echo "FINISHED_AT=$(date --iso-8601=seconds)"
    echo "VM_DELETED=yes"
  } >"$result_dir/runner-result.txt"

  echo "Finished $id; moving to the next selected case."
  return 0
}

row_matches_selection() {
  local row="$1"
  local id os profile contract

  IFS='|' read -r id os profile contract <<<"$row"

  if [[ -n "$SELECT_CASE" && "$id" != "$SELECT_CASE" ]]; then
    return 1
  fi
  if [[ -n "$SELECT_GROUP" && "$os" != "$SELECT_GROUP" ]]; then
    return 1
  fi
  return 0
}

parse_args() {
  while (($#)); do
    case "$1" in
      --list)
        list_matrix
        exit 0
        ;;
      --case)
        SELECT_CASE="$2"
        shift 2
        ;;
      --group)
        SELECT_GROUP="$2"
        shift 2
        ;;
      --from)
        START_FROM="$2"
        shift 2
        ;;
      --display)
        QEMU_DISPLAY="$2"
        shift 2
        ;;
      --no-download)
        AUTO_DOWNLOAD=0
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage >&2
        exit 2
        ;;
    esac
  done
}

main() {
  parse_args "$@"
  preflight

  case "$SELECT_GROUP" in
    ""|arch|debian|fedora|ubuntu) ;;
    *)
      echo "Unknown group: $SELECT_GROUP" >&2
      exit 2
      ;;
  esac

  local started=0 matched=0
  local row id os profile contract

  for row in "${MATRIX[@]}"; do
    IFS='|' read -r id os profile contract <<<"$row"

    if [[ -n "$START_FROM" && "$started" == 0 ]]; then
      if [[ "$id" == "$START_FROM" ]]; then
        started=1
      else
        continue
      fi
    else
      started=1
    fi

    if ! row_matches_selection "$row"; then
      continue
    fi

    matched=1
    run_case "$row"
  done

  if [[ "$matched" == 0 ]]; then
    echo "No matrix case matched the selection." >&2
    exit 2
  fi

  echo
  echo "All selected x86-64 cases finished."
}

main "$@"
