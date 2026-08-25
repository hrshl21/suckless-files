#!/bin/bash
#
# Installs dwm, dmenu, st, dwmblocks (status bar) and slock.
# For each tool, builds from this repo's own subfolder if it already
# contains source (so your local patches/configs are used); otherwise
# clones the upstream repo into that folder first.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# name:git-url
TOOLS=(
  "dwm:https://git.suckless.org/dwm"
  "dmenu:https://git.suckless.org/dmenu"
  "st:https://git.suckless.org/st"
  "dwmblocks:https://github.com/LukeSmithxyz/dwmblocks"
  "slock:https://git.suckless.org/slock"
)

if command -v pacman &>/dev/null; then
  echo "[1/4] Updating system (Arch)..."
  sudo pacman -Syu --noconfirm

  echo "[2/4] Installing essentials and build dependencies..."
  sudo pacman -S --noconfirm --needed \
    git base-devel xorg-server xorg-xinit xterm \
    libx11 libxft libxinerama libxrandr

  echo "[3/4] Installing extras: picom, pywal, feh..."
  sudo pacman -S --noconfirm --needed picom python-pywal feh

elif command -v dnf &>/dev/null; then
  echo "[1/4] Updating system (Fedora)..."
  sudo dnf upgrade --refresh -y

  echo "[2/4] Installing essentials and build dependencies..."
  sudo dnf install -y \
    git gcc gcc-c++ make pkgconf-pkg-config \
    xorg-x11-server-Xorg xorg-x11-xinit xterm \
    libX11-devel libXft-devel libXinerama-devel libXext-devel \
    libXrandr-devel freetype-devel fontconfig-devel

  echo "[3/4] Installing extras: picom, pywal, feh..."
  sudo dnf install -y picom feh python3-pip
  pip3 install --user pywal

else
  echo "Unsupported distro: no pacman or dnf found." >&2
  exit 1
fi

echo "[4/4] Building suckless tools..."
for entry in "${TOOLS[@]}"; do
  name="${entry%%:*}"
  url="${entry#*:}"
  dir="$SCRIPT_DIR/$name"

  mkdir -p "$dir"

  if [ -f "$dir/Makefile" ]; then
    echo "  -> $name: using existing source in $dir"
  else
    echo "  -> $name: no source found, cloning $url"
    git clone "$url" "$dir/_src"
    shopt -s dotglob
    mv "$dir"/_src/* "$dir"/
    shopt -u dotglob
    rmdir "$dir/_src"
  fi

  echo "  -> $name: building and installing"
  (cd "$dir" && sudo make clean install)
done

echo "Setting up .xinitrc to start dwm..."
cat <<'EOF' > ~/.xinitrc
#!/bin/sh
wal -i ~/Pictures/wallpapers/default.jpg &  # Update this path to your wallpaper
picom --config ~/.config/picom/picom.conf & # Optional: set config path
dwmblocks &
exec dwm
EOF

chmod +x ~/.xinitrc

echo "DWM environment setup complete. Run 'startx' to launch dwm."
