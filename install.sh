#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
mode=${1:-}
if [[ -n $mode && $mode != --skip-system ]]; then echo 'Usage: ./install.sh [--skip-system]' >&2; exit 2; fi
if [[ ${EUID} == 0 ]]; then echo 'Run as your normal user, not root.' >&2; exit 1; fi
if [[ $(uname -m) != x86_64 ]]; then echo 'The pinned shell-tool releases currently support x86-64 Linux only.' >&2; exit 1; fi
if [[ $mode != --skip-system ]]; then
  command -v emerge >/dev/null || { echo 'This installer targets Gentoo. emerge was not found.' >&2; exit 1; }
  command -v sudo >/dev/null || { echo 'Install sudo and configure access first.' >&2; exit 1; }
  sudo emerge --needed app-eselect/eselect-repository
  if ! eselect repository list -i | grep -Eq '(^|[[:space:]])guru([[:space:]]|$)'; then
    sudo eselect repository enable guru
    sudo emaint sync -r guru
  fi
  keyword='gui-apps/quickshell ~amd64'
  if [[ -d /etc/portage/package.accept_keywords ]]; then
    keyword_file=/etc/portage/package.accept_keywords/dotfiles-quickshell
    if ! sudo grep -Fqx "$keyword" "$keyword_file" 2>/dev/null; then printf '%s\n' "$keyword" | sudo tee -a "$keyword_file" >/dev/null; fi
  elif ! sudo grep -Fqx "$keyword" /etc/portage/package.accept_keywords 2>/dev/null; then
    printf '%s\n' "$keyword" | sudo tee -a /etc/portage/package.accept_keywords >/dev/null
  fi
  sudo emerge --needed x11-base/xorg-server x11-drivers/xf86-input-libinput x11-apps/xinit x11-apps/xauth x11-apps/xrandr x11-apps/xsetroot x11-apps/xrdb x11-libs/libX11 x11-libs/libXft x11-libs/libXinerama x11-libs/libXtst x11-libs/libXi x11-libs/libXmu media-libs/libpng media-libs/fontconfig media-fonts/jetbrains-mono dev-python/pygobject dev-python/pillow x11-libs/gtk+ app-misc/tmux x11-misc/xclip x11-misc/pcmanfm app-misc/fastfetch sys-process/btop gui-apps/quickshell media-video/pipewire net-misc/networkmanager net-wireless/bluez app-shells/bash-completion app-editors/vis net-misc/curl app-arch/unzip
fi
for program in cc make pkg-config curl tar sha256sum tic fc-cache python3 tmux fastfetch btop qs; do
  command -v "$program" >/dev/null || { echo "Missing dependency: $program" >&2; exit 1; }
done
work=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install.XXXXXX")
trap 'rm -rf "$work"' EXIT
cp -a "$root/src" "$work/src"
make -C "$work/src/dwm" clean all
make -C "$work/src/st" clean all CFLAGS='-O2 -pipe'
make -C "$work/src/desktop-tools" clean all
fetch() {
  local name=$1 hash=$2 url=$3
  curl -fL --retry 2 -o "$work/$name.tar.gz" "$url"
  printf '%s  %s\n' "$hash" "$work/$name.tar.gz" | sha256sum -c -
  mkdir -p "$work/$name"
  tar -xzf "$work/$name.tar.gz" -C "$work/$name"
}
fetch fzf d47d7f882972c7d674dbbba998ffa4116e68379616ffac7695d0671e9a722c5f https://github.com/junegunn/fzf/releases/download/v0.74.5/fzf-0.74.5-linux_amd64.tar.gz
fetch zoxide 2d93385b99f3e82cf2701609a1bffcad863fbeb75aa3fe7eb6be4d29be68b1ae https://github.com/ajeetdsouza/zoxide/releases/download/v0.10.0/zoxide-0.10.0-x86_64-unknown-linux-musl.tar.gz
fetch eza e06eebab74b73d6b7d51a796a353824b001bea82df077706382e100815d28904 https://github.com/eza-community/eza/releases/download/v0.23.5/eza_x86_64-unknown-linux-musl.tar.gz
fetch bat 0dcd8ac79732c0d5b136f11f4ee00e581440e16a44eab5b3105b611bbf2cf191 https://github.com/sharkdp/bat/releases/download/v0.26.1/bat-v0.26.1-x86_64-unknown-linux-musl.tar.gz
curl -fL --retry 2 -o "$work/bluetui" https://github.com/pythops/bluetui/releases/download/v0.8.2/bluetui-x86_64-linux-musl
printf '%s  %s\n' b476ee473cb4f7a48cd75d440e991bedc835ff5ac704aac1f1992f8e826222fd "$work/bluetui" | sha256sum -c -
chmod 755 "$work/bluetui"
fetch wifitui 4c82bb3d68388507bc414f0d4fc5833066115e00cbb6d2683eac827602535cf2 https://github.com/shazow/wifitui/releases/download/v0.13.0/wifitui-0.13.0-linux-x86_64.tar.gz
backup="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/install-$(date +%Y%m%d-%H%M%S)-$$"
install_file() {
  local src=$1 dst=$2 old
  if [[ -e $dst || -L $dst ]]; then
    if [[ -f $dst && ! -L $dst ]] && cmp -s "$src" "$dst"; then return; fi
    old="$backup/${dst#"$HOME"/}"
    mkdir -p "$(dirname "$old")"
    cp -a -- "$dst" "$old"
  fi
  mkdir -p "$(dirname "$dst")"
  install -m "$(stat -c '%a' "$src")" "$src" "$dst"
}
while IFS= read -r -d '' src; do rel=${src#"$root/config/"}; install_file "$src" "$HOME/.config/$rel"; done < <(find "$root/config" -type f -print0)
install_file "$root/shell/bashrc" "$HOME/.bashrc"
install_file "$root/shell/bash_profile" "$HOME/.bash_profile"
install_file "$root/shell/bash_logout" "$HOME/.bash_logout"
for src in "$root"/bin/*; do [[ -f $src ]] || continue; install_file "$src" "$HOME/.local/bin/${src##*/}"; done
for name in dwm st; do install_file "$work/src/$name/$name" "$HOME/.local/bin/$name"; done
for name in t480-screenshot t480-keys t480-touchpad; do install_file "$work/src/desktop-tools/$name" "$HOME/.local/bin/$name"; done
for name in fzf zoxide eza; do install_file "$work/$name/$name" "$HOME/.local/bin/$name"; done
install_file "$work/bat/bat-v0.26.1-x86_64-unknown-linux-musl/bat" "$HOME/.local/bin/bat"
install_file "$work/bluetui" "$HOME/.local/bin/bluetui"
install_file "$work/wifitui/wifitui" "$HOME/.local/bin/wifitui"
while IFS= read -r -d '' src; do rel=${src#"$root/fonts/"}; install_file "$src" "$HOME/.local/share/fonts/$rel"; done < <(find "$root/fonts" -type f -print0)
# The original btop theme contains the original user's absolute home path.
python3 - "$HOME/.config/btop/btop.conf" "$HOME" <<'PY'
import sys
from pathlib import Path
p=Path(sys.argv[1]); s=p.read_text(); s=s.replace('/home/farhanakhtar/.config/btop/themes/t480.theme', sys.argv[2]+'/.config/btop/themes/t480.theme'); p.write_text(s)
PY
# Install the file-manager icon theme and refresh its cache.
if [[ -d "$root/icons" ]]; then
  while IFS= read -r -d '' src; do rel=${src#"$root/icons/"}; install_file "$src" "$HOME/.local/share/icons/$rel"; done < <(find "$root/icons" -type f -print0)
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then gtk-update-icon-cache -f -t "$HOME/.local/share/icons/GitHub-Boxy"; fi
fi
# LibreWolf profiles have generated names; only install automatically when unambiguous.
shopt -s nullglob
profiles=("$HOME/.config/librewolf/librewolf/"*.default-release)
if [[ ${#profiles[@]} -eq 1 && -d ${profiles[0]} && -d "$root/browser/chrome" ]]; then
  for src in "$root"/browser/chrome/*.css; do install_file "$src" "${profiles[0]}/chrome/${src##*/}"; done
else
  echo 'LibreWolf profile not found or ambiguous; see README for browser styles.'
fi
shopt -u nullglob
fc-cache -f "$HOME/.local/share/fonts"
tic -x "$root/src/st/st.info"
echo 'Installed. Start a new login shell, then run startx.'
[[ ! -d $backup ]] || echo "Previous files saved in $backup"
