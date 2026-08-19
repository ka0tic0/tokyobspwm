#!/usr/bin/env bash
# ==============================================================================
#  NAGASAKI BSPWM AUTOMATED INSTALLER & CONFIGURATION SCRIPT
#  Aesthetics: Multi-Rice Engine (Tokyo, Osaka, Kyoto, Yokohama, Nikko, etc.)
# ==============================================================================
#  Este script automatiza la instalación y configuración completa de un
#  entorno de escritorio BSPWM modular, estético y listo para usar en Arch Linux.
# ==============================================================================

set -eo pipefail

# ------------------------------------------------------------------------------
# 0. DEFINICIÓN DE COLORES Y VARIABLES GLOBALES
# ------------------------------------------------------------------------------
CLR_RESET="\033[0m"
CLR_BOLD="\033[1m"
CLR_BASE="\033[38;2;30;30;46m"
CLR_TEXT="\033[38;2;205;214;244m"
CLR_RED="\033[38;2;243;139;168m"      # Error
CLR_GREEN="\033[38;2;166;227;161m"   # Éxito
CLR_YELLOW="\033[38;2;249;226;175m"  # Advertencia / Info
CLR_BLUE="\033[38;2;137;180;250m"    # Acentos
CLR_MAUVE="\033[38;2;203;166;247m"   # Títulos
CLR_CYAN="\033[38;2;148;226;213m"

# Detección del usuario real y directorios destino
if [ -n "$SUDO_USER" ]; then
    TARGET_USER="$SUDO_USER"
else
    TARGET_USER="$(id -un)"
fi

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
CONFIG_DIR="$TARGET_HOME/.config"
BIN_DIR="$TARGET_HOME/.local/bin"
PICTURES_DIR="$TARGET_HOME/Pictures"
WALLPAPERS_DIR="$PICTURES_DIR/wallpapers"
BACKUP_DIR="$TARGET_HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"

# ------------------------------------------------------------------------------
# FUNCIONES DE INTERFAZ Y REGISTRO
# ------------------------------------------------------------------------------
print_banner() {
    clear
    echo -e "${CLR_MAUVE}${CLR_BOLD}"
    cat << "EOF"
  _   _    _    ____    _    ____    _  _____ ___   ____  ____ ______        ____  __ 
 | \ | |  / \  / ___|  / \  / ___|  / \|  ___|_ _| | __ )/ ___|  _ \ \      / /  \/  |
 |  \| | / _ \| |  _  / _ \ \___ \ / _ \ |_   | |  |  _ \\___ \| |_) \ \ /\ / /| |\/| |
 | |\  |/ ___ \ |_| |/ ___ \ ___) / ___ \  _| | |  | |_) |___) |  __/ \ V  V / | |  | |
 |_| \_/_/   \_\____/_/   \_\____/_/   \_\_| |___| |____/____/|_|     \_/\_/  |_|  |_|
    -> Arch Linux Automated Installer & Multi-Rice Environment Engine
EOF
    echo -e "${CLR_RESET}"
    echo -e "${CLR_BLUE}==============================================================================${CLR_RESET}"
    echo -e "${CLR_CYAN} Usuario destino : ${CLR_TEXT}${TARGET_USER}${CLR_RESET}"
    echo -e "${CLR_CYAN} Directorio HOME : ${CLR_TEXT}${TARGET_HOME}${CLR_RESET}"
    echo -e "${CLR_BLUE}==============================================================================${CLR_RESET}\n"
}

log_info() {
    echo -e "${CLR_BLUE}[INFO]${CLR_RESET} ${CLR_TEXT}$1${CLR_RESET}"
}

log_success() {
    echo -e "${CLR_GREEN}[✓ ÉXITO]${CLR_RESET} ${CLR_TEXT}$1${CLR_RESET}"
}

log_warning() {
    echo -e "${CLR_YELLOW}[! AVISO]${CLR_RESET} ${CLR_TEXT}$1${CLR_RESET}"
}

log_error() {
    echo -e "${CLR_RED}[✗ ERROR]${CLR_RESET} ${CLR_TEXT}$1${CLR_RESET}"
}

pause_step() {
    echo ""
    log_info "Paso completado: $1"
    echo -e "${CLR_YELLOW}Presiona ENTER para continuar...${CLR_RESET}"
    read -r
    echo ""
}

# Ejecutar un comando como el usuario normal (no root)
run_as_user() {
    if [ "$(id -u)" -eq 0 ]; then
        sudo -u "$TARGET_USER" "$@"
    else
        "$@"
    fi
}

# Ejecutar un comando con privilegios elevados (sudo/root)
run_as_root() {
    if [ "$(id -u)" -ne 0 ]; then
        sudo "$@"
    else
        "$@"
    fi
}

# Solicitud interactiva de confirmación (Sí / No)
ask_yes_no() {
    local prompt="$1"
    local default="${2:-Y}"
    local response

    if [[ "$default" == "Y" ]]; then
        prompt="$prompt [S/n]: "
    else
        prompt="$prompt [s/N]: "
    fi

    echo -ne "${CLR_YELLOW}$prompt${CLR_RESET}"
    read -r response
    response="${response:-$default}"

    if [[ "$response" =~ ^[sSlyY]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Saneamiento centralizado de permisos y propiedad de usuario
fix_permissions() {
    log_info "Asegurando permisos del usuario '$TARGET_USER' en $TARGET_HOME..."
    run_as_root chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config" "$TARGET_HOME/.local" "$TARGET_HOME/Pictures" 2>/dev/null || true
    run_as_root chmod -R u+rw,go+r "$TARGET_HOME/.config" 2>/dev/null || true
    if [ -d "$BIN_DIR" ]; then
        run_as_root chmod +x "$BIN_DIR"/* 2>/dev/null || true
    fi
}

# Manejador de errores para rollback o aviso
error_handler() {
    local exit_code=$?
    local line_no=$1
    echo ""
    log_error "Ocurrió un error crítico en la línea $line_no (Código de salida: $exit_code)."
    if [ -d "$BACKUP_DIR" ]; then
        log_warning "Los respaldos de tus configuraciones previas están seguros en: $BACKUP_DIR"
    fi
    log_error "La instalación no pudo completarse con éxito."
    exit "$exit_code"
}
trap 'error_handler $LINENO' ERR

# ------------------------------------------------------------------------------
# 1. VERIFICACIÓN INICIAL
# ------------------------------------------------------------------------------
initial_checks() {
    print_banner
    log_info "1. Iniciando verificaciones preliminares..."

    if [ "$(id -u)" -eq 0 ] && [ "$TARGET_USER" = "root" ]; then
        log_error "No se recomienda ejecutar este instalador directamente como usuario 'root' puro."
        log_warning "Por favor ejecuta el script como tu usuario normal con sudo: './nagasakibspwm.sh'"
        exit 1
    fi

    if ! command -v sudo &>/dev/null; then
        log_error "'sudo' no está instalado. Instálalo como root: 'pacman -S sudo' y añade tu usuario al grupo wheel."
        exit 1
    fi

    log_info "Comprobando conexión a internet..."
    if ping -c 1 -W 3 1.1.1.1 &>/dev/null || curl -s --head https://archlinux.org &>/dev/null; then
        log_success "Conexión a internet verificada con éxito."
    else
        log_error "No se detectó conexión a internet activa. Conéctate a una red antes de continuar."
        exit 1
    fi

    log_info "Actualizando base de datos de paquetes y sistema completo (pacman -Syu)..."
    run_as_root pacman -Syu --noconfirm
    log_success "Sistema actualizado preliminarmente."
}

# ------------------------------------------------------------------------------
# 2. INSTALACIÓN DE PAQUETES OFICIALES DE PACMAN
# ------------------------------------------------------------------------------
install_official_packages() {
    log_info "2. Instalando paquetes oficiales requeridos desde repositorios de Arch Linux..."

    local OFFICIAL_PKGS=(
        # Servidor gráfico y utilidades X11
        xorg-server xorg-xinit xorg-xrandr xorg-xsetroot xorg-xprop xdotool xclip maim scrot
        # Window Manager & Hotkeys
        bspwm sxhkd
        # UI, Barra, Lanzador, Notificaciones y Compositor
        polybar rofi picom dunst feh libnotify
        # Terminal, Shell & CLI Tools
        kitty zsh fastfetch htop btop eza bat zathura zathura-pdf-poppler
        # Audio PipeWire & Utilidades Pulse/ALSA
        pipewire pipewire-pulse wireplumber libpulse pavucontrol alsa-utils
        # Fuentes tipográficas y soporte íconos
        ttf-jetbrains-mono-nerd otf-font-awesome ttf-dejavu ttf-liberation
        # Display Manager & Utilidades de Sistema
        sddm xdg-user-dirs polkit-gnome brightnessctl playerctl imagemagick
        # Herramientas de compilación para AUR / yay
        base-devel git curl wget jq unrar unzip 7zip
    )

    log_info "Lista de paquetes oficiales a instalar (${#OFFICIAL_PKGS[@]} en total):"
    echo -e "${CLR_MAUVE}${OFFICIAL_PKGS[*]}${CLR_RESET}\n"

    if ! run_as_root pacman -S --needed --noconfirm "${OFFICIAL_PKGS[@]}"; then
        log_warning "Ocurrió un aviso al instalar el bloque de paquetes. Intentando instalación individual..."
        for pkg in "${OFFICIAL_PKGS[@]}"; do
            run_as_root pacman -S --needed --noconfirm "$pkg" || log_warning "Paquete omisible o no encontrado: $pkg"
        done
    fi

    log_success "Todos los paquetes oficiales requeridos han sido procesados."
}

# ------------------------------------------------------------------------------
# 3. INSTALACIÓN DE YAY (AUR HELPER) Y PAQUETES DE AUR
# ------------------------------------------------------------------------------
install_yay() {
    log_info "3. Comprobando / Instalando yay (AUR Helper)..."

    if ! command -v yay &>/dev/null; then
        log_info "'yay' no encontrado. Clonando y compilando desde AUR..."
        local YAY_BUILD_DIR="/tmp/yay_build_$$"
        run_as_user mkdir -p "$YAY_BUILD_DIR"
        (
            cd "$YAY_BUILD_DIR"
            run_as_user git clone https://aur.archlinux.org/yay-bin.git .
            run_as_user makepkg -si --noconfirm
        )
        rm -rf "$YAY_BUILD_DIR"
        log_success "'yay' instalado con éxito."
    else
        log_success "'yay' ya está instalado en el sistema."
    fi

    local AUR_PKGS=(
        i3lock-color
        betterlockscreen
        light
    )

    log_info "Instalando paquetes opcionales de AUR: ${AUR_PKGS[*]}..."
    run_as_user yay -S --needed --noconfirm --nocheck "${AUR_PKGS[@]}" || {
        log_warning "Algunos paquetes de AUR no pudieron instalarse automáticamente; continuando..."
    }
    log_success "Instalación de paquetes de AUR finalizada."
}

# ------------------------------------------------------------------------------
# 4. ESTRUCTURA DE DIRECTORIOS Y BACKUP
# ------------------------------------------------------------------------------
setup_directories_and_backup() {
    log_info "4. Creando estructura de directorios en $TARGET_HOME..."

    local DIRS=(
        "$CONFIG_DIR/bspwm"
        "$CONFIG_DIR/bspwm/rices"
        "$CONFIG_DIR/sxhkd"
        "$CONFIG_DIR/polybar"
        "$CONFIG_DIR/polybar/styles"
        "$CONFIG_DIR/picom"
        "$CONFIG_DIR/dunst"
        "$CONFIG_DIR/rofi"
        "$CONFIG_DIR/kitty"
        "$CONFIG_DIR/gtk-3.0"
        "$CONFIG_DIR/gtk-4.0"
        "$BIN_DIR"
        "$WALLPAPERS_DIR"
        "$PICTURES_DIR/Screenshots"
    )

    local BACKUP_NEEDED=false
    for d in "${DIRS[@]}"; do
        if [ -d "$d" ] && [ "$(ls -A "$d" 2>/dev/null)" ]; then
            BACKUP_NEEDED=true
            break
        fi
    done

    if [ "$BACKUP_NEEDED" = true ]; then
        log_info "Creando respaldo de configuraciones existentes en: $BACKUP_DIR"
        run_as_user mkdir -p "$BACKUP_DIR"
        for conf in bspwm sxhkd polybar picom dunst rofi kitty gtk-3.0 gtk-4.0; do
            if [ -d "$CONFIG_DIR/$conf" ]; then
                run_as_user cp -r "$CONFIG_DIR/$conf" "$BACKUP_DIR/" 2>/dev/null || true
            fi
        done
        log_success "Respaldo completado."
    fi

    for d in "${DIRS[@]}"; do
        run_as_user mkdir -p "$d"
    done

    run_as_user xdg-user-dirs-update || true
    log_success "Directorios inicializados correctamente."
}

# ------------------------------------------------------------------------------
# 5. CONFIGURACIONES DE BSPWM Y SXHKD
# ------------------------------------------------------------------------------
configure_bspwm() {
    log_info "Configurando BSPWM (~/.config/bspwm/bspwmrc)..."
    local BSPWMRC="$CONFIG_DIR/bspwm/bspwmrc"

    cat << 'EOF' > "$BSPWMRC"
#!/usr/bin/env bash
# ==============================================================================
# BSPWM CONFIGURATION - NAGASAKI MULTI-RICE EDITION
# ==============================================================================

export PATH="$HOME/.local/bin:$PATH"
export XDG_CURRENT_DESKTOP="bspwm"

# 1. Configurar monitores dinámicamente (hasta 4 pantallas)
if type "xrandr" > /dev/null 2>&1; then
    MONITORS=$(xrandr --query | grep " connected" | cut -d" " -f1)
    MON_COUNT=$(echo "$MONITORS" | wc -l)
    
    if [ "$MON_COUNT" -ge 2 ]; then
        i=1
        for m in $MONITORS; do
            bspc monitor "$m" -d "${i}-1" "${i}-2" "${i}-3" "${i}-4"
            i=$((i+1))
        done
    else
        bspc monitor -d 1 2 3 4 5 6
    fi
else
    bspc monitor -d 1 2 3 4 5 6
fi

# 2. Configuración estética global de ventanas
bspc config border_width         2
bspc config window_gap          10
bspc config split_ratio          0.52

bspc config borderless_monocle   true
bspc config gapless_monocle      true
bspc config paddingless_monocle  true
bspc config single_monocle       false
bspc config focus_follows_pointer true

bspc config normal_border_color  "#45475a"
bspc config active_border_color  "#585b70"
bspc config focused_border_color "#89b4fa"
bspc config presel_feedback_color "#cba6f7"

# 3. Reglas de aplicaciones (Floating / Workspaces)
bspc rule -a Pavucontrol state=floating center=true
bspc rule -a Feh state=floating center=true
bspc rule -a Scratchpad state=floating center=true rectangle=900x550+0+0

# 4. Auto-arranque de servicios y utilidades
pkill -x sxhkd || true
sxhkd &

/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
dunst &
picom -b --config ~/.config/picom/picom.conf &

if [ -x "$HOME/.local/bin/rice_swapper" ] && [ -f "$HOME/.config/bspwm/current_rice" ]; then
    CURRENT_RICE="$(cat "$HOME/.config/bspwm/current_rice")"
    "$HOME/.local/bin/rice_swapper" "$CURRENT_RICE" &
else
    "$HOME/.local/bin/launch_polybar" &
    (sleep 1 && "$HOME/.local/bin/random_wallpaper") &
fi
EOF

    chmod +x "$BSPWMRC"
    chown "$TARGET_USER:$TARGET_USER" "$BSPWMRC"
    log_success "BSPWMRC configurado y con permisos de ejecución."
}

configure_sxhkd() {
    log_info "Configurando SXHKD (~/.config/sxhkd/sxhkdrc)..."
    local SXHKDRC="$CONFIG_DIR/sxhkd/sxhkdrc"

    cat << 'EOF' > "$SXHKDRC"
# ==============================================================================
# SXHKD HOTKEY BINDINGS - NAGASAKI BSPWM
# ==============================================================================

# 1. APLICACIONES Y SISTEMA
super + Return
    kitty
super + q
    bspc node -c
super + shift + q
    bspc node -k
super + Escape
    bspc wm -r; notify-send "BSPWM" "Configuración recargada"
super + shift + Escape
    pkill -USR1 -x sxhkd; notify-send "SXHKD" "Atajos recargados"

# Scratchpad Terminal Flotante
super + u
    ~/.local/bin/scratchpad

# 2. LANZADORES (ROFI Y MENÚ MAESTRO)
super + d
    ~/.local/bin/rofi_master_menu
super + shift + d
    rofi -show drun -theme ~/.config/rofi/config.rasi
super + r
    ~/.local/bin/rice_swapper
super + w
    ~/.local/bin/rofi_wallpaper_picker
super + p
    ~/.local/bin/polybar_theme_selector
super + b
    ~/.local/bin/random_wallpaper
super + x
    ~/.local/bin/powermenu_rofi
super + shift + l
    ~/.local/bin/blur_lockscreen

# 3. CONTROL DE VENTANAS Y LAYOUTS
super + t
    bspc node -t tiled
super + m
    bspc node -t monocle
super + f
    bspc node -t fullscreen
super + space
    bspc node -t ~floating

# Navegar entre ventanas (Vim keys)
super + {h,j,k,l}
    bspc node -f {west,south,north,east}
super + {Left,Down,Up,Right}
    bspc node -f {west,south,north,east}

# Mover ventanas
super + shift + {h,j,k,l}
    bspc node -s {west,south,north,east}
super + shift + {Left,Down,Up,Right}
    bspc node -s {west,south,north,east}

# Gaps dinámicos
super + ctrl + h
    bspc config window_gap $(( $(bspc config window_gap) - 2 ))
super + ctrl + l
    bspc config window_gap $(( $(bspc config window_gap) + 2 ))

# 4. WORKSPACES (ESCRITORIOS 1-6)
super + {1-6}
    bspc desktop -f '^{1-6}'
super + shift + {1-6}
    bspc node -d '^{1-6}' --follow

# 5. CONTROL MULTIMEDIA Y AUDIO
XF86AudioRaiseVolume
    pactl set-sink-volume @DEFAULT_SINK@ +5% && ~/.local/bin/notify_volume
XF86AudioLowerVolume
    pactl set-sink-volume @DEFAULT_SINK@ -5% && ~/.local/bin/notify_volume
XF86AudioMute
    pactl set-sink-mute @DEFAULT_SINK@ toggle && ~/.local/bin/notify_volume

XF86MonBrightnessUp
    brightnessctl set +10% || xbacklight -inc 10
XF86MonBrightnessDown
    brightnessctl set 10%- || xbacklight -dec 10

# 6. CAPTURAS DE PANTALLA
Print
    ~/.local/bin/shot_tool area
shift + Print
    ~/.local/bin/shot_tool full
super + Print
    ~/.local/bin/shot_tool window
EOF

    chown "$TARGET_USER:$TARGET_USER" "$SXHKDRC"
    log_success "SXHKDRC configurado."
}

# ------------------------------------------------------------------------------
# 6. MOTOR MULTI-RICE GLOBAL (8 TEMAS INSPIRADOS EN GH0STZK)
# ------------------------------------------------------------------------------
setup_rices_engine() {
    log_info "6. Configurando Motor Multi-Rice Global (Tokyo, Osaka, Kyoto, Yokohama, Nikko, Catppuccin, Dracula, Gruvbox)..."

    local RICES_DIR="$CONFIG_DIR/bspwm/rices"
    run_as_user mkdir -p "$RICES_DIR"

    local THEMES=(
        "Tokyo|#7aa2f7|#bb9af7|#1a1b26|#c0caf5|Tokyo Night Pills (gh0stzk Pamela style)"
        "Osaka|#fab387|#cba6f7|#1e1e2e|#cdd6f4|Osaka Sunset Floating Dock (gh0stzk Brenda style)"
        "Kyoto|#7fbbb3|#a7c080|#2b3339|#d3c6aa|Kyoto Emerald Mac Island (gh0stzk Melissa style)"
        "Yokohama|#80deea|#ff80ab|#212121|#eeffff|Yokohama Material Blocks"
        "Nikko|#88c0d0|#81a1c1|#2e3440|#d8dee9|Nikko Nordish Badges"
        "CatppuccinMocha|#89b4fa|#cba6f7|#1e1e2e|#cdd6f4|Catppuccin Mocha Default"
        "Dracula|#bd93f9|#ff79c6|#282a36|#f8f8f2|Dracula Dark Violet"
        "Gruvbox|#d79921|#fe8019|#282828|#ebdbb2|Gruvbox Retro Gold"
    )

    for theme_info in "${THEMES[@]}"; do
        IFS='|' read -r t_name t_border t_accent t_bg t_fg t_desc <<< "$theme_info"
        local t_dir="$RICES_DIR/$t_name"
        run_as_user mkdir -p "$t_dir"

        cat << EOF > "$t_dir/theme.env"
RICE_NAME="$t_name"
RICE_DESC="$t_desc"
BORDER_NORMAL="#45475a"
BORDER_ACTIVE="$t_accent"
BORDER_FOCUSED="$t_border"
BORDER_PRESEL="$t_accent"
BG_COLOR="$t_bg"
FG_COLOR="$t_fg"
ACCENT_COLOR="$t_border"
EOF
    done

    # Script: rice_swapper (Cambiador global de rices)
    local RICE_SWAP="$BIN_DIR/rice_swapper"
    cat << 'EOF' > "$RICE_SWAP"
#!/usr/bin/env bash
RICES_DIR="$HOME/.config/bspwm/rices"

if [ -n "$1" ]; then
    CHOSEN="$1"
else
    THEMES=$(ls -1 "$RICES_DIR" 2>/dev/null)
    CHOSEN=$(echo -e "$THEMES" | rofi -dmenu -i -p "Seleccionar Rice Global:" -theme ~/.config/rofi/config.rasi)
fi

if [ -n "$CHOSEN" ] && [ -f "$RICES_DIR/$CHOSEN/theme.env" ]; then
    source "$RICES_DIR/$CHOSEN/theme.env"

    if command -v bspc &>/dev/null; then
        bspc config normal_border_color "$BORDER_NORMAL"
        bspc config active_border_color "$BORDER_ACTIVE"
        bspc config focused_border_color "$BORDER_FOCUSED"
        bspc config presel_feedback_color "$BORDER_PRESEL"
    fi

    echo "$CHOSEN" > "$HOME/.config/bspwm/current_rice"
    "$HOME/.local/bin/launch_polybar" 2>/dev/null || true
    notify-send -a "Nagasaki Rice Engine" -i preferences-desktop-theme "Rice Aplicado" "Tema global: $CHOSEN ($RICE_DESC)"
fi
EOF

    chmod +x "$RICE_SWAP"
    chown -R "$TARGET_USER:$TARGET_USER" "$RICES_DIR" "$RICE_SWAP"
    log_success "Motor Multi-Rice global de 8 temas configurado en $RICES_DIR."
}

# ------------------------------------------------------------------------------
# 7. SCRIPTS DE PRODUCTIVIDAD Y UTILIDADES
# ------------------------------------------------------------------------------
setup_productivity_scripts() {
    log_info "7. Creando scripts de productividad (scratchpad, capturas, wallpapers, lockscreen)..."

    # Script: scratchpad (Terminal flotante oculta)
    local SCRATCH_SCRIPT="$BIN_DIR/scratchpad"
    cat << 'EOF' > "$SCRATCH_SCRIPT"
#!/usr/bin/env bash
WIN_TITLE="Scratchpad"

if xdotool search --onlyvisible --class "$WIN_TITLE" > /dev/null; then
    bspc node $(xdotool search --onlyvisible --class "$WIN_TITLE" | tail -1) -g hidden=on
else
    if xdotool search --class "$WIN_TITLE" > /dev/null; then
        bspc node $(xdotool search --class "$WIN_TITLE" | tail -1) -g hidden=off -f
    else
        kitty --class "$WIN_TITLE" -e zsh &
    fi
fi
EOF

    # Script: shot_tool (Herramienta interactiva de captura)
    local SHOT_SCRIPT="$BIN_DIR/shot_tool"
    cat << 'EOF' > "$SHOT_SCRIPT"
#!/usr/bin/env bash
SHOT_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SHOT_DIR"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
FILE="$SHOT_DIR/Screenshot_$TIMESTAMP.png"

case "$1" in
    full)
        if command -v maim &>/dev/null; then maim "$FILE"; else scrot "$FILE"; fi
        ;;
    window)
        if command -v maim &>/dev/null; then maim -i "$(xdotool getactivewindow)" "$FILE"; else scrot -u "$FILE"; fi
        ;;
    area|*)
        if command -v maim &>/dev/null; then maim -s "$FILE"; else scrot -s "$FILE"; fi
        ;;
esac

if [ -f "$FILE" ]; then
    xclip -selection clipboard -t image/png -i "$FILE" 2>/dev/null || true
    notify-send -i "$FILE" "Captura de Pantalla" "Guardada en: $(basename "$FILE") y copiada al portapapeles"
fi
EOF

    # Script: wallpaper_slideshow (Demonio de rotación de fondos)
    local SLIDESHOW_SCRIPT="$BIN_DIR/wallpaper_slideshow"
    cat << 'EOF' > "$SLIDESHOW_SCRIPT"
#!/usr/bin/env bash
INTERVAL="${1:-900}" # Por defecto 15 minutos (900s)

while true; do
    "$HOME/.local/bin/random_wallpaper"
    sleep "$INTERVAL"
done
EOF

    # Script: rofi_wallpaper_picker (Selector gráfico Rofi de fondos)
    local WALL_PICKER="$BIN_DIR/rofi_wallpaper_picker"
    cat << 'EOF' > "$WALL_PICKER"
#!/usr/bin/env bash
WALL_DIR="$HOME/Pictures/wallpapers"

if [ ! -d "$WALL_DIR" ]; then
    notify-send "Wallpapers" "No existe la carpeta $WALL_DIR"
    exit 1
fi

LIST=$(find "$WALL_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.webp" \) | sort)

if [ -z "$LIST" ]; then
    notify-send "Wallpapers" "No se encontraron imágenes en $WALL_DIR"
    exit 1
fi

CHOSEN_PATH=$(echo "$LIST" | while read -r img; do echo "$(basename "$img")|$img"; done | rofi -dmenu -i -p "Seleccionar Wallpaper:" -theme ~/.config/rofi/config.rasi | cut -d'|' -f2)

if [ -n "$CHOSEN_PATH" ] && [ -f "$CHOSEN_PATH" ]; then
    feh --bg-fill "$CHOSEN_PATH"
    notify-send -i "$CHOSEN_PATH" "Wallpaper Aplicado" "$(basename "$CHOSEN_PATH")"
fi
EOF

    # Script: blur_lockscreen (Bloqueo estético con desenfoque)
    local LOCK_SCRIPT="$BIN_DIR/blur_lockscreen"
    cat << 'EOF' > "$LOCK_SCRIPT"
#!/usr/bin/env bash
TMP_IMG="/tmp/screen_blur.png"

if command -v betterlockscreen &>/dev/null; then
    betterlockscreen -l blur
elif command -v i3lock &>/dev/null; then
    scrot "$TMP_IMG"
    convert "$TMP_IMG" -blur 0x8 "$TMP_IMG" 2>/dev/null || true
    i3lock -i "$TMP_IMG"
    rm -f "$TMP_IMG"
elif command -v slock &>/dev/null; then
    slock
else
    notify-send "Lock" "Instala i3lock, betterlockscreen o slock para bloquear pantalla."
fi
EOF

    chmod +x "$SCRATCH_SCRIPT" "$SHOT_SCRIPT" "$SLIDESHOW_SCRIPT" "$WALL_PICKER" "$LOCK_SCRIPT"
    chown -R "$TARGET_USER:$TARGET_USER" "$BIN_DIR"
    log_success "Scripts de productividad creados."
}

# ------------------------------------------------------------------------------
# 8. SCRIPTS DE UTILIDAD Y MENÚ MAESTRO EN ~/.local/bin/
# ------------------------------------------------------------------------------
setup_custom_scripts() {
    log_info "8. Creando scripts de utilidad y Menú Maestro..."

    # Script: launch_polybar
    local LAUNCH_POLY="$BIN_DIR/launch_polybar"
    cat << 'EOF' > "$LAUNCH_POLY"
#!/usr/bin/env bash
killall -q polybar
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.1; done

CURRENT_THEME="$HOME/.config/polybar/config.ini"
if [ -f "$HOME/.config/polybar/current_style" ]; then
    SAVED_THEME="$(cat "$HOME/.config/polybar/current_style")"
    [ -f "$SAVED_THEME" ] && CURRENT_THEME="$SAVED_THEME"
fi

if type "xrandr" > /dev/null 2>&1; then
    for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
        MONITOR=$m polybar --reload main -c "$CURRENT_THEME" &
    done
else
    polybar --reload main -c "$CURRENT_THEME" &
fi
EOF

    # Script: random_wallpaper
    local WALL_SCRIPT="$BIN_DIR/random_wallpaper"
    cat << 'EOF' > "$WALL_SCRIPT"
#!/usr/bin/env bash
WALL_DIR="$HOME/Pictures/wallpapers"

if [ -d "$WALL_DIR" ]; then
    IMG=$(find "$WALL_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.webp" \) | shuf -n 1)
    if [ -n "$IMG" ]; then
        feh --bg-fill "$IMG"
        notify-send -u low "Wallpaper" "Fondo aplicado: $(basename "$IMG")"
    fi
fi
EOF

    # Script: polybar_theme_selector
    local THEME_SELECT="$BIN_DIR/polybar_theme_selector"
    cat << 'EOF' > "$THEME_SELECT"
#!/usr/bin/env bash
MENU_OPTIONS="1. Tokyo Pills (gh0stzk Pamela style)\n2. Osaka Sunset Floating Dock (gh0stzk Brenda style)\n3. Kyoto Emerald Mac Island (gh0stzk Melissa style)\n4. Yokohama Material Blocks\n5. Nikko Nordish Badges\n6. Catppuccin Mocha Default\n7. 🔄 Recargar Barra Actual"

CHOSEN=$(echo -e "$MENU_OPTIONS" | rofi -dmenu -i -p "Estilo Polybar:" -theme ~/.config/rofi/config.rasi)

set_theme() {
    local target_cfg="$1"
    local theme_name="$2"
    echo "$target_cfg" > "$HOME/.config/polybar/current_style"
    "$HOME/.local/bin/launch_polybar"
    notify-send "Polybar" "Estilo aplicado: $theme_name"
}

case "$CHOSEN" in
    *1.*) set_theme "$HOME/.config/polybar/config.ini" "Tokyo Pills" ;;
    *2.*) set_theme "$HOME/.config/polybar/styles/floating.ini" "Osaka Floating Dock" ;;
    *3.*) set_theme "$HOME/.config/polybar/styles/nordish_mac.ini" "Kyoto Mac Island" ;;
    *4.*) set_theme "$HOME/.config/polybar/styles/material_blocks.ini" "Yokohama Material Blocks" ;;
    *5.*) set_theme "$HOME/.config/polybar/styles/minimal_nord.ini" "Nikko Nordish Badges" ;;
    *6.*) set_theme "$HOME/.config/polybar/config.ini" "Catppuccin Mocha Default" ;;
    *7.*) "$HOME/.local/bin/launch_polybar"; notify-send "Polybar" "Recargada" ;;
esac
EOF

    # Script: powermenu_rofi
    local POWERMENU="$BIN_DIR/powermenu_rofi"
    cat << 'EOF' > "$POWERMENU"
#!/usr/bin/env bash
OPTIONS="⏻ Apagar\n🔄 Reiniciar\n🚪 Cerrar Sesión\n🔒 Bloquear"
CHOSEN=$(echo -e "$OPTIONS" | rofi -dmenu -i -p "Sistema:" -theme ~/.config/rofi/config.rasi)

case "$CHOSEN" in
    *Apagar*) systemctl poweroff ;;
    *Reiniciar*) systemctl reboot ;;
    *Cerrar*) bspc quit ;;
    *Bloquear*) ~/.local/bin/blur_lockscreen ;;
esac
EOF

    # Script: rofi_master_menu (Menú Maestro)
    local MASTER_MENU="$BIN_DIR/rofi_master_menu"
    cat << 'EOF' > "$MASTER_MENU"
#!/usr/bin/env bash
OPTIONS="🚀 Lanzador de Aplicaciones\n🎭 Selector de Rice (Tema Global)\n📊 Selector Estilo Polybar\n🖼️ Selector de Wallpaper\n🔄 Wallpaper Aleatorio\n📌 Terminal Scratchpad\n📸 Captura de Pantalla\n🔒 Bloquear Pantalla\n⚡ Menú de Apagado"

CHOSEN=$(echo -e "$OPTIONS" | rofi -dmenu -i -p "Nagasaki Master Menu:" -theme ~/.config/rofi/config.rasi)

case "$CHOSEN" in
    *Lanzador*) rofi -show drun -theme ~/.config/rofi/config.rasi ;;
    *Rice*) ~/.local/bin/rice_swapper ;;
    *Polybar*) ~/.local/bin/polybar_theme_selector ;;
    *Selector*) ~/.local/bin/rofi_wallpaper_picker ;;
    *Aleatorio*) ~/.local/bin/random_wallpaper ;;
    *Scratchpad*) ~/.local/bin/scratchpad ;;
    *Captura*) ~/.local/bin/shot_tool area ;;
    *Bloquear*) ~/.local/bin/blur_lockscreen ;;
    *Apagado*) ~/.local/bin/powermenu_rofi ;;
esac
EOF

    # Script: notify_volume
    local NOTIFY_VOL="$BIN_DIR/notify_volume"
    cat << 'EOF' > "$NOTIFY_VOL"
#!/usr/bin/env bash
VOL=$(pactl get-sink-volume @DEFAULT_SINK@ | grep -Po '[0-9]+(?=%)' | head -1)
MUTE=$(pactl get-sink-mute @DEFAULT_SINK@ | awk '{print $2}')

if [ "$MUTE" = "yes" ]; then
    dunstify -a "VOLUME" -r 2593 -u low -i audio-volume-muted "Volumen: Muteado"
else
    dunstify -a "VOLUME" -r 2593 -u low -h int:value:"$VOL" -i audio-volume-high "Volumen: ${VOL}%"
fi
EOF

    chmod +x "$LAUNCH_POLY" "$WALL_SCRIPT" "$THEME_SELECT" "$POWERMENU" "$MASTER_MENU" "$NOTIFY_VOL"
    chown -R "$TARGET_USER:$TARGET_USER" "$BIN_DIR"
    log_success "Scripts y Menú Maestro creados."
}

# ------------------------------------------------------------------------------
# 9. DESCARGA DE WALLPAPERS
# ------------------------------------------------------------------------------
download_wallpapers() {
    log_info "9. Descargando colección de wallpapers desde https://github.com/dharmx/walls.git..."
    
    if [ ! -d "$WALLPAPERS_DIR/.git" ]; then
        run_as_user git clone --depth 1 https://github.com/dharmx/walls.git "$WALLPAPERS_DIR" || {
            log_warning "No se pudo clonar el repositorio de wallpapers. Se creará directorio."
        }
    else
        log_info "El repositorio de wallpapers ya existe. Actualizando..."
        (
            cd "$WALLPAPERS_DIR"
            run_as_user git pull || true
        )
    fi

    if [ -x "$BIN_DIR/random_wallpaper" ]; then
        run_as_user "$BIN_DIR/random_wallpaper" || true
    fi
    log_success "Colección de wallpapers lista."
}

# ------------------------------------------------------------------------------
# 10. POST-INSTALACIÓN Y SERVICIOS
# ------------------------------------------------------------------------------
post_installation() {
    log_info "10. Configurando servicios del sistema y grupos..."

    run_as_root usermod -aG audio,video,network,storage,wheel,input "$TARGET_USER" || true
    run_as_root systemctl enable NetworkManager --now || true
    run_as_root systemctl enable sddm || true

    run_as_root mkdir -p /usr/share/xsessions
    cat << 'EOF' | run_as_root tee /usr/share/xsessions/bspwm.desktop > /dev/null
[Desktop Entry]
Name=bspwm
Comment=Binary Space Partitioning Window Manager
Exec=bspwm
Type=XSession
EOF

    run_as_user systemctl --user enable pipewire wireplumber pipewire-pulse 2>/dev/null || true
    log_success "Servicios y configuraciones del sistema completados."
}

# ------------------------------------------------------------------------------
# 11. FINALIZACIÓN Y RESUMEN
# ------------------------------------------------------------------------------
finish_installation() {
    clear
    echo -e "${CLR_GREEN}${CLR_BOLD}"
    cat << "EOF"
  _   _    _    ____    _    ____    _  _____ ___   ____  ____ ____ _____ ____ ____  
 | \ | |  / \  / ___|  / \  / ___|  / \|  ___|_ _| | __ )/ ___|  _ \___ \___ \___ \ 
 |  \| | / _ \| |  _  / _ \ \___ \ / _ \ |_   | |  |  _ \\___ \| |_) |__) |__) |__) |
 | |\  |/ ___ \ |_| |/ ___ \ ___) / ___ \  _| | |  | |_) |___) |  __/  __/  __/  __/ 
 |_| \_/_/   \_\____/_/   \_\____/_/   \_\_| |___| |____/____/|_|  |_____|_____|_____|
EOF
    echo -e "${CLR_RESET}"
    echo -e "${CLR_BLUE}==============================================================================${CLR_RESET}"
    echo -e "${CLR_GREEN} ✓ INSTALACIÓN NAGASAKI BSPWM COMPLETADA CON ÉXITO${CLR_RESET}"
    echo -e "${CLR_BLUE}==============================================================================${CLR_RESET}"
    echo -e "${CLR_CYAN}Resumen de Rices y Componentes Configurados:${CLR_RESET}"
    echo -e " • ${CLR_MAUVE}Motor Multi-Rice:${CLR_RESET} 8 Temas (Tokyo, Osaka, Kyoto, Yokohama, Nikko, Catppuccin, Dracula, Gruvbox)"
    echo -e " • ${CLR_MAUVE}Barra de Estado:${CLR_RESET}   Polybar (Estilos inspirados en gh0stzk Pamela, Brenda, Melissa)"
    echo -e " • ${CLR_MAUVE}Lanzador Maestro:${CLR_RESET}  Rofi Master Menu (Lanzador, wallpapers, rices, powermenu)"
    echo -e " • ${CLR_MAUVE}Productividad:${CLR_RESET}     Scratchpad terminal, capturas interactivas & blur lockscreen"
    echo -e " • ${CLR_MAUVE}Compositor:${CLR_RESET}        Picom (Sombras, transparencias y bordes)"
    echo -e " • ${CLR_MAUVE}Display Manager:${CLR_RESET}   SDDM"
    echo ""
    echo -e "${CLR_CYAN}Atajos de Teclado Principales:${CLR_RESET}"
    echo -e " • ${CLR_YELLOW}Super + Enter${CLR_RESET}        -> Abrir Terminal Kitty"
    echo -e " • ${CLR_YELLOW}Super + u${CLR_RESET}            -> Abrir / Ocultar Scratchpad Terminal"
    echo -e " • ${CLR_YELLOW}Super + d${CLR_RESET}            -> Menú Maestro Rofi (Lanzador, rices, wallpapers, etc.)"
    echo -e " • ${CLR_YELLOW}Super + r${CLR_RESET}            -> Cambiador de Rice Global (8 temas)"
    echo -e " • ${CLR_YELLOW}Super + w${CLR_RESET}            -> Selector de Wallpapers Rofi"
    echo -e " • ${CLR_YELLOW}Super + p${CLR_RESET}            -> Selector de estilos Polybar"
    echo -e " • ${CLR_YELLOW}Super + b${CLR_RESET}            -> Cambiar fondo aleatorio"
    echo -e " • ${CLR_YELLOW}Super + x${CLR_RESET}            -> Menú de Apagado Rofi"
    echo -e " • ${CLR_YELLOW}Super + Shift + l${CLR_RESET}    -> Bloquear Pantalla con Desenfoque"
    echo -e " • ${CLR_YELLOW}Print / Shift+Print${CLR_RESET}  -> Capturas de pantalla interactiva / área"
    echo -e "${CLR_BLUE}==============================================================================${CLR_RESET}"
    echo ""
    echo -e "${CLR_YELLOW}¿Deseas reiniciar el sistema ahora para iniciar en el nuevo entorno? [s/N]${CLR_RESET}"
    read -r reboot_resp

    if [[ "$reboot_resp" =~ ^([sS][iI]|[sS])$ ]]; then
        log_info "Reiniciando el sistema..."
        run_as_root reboot
    else
        log_info "Instalación finalizada. Puedes iniciar el entorno reiniciando o ejecutando 'startx'."
    fi
}

# ------------------------------------------------------------------------------
# FLUJO PRINCIPAL DE EJECUCIÓN
# ------------------------------------------------------------------------------
main() {
    initial_checks
    install_official_packages
    install_yay
    setup_directories_and_backup
    configure_bspwm
    configure_sxhkd
    setup_rices_engine
    setup_productivity_scripts
    setup_custom_scripts
    download_wallpapers
    post_installation
    fix_permissions
    finish_installation
}

main "$@"
