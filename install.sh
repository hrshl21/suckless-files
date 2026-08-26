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

echo "Setting up pywal..."
mkdir -p ~/Pictures/wallpapers
grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' ~/.bash_profile 2>/dev/null || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bash_profile
grep -qxF '[ -f ~/.cache/wal/sequences ] && cat ~/.cache/wal/sequences' ~/.bashrc 2>/dev/null || \
  echo '[ -f ~/.cache/wal/sequences ] && cat ~/.cache/wal/sequences' >> ~/.bashrc

echo "Installing set-wallpaper helper..."
mkdir -p ~/.local/bin
cat <<'EOF' > ~/.local/bin/set-wallpaper
#!/bin/bash
# set-wallpaper: pick and apply a wallpaper (with pywal), remembering the choice.
#
# Usage:
#   set-wallpaper                # reuse last wallpaper, or pick random if none set yet
#   set-wallpaper --random       # force a new random pick from WALLPAPER_DIR
#   set-wallpaper /path/to/img   # use this specific image
#   set-wallpaper /path/to/dir   # pick a random image from this directory

set -euo pipefail

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/wallpapers}"
STATE_DIR="$HOME/.config/wallpaper"
CURRENT_LINK="$STATE_DIR/current"

mkdir -p "$STATE_DIR"

pick_random() {
  find "$1" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' \) 2>/dev/null | shuf -n 1
}

arg="${1:-}"
target=""

if [ -z "$arg" ]; then
  if [ -e "$CURRENT_LINK" ]; then
    target="$(readlink -f "$CURRENT_LINK")"
  else
    target="$(pick_random "$WALLPAPER_DIR")"
  fi
elif [ "$arg" = "--random" ]; then
  target="$(pick_random "$WALLPAPER_DIR")"
elif [ -d "$arg" ]; then
  target="$(pick_random "$arg")"
elif [ -f "$arg" ]; then
  target="$arg"
else
  echo "set-wallpaper: no such file or directory: $arg" >&2
  exit 1
fi

if [ -z "$target" ]; then
  echo "set-wallpaper: no images found in $WALLPAPER_DIR" >&2
  echo "Drop some .jpg/.png files there, or pass a path: set-wallpaper /path/to/image.jpg" >&2
  exit 1
fi

ln -sfn "$target" "$CURRENT_LINK"

if command -v wal &>/dev/null; then
  wal -i "$target"
elif command -v feh &>/dev/null; then
  feh --bg-fill "$target"
fi
EOF
chmod +x ~/.local/bin/set-wallpaper

echo "Setting up .xinitrc to start dwm..."
cat <<'EOF' > ~/.xinitrc
#!/bin/sh
export PATH="$HOME/.local/bin:$PATH"

set-wallpaper &
picom --config ~/.config/picom/picom.conf & # Optional: set config path
dwmblocks &
exec dwm
EOF

chmod +x ~/.xinitrc

echo "Registering dwm as a login-manager session..."
sudo tee /usr/local/bin/start-dwm.sh > /dev/null <<'EOF'
#!/bin/sh
[ -f "$HOME/.xinitrc" ] && exec sh "$HOME/.xinitrc"
exec dwm
EOF
sudo chmod +x /usr/local/bin/start-dwm.sh

sudo tee /usr/share/xsessions/dwm.desktop > /dev/null <<'EOF'
[Desktop Entry]
Name=dwm
Comment=Dynamic window manager
Exec=/usr/local/bin/start-dwm.sh
Type=Application
EOF

echo "DWM environment setup complete."
echo "On a real TTY (no desktop session running), run 'startx' to launch dwm directly."
echo "From a login manager (GDM/SDDM/LightDM), log out and pick the 'dwm' session from the gear/session menu instead."
