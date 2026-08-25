#!/usr/bin/env bash
# ==============================================================================
#  ARCH LINUX BSPWM AUTOMATED INSTALLER & CONFIGURATION SCRIPT
#  Aesthetics: Catppuccin Mocha
# ==============================================================================
#  Este script automatiza la instalación y configuración completa de un
#  entorno de escritorio BSPWM modular, estético y listo para usar en Arch Linux.
# ==============================================================================

set -eo pipefail

# ------------------------------------------------------------------------------
# 0. DEFINICIÓN DE COLORES Y VARIABLES GLOBALES
# ------------------------------------------------------------------------------
# Paleta ANSI inspirada en Catppuccin Mocha
CLR_RESET="\033[0m"
CLR_BOLD="\033[1m"
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
  ____  ____  ______        ____  __  __   ____       _               
 | __ )/ ___||  _ \ \      / /  \/  | \ |  _ \  ___| |_ _   _ _ __  
 |  _ \\___ \| |_) \ \ /\ / /| |\/| |  \| |_) |/ _ \ __| | | | '_ \ 
 | |_) |___) |  __/ \ V  V / | |  | |   |  __/|  __/ |_| |_| | |_) |
 |____/|____/|_|     \_/\_/  |_|  |_|   |_|    \___|\__|\__,_| .__/ 
                                                              |_|    
    -> Arch Linux Base to Beautiful Catppuccin Mocha BSPWM
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

    # Verificar que no se intente compilar yay puramente como root sin usuario destino válido
    if [ "$(id -u)" -eq 0 ] && [ "$TARGET_USER" = "root" ]; then
        log_error "No se recomienda ejecutar este instalador directamente como usuario 'root' puro."
        log_warning "Arch Linux y herramientas AUR (como yay/makepkg) prohíben compilar como root."
        log_warning "Por favor ejecuta el script como tu usuario normal con sudo: './${0##*/}'"
        exit 1
    fi

    # Verificar privilegios sudo
    if ! command -v sudo &>/dev/null; then
        log_error "'sudo' no está instalado. Instálalo como root: 'pacman -S sudo' y añade tu usuario al grupo wheel."
        exit 1
    fi

    # Verificar conexión a Internet
    log_info "Comprobando conexión a internet..."
    if ping -c 1 -W 3 1.1.1.1 &>/dev/null || curl -s --head https://archlinux.org &>/dev/null; then
        log_success "Conexión a internet verificada con éxito."
    else
        log_error "No se detectó conexión a internet activa. Conéctate a una red antes de continuar."
        exit 1
    fi

    # Actualización del sistema
    log_info "Actualizando base de datos de paquetes y sistema completo (pacman -Syu)..."
    run_as_root pacman -Syu --noconfirm
    log_success "Sistema actualizado correctamente."

    echo ""
    echo -e "${CLR_YELLOW}¿Deseas continuar con la instalación de paquetes y configuración de BSPWM? [S/n]${CLR_RESET}"
    read -r response
    if [[ "$response" =~ ^([nN][oO]|[nN])$ ]]; then
        log_warning "Instalación cancelada por el usuario."
        exit 0
    fi
}

# ------------------------------------------------------------------------------
# 2. INSTALACIÓN DE PAQUETES OFICIALES (PACMAN)
# ------------------------------------------------------------------------------
install_official_packages() {
    log_info "2. Instalando paquetes base requeridos desde repositorios oficiales..."

    local PACKAGES=(
        # Servidor X & utilidades de display
        xorg-server
        xorg-xinit
        xorg-xrandr
        xorg-xsetroot
        xorg-xprop
        xorg-xev
        xdotool
        xclip
        maim

        # Window Manager & Hotkeys
        bspwm
        sxhkd

        # Terminal & Shell Utils
        kitty
        neovim
        cava
        zsh
        zsh-completions
        zsh-autosuggestions
        zsh-syntax-highlighting
        bash-completion
        fastfetch
        htop
        btop
        eza
        bat
        zathura
        zathura-pdf-poppler

        # Barra, Lanzador & Compositor
        polybar
        rofi
        picom

        # Notificaciones & Capturas
        dunst
        libnotify
        scrot

        # Gestor de fondos de pantalla e imágenes
        feh
        imagemagick

        # Gestor de archivos & thumbnails
        thunar
        thunar-volman
        thunar-archive-plugin
        tumbler
        gvfs

        # Red & Bluetooth
        networkmanager
        network-manager-applet
        bluez
        bluez-utils

        # Audio (Pipewire stack, pamixer & Pulse utilities)
        pipewire
        pipewire-pulse
        pipewire-alsa
        wireplumber
        libpulse
        pavucontrol
        pamixer
        alsa-utils

        # Fuentes tipográficas
        ttf-jetbrains-mono-nerd
        noto-fonts
        noto-fonts-emoji
        otf-font-awesome
        ttf-nerd-fonts-symbols
        ttf-dejavu
        ttf-liberation

        # Apariencia y motores GTK
        lxappearance 
        xsettingsd

        # Display Manager, Monitores & Control del Sistema
        sddm
        brightnessctl
        playerctl
        arandr
        rofi-calc

        # Utilidades del sistema & compilación
        git
        curl
        wget
        base-devel
        polkit-gnome
        xdg-user-dirs
        bc
        jq
        pacman-contrib
        7zip
        unrar
        unzip
    )

    log_info "Instalando paquetes requeridos via pacman (esto puede tomar unos minutos)..."
    if ! run_as_root pacman -S --needed --noconfirm "${PACKAGES[@]}"; then
        log_warning "Ocurrió un aviso al instalar el bloque de paquetes. Intentando instalación individual de respaldo..."
        for pkg in "${PACKAGES[@]}"; do
            run_as_root pacman -S --needed --noconfirm "$pkg" || log_warning "Paquete omitido: $pkg"
        done
    fi
    log_success "Todos los paquetes oficiales requeridos han sido procesados."
}

# ------------------------------------------------------------------------------
# 3. GESTOR AUR (YAY) Y PAQUETES OPCIONALES
# ------------------------------------------------------------------------------
install_yay() {
    log_info "3. Verificando gestor AUR (yay)..."

    if command -v yay &>/dev/null; then
        log_success "yay ya se encuentra instalado en el sistema."
    else
        log_info "Instalando yay desde el repositorio oficial de AUR..."
        local YAY_BUILD_DIR="/tmp/yay_build_$$"
        run_as_user mkdir -p "$YAY_BUILD_DIR"
        run_as_user git clone https://aur.archlinux.org/yay.git "$YAY_BUILD_DIR"
        
        # Compilar e instalar como el usuario normal
        (
            cd "$YAY_BUILD_DIR"
            run_as_user makepkg -si --noconfirm
        )
        rm -rf "$YAY_BUILD_DIR"
        log_success "yay ha sido instalado con éxito."
    fi
}

install_optional_packages() {
    echo ""
    log_info "¿Deseas instalar paquetes adicionales y temas de personalización AUR? (Recomendado)"
    echo -e "${CLR_CYAN}Los paquetes opcionales incluyen:${CLR_RESET}"
    echo -e "  - ${CLR_MAUVE}brave-bin${CLR_RESET} (Navegador web rápido y privado)"
    echo -e "  - ${CLR_MAUVE}neovim${CLR_RESET} (Editor de texto moderno)"
    echo -e "  - ${CLR_MAUVE}catppuccin-gtk-theme-mocha${CLR_RESET} (Tema GTK oficial Catppuccin Mocha)"
    echo -e "  - ${CLR_MAUVE}tela-circle-icon-theme${CLR_RESET} (Paquete de iconos Tela Circle)"
    echo ""
    echo -e "${CLR_YELLOW}¿Instalar paquetes opcionales? [S/n]${CLR_RESET}"
    read -r opt_response

    if [[ ! "$opt_response" =~ ^([nN][oO]|[nN])$ ]]; then
        local AUR_PKGS=()
        local PAC_PKGS=()

        # Neovim está en repos oficiales
        PAC_PKGS+=(neovim)

        # AUR packages
        AUR_PKGS+=(
            brave-bin
            catppuccin-gtk-theme-mocha
            tela-circle-icon-theme
            rofi-greenclip
            ncspot-bin
        )

        log_info "Instalando utilidades adicionales desde repos oficiales..."
        run_as_root pacman -S --needed --noconfirm "${PAC_PKGS[@]}" || true

        log_info "Instalando temas y paquetes desde AUR via yay..."
        run_as_user yay -S --needed --noconfirm "${AUR_PKGS[@]}" || {
            log_warning "Algunos paquetes opcionales AUR pudieron requerir interacción o fallaron. Se continuará con la configuración."
        }
        log_success "Instalación de paquetes opcionales concluida."
    else
        log_info "Saltando paquetes opcionales a petición del usuario."
    fi
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
        "$CONFIG_DIR/picom"
        "$CONFIG_DIR/dunst"
        "$CONFIG_DIR/rofi"
        "$CONFIG_DIR/kitty"
        "$CONFIG_DIR/fastfetch"
        "$CONFIG_DIR/nvim"
        "$CONFIG_DIR/cava"
        "$CONFIG_DIR/ncspot"
        "$CONFIG_DIR/gtk-3.0"
        "$CONFIG_DIR/gtk-4.0"
        "$BIN_DIR"
        "$WALLPAPERS_DIR"
        "$PICTURES_DIR/Screenshots"
    )

    # Si existen configuraciones previas, respaldarlas
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
        for conf in bspwm sxhkd polybar picom dunst rofi kitty fastfetch nvim cava ncspot gtk-3.0 gtk-4.0; do
            if [ -d "$CONFIG_DIR/$conf" ]; then
                run_as_user cp -r "$CONFIG_DIR/$conf" "$BACKUP_DIR/" 2>/dev/null || true
            fi
        done
        log_success "Respaldo completado."
    fi

    # Crear todas las carpetas con propiedad del usuario destino
    for d in "${DIRS[@]}"; do
        run_as_user mkdir -p "$d"
    done

    # Generar directorios estándar XDG
    run_as_user xdg-user-dirs-update || true

    log_success "Directorios inicializados correctamente."
}

# ------------------------------------------------------------------------------
# 5. CONFIGURACIONES DETALLADAS (CATPPUCCIN MOCHA THEMED)
# ------------------------------------------------------------------------------

configure_bspwm() {
    log_info "Configurando BSPWM (~/.config/bspwm/bspwmrc)..."
    local BSPWMRC="$CONFIG_DIR/bspwm/bspwmrc"

    cat << 'EOF' > "$BSPWMRC"
#!/usr/bin/env bash
# ==============================================================================
# BSPWM CONFIGURATION - CATPPUCCIN MOCHA
# ==============================================================================

# --- Variables de Colores Catppuccin Mocha ---
COLOR_BASE="#1e1e2e"
COLOR_SURFACE="#313244"
COLOR_MAUVE="#cba6f7"
COLOR_BLUE="#89b4fa"
COLOR_RED="#f38ba8"
COLOR_TEXT="#cdd6f4"

# --- 1. Autostart de Servicios y Utilidades ---
# Hotkey daemon
pgrep -x sxhkd > /dev/null || sxhkd &

# Compositor (Picom)
killall -q picom
while pgrep -u $UID -x picom >/dev/null; do sleep 0.1; done
picom --config ~/.config/picom/picom.conf -b &

# Notificaciones (Dunst)
killall -q dunst
dunst -config ~/.config/dunst/dunstrc &

# Applet de Red
pgrep -x nm-applet > /dev/null || nm-applet &

# Gestor de Portapapeles (Greenclip daemon)
if command -v greenclip >/dev/null 2>&1; then
    pkill -x greenclip
    greenclip daemon &
fi

# Polkit Authentication Agent
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &

# Gestor de cursor
xsetroot -cursor_name left_ptr &

# Restaurar o aplicar Wallpaper aleatorio
if [ -f "$HOME/.local/bin/random_wallpaper" ]; then
    "$HOME/.local/bin/random_wallpaper" &
fi

# Iniciar Polybar (Multi-monitor)
if [ -f "$HOME/.local/bin/launch_polybar" ]; then
    "$HOME/.local/bin/launch_polybar" &
fi

# --- 2. Configuración de Pantalla y Escritorios (Workspaces) ---
# Detección de monitores
MONITORS=($(xrandr --query | grep " connected" | cut -d" " -f1))
if [ "${#MONITORS[@]}" -gt 0 ]; then
    for monitor in "${MONITORS[@]}"; do
        bspc monitor "$monitor" -d 1 2 3 4 5
    done
else
    bspc monitor -d 1 2 3 4 5 
fi

# --- 3. Configuración de Ventanas y Gaps ---
bspc config border_width         2
bspc config window_gap           10
bspc config top_padding          32
bspc config bottom_padding       6
bspc config left_padding         6
bspc config right_padding        6

bspc config split_ratio          0.52
bspc config borderless_monocle   true
bspc config gapless_monocle      true
bspc config focus_follows_pointer true
bspc config pointer_follows_focus false
bspc config center_pseudo_tiled  true

# --- 4. Colores de Bordes (Catppuccin Mocha) ---
bspc config normal_border_color   "$COLOR_SURFACE"
bspc config active_border_color   "$COLOR_BASE"
bspc config focused_border_color  "$COLOR_MAUVE"
bspc config presel_feedback_color "$COLOR_BLUE"

# --- 5. Reglas de Ventanas (Window Rules) ---
bspc rule -r *:*
bspc rule -a Pavucontrol state=floating center=true follow=on
bspc rule -a Lxappearance state=floating center=true follow=on
bspc rule -a Thunar state=floating center=true
bspc rule -a Viewnior state=floating center=true
bspc rule -a feh state=floating center=true
bspc rule -a Rofi state=floating center=true
bspc rule -a GParted state=floating center=true
bspc rule -a File-roller state=floating center=true

EOF

    chown "$TARGET_USER:$TARGET_USER" "$BSPWMRC"
    chmod +x "$BSPWMRC"
    log_success "bspwmrc configurado y con permisos de ejecución."
}

configure_sxhkd() {
    log_info "Configurando SXHKD (~/.config/sxhkd/sxhkdrc)..."
    local SXHKDRC="$CONFIG_DIR/sxhkd/sxhkdrc"

    cat << 'EOF' > "$SXHKDRC"
# ==============================================================================
# SXHKD HOTKEY BINDINGS - BSPWM
# Modkey = Super (Windows Key)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. APLICACIONES Y SISTEMA
# ------------------------------------------------------------------------------
# Terminal (Kitty)
super + Return
    kitty

# Cerrar o forzar cierre de ventana
super + q
    bspc node -c
super + shift + q
    bspc node -k

# Recargar bspwm y sxhkd
super + Escape
    bspc wm -r; notify-send "BSPWM" "Configuración recargada"
super + shift + Escape
    pkill -USR1 -x sxhkd; notify-send "SXHKD" "Atajos recargados"

# Bloquear pantalla / Cerrar sesión
super + shift + e
    bspc quit

# ------------------------------------------------------------------------------
# 2. LANZADORES Y APPLETS (ROFI Y MENÚ MAESTRO)
# ------------------------------------------------------------------------------
# Menú Maestro Integrado Rofi
super + d
    ~/.local/bin/rofi_master_menu

# Lanzador directo de aplicaciones (drun)
super + shift + d
    rofi -show drun -theme ~/.config/rofi/config.rasi

# Historial de Portapapeles (Clipboard)
super + v
    ~/.local/bin/rofi_clipboard

# Gestor de Redes Wi-Fi
super + n
    ~/.local/bin/rofi_wifi_menu

# Gestor de Dispositivos Bluetooth
super + shift + b
    ~/.local/bin/rofi_bluetooth

# Selector de Salida de Audio (Pipewire/Pulse)
super + shift + a
    ~/.local/bin/rofi_audio_output

# Gestor de Monitores y Pantallas
super + shift + m
    ~/.local/bin/rofi_monitors

# Reproductor de Música (ncspot + cava)
super + shift + s
    ~/.local/bin/launch_music_player

# Terminal Scratchpad Flotante
super + u
    ~/.local/bin/scratchpad

# Cambiador Global de Rices / Temas
super + r
    ~/.local/bin/rice_swapper

# Editor Interactivo de Rices
super + shift + r
    ~/.local/bin/rice_editor

# Mantenimiento & Tweaks del Sistema (Control Center)
super + shift + t
    ~/.local/bin/bspwm_tweaks

# Información del Sistema
super + i
    ~/.local/bin/rofi_system_info

# Archivos Recientes y Descargas
super + f
    ~/.local/bin/rofi_recent_files

# Modo Noche / Filtro Cálido (4500K)
super + shift + n
    ~/.local/bin/night_mode

# Perfiles de Energía
super + shift + p
    ~/.local/bin/rofi_power_profile

# Selector de Wallpapers
super + w
    ~/.local/bin/rofi_wallpaper_picker

# Selector de estilos de Polybar
super + p
    ~/.local/bin/polybar_theme_selector

# Cambiar fondo de pantalla aleatorio
super + b
    ~/.local/bin/random_wallpaper

# Menú de energía y apagado
super + x
    ~/.local/bin/powermenu_rofi

# Bloquear pantalla con desenfoque
super + shift + l
    ~/.local/bin/blur_lock

# ------------------------------------------------------------------------------
# 3. CONTROL DE VENTANAS Y LAYOUTS
# ------------------------------------------------------------------------------
# Alternar layouts (tiled, monocle, fullscreen)
super + t
    bspc node -t tiled
super + m
    bspc node -t monocle
super + f
    bspc node -t fullscreen
super + space
    bspc node -t ~floating

# Navegar entre ventanas (Vim keys: j=abajo, k=arriba, h/l=izq/der o ;)
super + {h,j,k,l}
    bspc node -f {west,south,north,east}
super + {Left,Down,Up,Right}
    bspc node -f {west,south,north,east}

# Mover ventanas de posición
super + shift + {h,j,k,l}
    bspc node -s {west,south,north,east}
super + shift + {Left,Down,Up,Right}
    bspc node -s {west,south,north,east}

# Ajustar Gaps dinámicamente
super + ctrl + h
    bspc config window_gap $(( $(bspc config window_gap) - 2 ))
super + ctrl + l
    bspc config window_gap $(( $(bspc config window_gap) + 2 ))

# ------------------------------------------------------------------------------
# 4. WORKSPACES (ESCRITORIOS 1-4)
# ------------------------------------------------------------------------------
# Cambiar a escritorio {1-4}
super + {1-4}
    bspc desktop -f '^{1-4}'

# Mover ventana a escritorio {1-4}
super + shift + {1-4}
    bspc node -d '^{1-4}' --follow

# ------------------------------------------------------------------------------
# 5. CONTROL MULTIMEDIA, AUDIO Y BRILLO (OSD DUNST)
# ------------------------------------------------------------------------------
XF86AudioRaiseVolume
    ~/.local/bin/notify_volume up
XF86AudioLowerVolume
    ~/.local/bin/notify_volume down
XF86AudioMute
    ~/.local/bin/notify_volume mute

# Control de reproducción de medios
XF86AudioPlay
    playerctl play-pause
XF86AudioNext
    playerctl next
XF86AudioPrev
    playerctl previous

# Brillo de pantalla con OSD
XF86MonBrightnessUp
    ~/.local/bin/notify_brightness up
XF86MonBrightnessDown
    ~/.local/bin/notify_brightness down

# ------------------------------------------------------------------------------
# 6. CAPTURAS DE PANTALLA
# ------------------------------------------------------------------------------
# Seleccionar área interactiva
Print
    ~/.local/bin/shot_tool area
# Captura de pantalla completa
shift + Print
    ~/.local/bin/shot_tool full
# Captura de ventana activa
super + Print
    ~/.local/bin/shot_tool window
EOF

    chown "$TARGET_USER:$TARGET_USER" "$SXHKDRC"
    log_success "sxhkdrc configurado exitosamente."
}

configure_polybar() {
    log_info "Configurando Polybar (~/.config/polybar/config.ini)..."
    local POLYBAR_CONF="$CONFIG_DIR/polybar/config.ini"

    cat << 'EOF' > "$POLYBAR_CONF"
; ==============================================================================
; POLYBAR CONFIGURATION - CATPPUCCIN MOCHA (DEFAULT)
; ==============================================================================

[colors]
base       = #1e1e2e
mantle     = #181825
crust      = #11111b
text       = #cdd6f4
subtext0   = #a6adc8
surface0   = #313244
surface1   = #45475a
surface2   = #585b70
blue       = #89b4fa
lavender   = #b4befe
sapphire   = #74c7ec
sky        = #89dceb
teal       = #94e2d5
green      = #a6e3a1
yellow     = #f9e2af
peach      = #fab387
maroon     = #eba0ac
red        = #f38ba8
mauve      = #cba6f7
pink       = #f5c2e7
transparent= #00000000

[bar/main]
monitor = ${env:MONITOR:}
width = 100%
height = 30pt
radius = 0
fixed-center = true

background = ${colors.base}
foreground = ${colors.text}

line-size = 2pt
line-color = ${colors.mauve}

padding-left = 1
padding-right = 1
module-margin = 1

separator = |
separator-foreground = ${colors.surface1}

font-0 = "JetBrainsMono Nerd Font:size=10:weight=bold;3"
font-1 = "Font Awesome 6 Free Solid:size=10;3"
font-2 = "Noto Color Emoji:scale=10;3"

modules-left = bspwm xwindow
modules-center = date
modules-right = spotify cpu memory filesystem pulseaudio network battery sysmenu

cursor-click = pointer
cursor-scroll = ns-resize
enable-ipc = true
wm-restack = bspwm

[module/bspwm]
type = internal/bspwm
pin-workspaces = true
inline-mode = false
enable-click = true
enable-scroll = true

ws-icon-0 = 1;󰈹 1
ws-icon-1 = 2;󰅩 2
ws-icon-2 = 3;󰓇 3
ws-icon-3 = 4;󰨞 4
ws-icon-4 = 5;󰭹 5
ws-icon-5 = 6;󰉋 6
ws-icon-default = 󰍹

label-focused = %icon%
label-focused-background = ${colors.surface0}
label-focused-foreground = ${colors.mauve}
label-focused-underline = ${colors.mauve}
label-focused-padding = 2

label-occupied = %icon%
label-occupied-foreground = ${colors.blue}
label-occupied-padding = 2

label-urgent = %icon%!
label-urgent-background = ${colors.red}
label-urgent-foreground = ${colors.base}
label-urgent-padding = 2

label-empty = %icon%
label-empty-foreground = ${colors.surface2}
label-empty-padding = 2

[module/xwindow]
type = internal/xwindow
label = %title:0:36:...%
label-foreground = ${colors.subtext0}
label-empty = " Arch Linux BSPWM"
label-empty-foreground = ${colors.surface2}

[module/date]
type = internal/date
interval = 1.0
time = %H:%M
date = %A, %d %b
date-alt = %Y-%m-%d %H:%M:%S
label = "󰃰 %date%  󱑂 %time%"
label-foreground = ${colors.mauve}

[module/pulseaudio]
type = internal/pulseaudio
use-ui-max = true
interval = 5
format-volume = <ramp-volume> <label-volume>
format-volume-foreground = ${colors.green}
label-volume = %percentage%%
label-volume-foreground = ${colors.text}
ramp-volume-0 = 
ramp-volume-1 = 
ramp-volume-2 = 
format-muted = <label-muted>
label-muted = "󰝟 Muted"
label-muted-foreground = ${colors.red}
click-right = pavucontrol

[module/network]
type = internal/network
interface-type = wired,wireless
interval = 3.0
format-connected = <label-connected>
format-connected-foreground = ${colors.blue}
label-connected = "󰤨 %essid%"
format-disconnected = <label-disconnected>
label-disconnected = "󰤭 Disconnected"
label-disconnected-foreground = ${colors.surface2}

[module/cpu]
type = internal/cpu
interval = 2
format-prefix = " "
format-prefix-foreground = ${colors.yellow}
label = %percentage:2%%
label-foreground = ${colors.text}

[module/memory]
type = internal/memory
interval = 2
format-prefix = "󰍛 "
format-prefix-foreground = ${colors.pink}
label = %percentage_used:2%%
label-foreground = ${colors.text}

[module/filesystem]
type = internal/fs
interval = 25
mount-0 = /
label-mounted = "󰋊 %percentage_used%%"
label-mounted-foreground = ${colors.teal}

[module/battery]
type = internal/battery
full-at = 99
low-at = 15
battery = BAT0
adapter = AC
poll-interval = 5
format-charging = <animation-charging> <label-charging>
format-discharging = <ramp-capacity> <label-discharging>
format-full = <ramp-capacity> <label-full>
label-charging = %percentage%%
label-discharging = %percentage%%
label-full = 100%
ramp-capacity-0 = 
ramp-capacity-1 = 
ramp-capacity-2 = 
ramp-capacity-3 = 
ramp-capacity-4 = 
ramp-capacity-foreground = ${colors.green}
animation-charging-0 = 
animation-charging-1 = 
animation-charging-2 = 
animation-charging-3 = 
animation-charging-4 = 
animation-charging-framerate = 750
animation-charging-foreground = ${colors.yellow}

[module/sysmenu]
type = custom/text
label = " ⏻ "
label-foreground = ${colors.red}
label-padding = 1
click-left = ~/.local/bin/powermenu_rofi

[module/spotify]
type = custom/script
tail = true
interval = 1
format-prefix = "󰓇 "
format-prefix-foreground = ${colors.mauve}
format = <label>
exec = ~/.local/bin/spotify_status
click-left = playerctl play-pause --player=ncspot,spotify,%any 2>/dev/null || true
click-right = playerctl next --player=ncspot,spotify,%any 2>/dev/null || true
double-click-left = ~/.local/bin/launch_music_player 2>/dev/null || true
EOF

    chown -R "$TARGET_USER:$TARGET_USER" "$CONFIG_DIR/polybar"
    log_success "Polybar configurada correctamente."
}

configure_picom() {
    log_info "Configurando Compositor Picom (~/.config/picom/picom.conf)..."
    local PICOM_CONF="$CONFIG_DIR/picom/picom.conf"

    cat << 'EOF' > "$PICOM_CONF"
# ==============================================================================
# PICOM COMPOSITOR CONFIGURATION - CATPPUCCIN MOCHA
# ==============================================================================

# --- Backend y Rendimiento ---
backend = "xrender";
vsync = true;
mark-wmwin-focused = true;
mark-ovredir-focused = true;
detect-rounded-corners = true;
detect-client-opacity = true;
detect-transient = true;
use-damage = true;

# --- Sombras (Shadows) ---
shadow = true;
shadow-radius = 7;
shadow-offset-x = -7;
shadow-offset-y = -7;
shadow-opacity = 0.5;
shadow-exclude = [
  "name = 'Notification'",
  "class_g = 'Polybar'",
  "class_g ?= 'Notify-osd'",
  "_GTK_FRAME_EXTENTS@:c"
];

# --- Transparencias y Opacidad ---
active-opacity = 1.0;
inactive-opacity = 0.8;
frame-opacity = 1.0;
inactive-opacity-override = false;

opacity-rule = [
  "85:class_g = 'kitty' && focused",
  "75:class_g = 'kitty' && !focused",
  "90:class_g = 'Rofi'",
  "95:class_g = 'Thunar'",
  "100:class_g = 'Brave-browser'",
  "100:class_g = 'feh'"
];

# --- Esquinas Redondeadas (Corner Radius) ---
corner-radius = 10;
rounded-corners-exclude = [
  "window_type = 'dock'",
  "window_type = 'desktop'",
  "class_g = 'Polybar'"
];

# --- Fading (Transiciones suaves) ---
fading = true;
fade-in-step = 0.03;
fade-out-step = 0.03;
fade-delta = 5;

EOF

    chown "$TARGET_USER:$TARGET_USER" "$PICOM_CONF"
    log_success "Picom configurado correctamente."
}

configure_dunst() {
    log_info "Configurando Dunst (~/.config/dunst/dunstrc)..."
    local DUNSTRC="$CONFIG_DIR/dunst/dunstrc"

    cat << 'EOF' > "$DUNSTRC"
# ==============================================================================
# DUNST NOTIFICATION DAEMON - CATPPUCCIN MOCHA
# ==============================================================================

[global]
    monitor = 0
    follow = mouse
    width = 320
    height = 100
    origin = top-right
    offset = 12x42
    scale = 0
    notification_limit = 5

    progress_bar = true
    progress_bar_height = 8
    progress_bar_frame_width = 1
    progress_bar_min_width = 150
    progress_bar_max_width = 300

    indicate_hidden = yes
    transparency = 20
    separator_height = 2
    padding = 12
    horizontal_padding = 14
    text_icon_padding = 12
    frame_width = 2
    gap_size = 8

    # Colores base Catppuccin Mocha
    frame_color = "#89b4fa"
    separator_color = frame
    sort = yes
    idle_threshold = 120

    # Fuentes y formato
    font = JetBrainsMono Nerd Font 11
    line_height = 0
    markup = full
    format = "<b>%s</b>\n%b"
    alignment = left
    show_age_threshold = 60
    ellipsize = middle
    corner_radius = 10

    # Iconos
    icon_position = left
    min_icon_size = 24
    max_icon_size = 48

[urgency_low]
    background = "#1e1e2e"
    foreground = "#cdd6f4"
    frame_color = "#89b4fa"
    timeout = 4

[urgency_normal]
    background = "#1e1e2e"
    foreground = "#cdd6f4"
    frame_color = "#cba6f7"
    timeout = 6

[urgency_critical]
    background = "#1e1e2e"
    foreground = "#f38ba8"
    frame_color = "#f38ba8"
    timeout = 0
EOF

    chown "$TARGET_USER:$TARGET_USER" "$DUNSTRC"
    log_success "Dunst configurado correctamente."
}

configure_kitty() {
    log_info "Configurando Kitty Terminal (~/.config/kitty/kitty.conf)..."
    local KITTY_CONF="$CONFIG_DIR/kitty/kitty.conf"

    cat << 'EOF' > "$KITTY_CONF"
# ==============================================================================
# KITTY CONFIGURATION - CATPPUCCIN MOCHA
# ==============================================================================

# --- Fuente ---
font_family      JetBrainsMono Nerd Font
bold_font        auto
italic_font      auto
bold_italic_font auto
font_size        12.0

# --- Ventana y Padding ---
window_padding_width 10
background_opacity   0.85
hide_window_decorations yes
confirm_os_window_close 0

# --- Scrollback & Mouse ---
scrollback_lines 10000
mouse_hide_wait  3.0

# --- Catppuccin Mocha Color Palette ---
foreground            #cdd6f4
background            #1e1e2e
selection_foreground  #1e1e2e
selection_background  #f5e0dc

# Cursor
cursor                #f5e0dc
cursor_text_color     #1e1e2e

# URL
url_color             #f5e0dc

# Border
active_border_color   #b4befe
inactive_border_color #6c7086
bell_border_color     #f9e2af

# Tab bar
active_tab_foreground   #11111b
active_tab_background   #cba6f7
inactive_tab_foreground #cdd6f4
inactive_tab_background #181825

# 16 Terminal Colors
# black
color0 #45475a
color8 #585b70

# red
color1 #f38ba8
color9 #f38ba8

# green
color2  #a6e3a1
color10 #a6e3a1

# yellow
color3  #f9e2af
color11 #f9e2af

# blue
color4  #89b4fa
color12 #89b4fa

# magenta
color5  #cba6f7
color13 #cba6f7

# cyan
color6  #94e2d5
color14 #94e2d5

# white
color7  #bac2de
color15 #a6adc8
EOF

    chown "$TARGET_USER:$TARGET_USER" "$KITTY_CONF"
    log_success "Kitty configurado con Catppuccin Mocha."
}

configure_rofi() {
    log_info "Configurando Rofi Launcher (~/.config/rofi/config.rasi)..."
    local ROFI_CONF="$CONFIG_DIR/rofi/config.rasi"

    cat << 'EOF' > "$ROFI_CONF"
/* ==============================================================================
 * ROFI THEME - CATPPUCCIN MOCHA
 * ============================================================================== */

configuration {
    modi: "drun,run,window";
    lines: 7;
    font: "JetBrainsMono Nerd Font 11";
    show-icons: true;
    icon-theme: "Tela-circle-dark";
    terminal: "kitty";
    drun-display-format: "{icon} {name}";
    location: 0;
    disable-history: false;
    hide-scrollbar: true;
    display-drun: "   Apps ";
    display-run: "   Run ";
    display-window: "   Windows ";
    sidebar-mode: true;
}

* {
    bg-col:  #1e1e2e;
    bg-col-light: #313244;
    border-col: #cba6f7;
    selected-col: #313244;
    blue: #89b4fa;
    fg-col: #cdd6f4;
    fg-col2: #f38ba8;
    grey: #6c7086;

    width: 580;
    font: "JetBrainsMono Nerd Font 11";
}

element-text, element-icon , mode-switcher {
    background-color: inherit;
    text-color:       inherit;
}

window {
    height: 360px;
    border: 2px;
    border-radius: 12px;
    border-color: @border-col;
    background-color: @bg-col;
}

mainbox {
    background-color: @bg-col;
}

inputbar {
    children: [prompt,entry];
    background-color: @bg-col;
    border-radius: 6px;
    padding: 2px;
}

prompt {
    background-color: @blue;
    padding: 6px;
    text-color: @bg-col;
    border-radius: 6px;
    margin: 10px 0px 0px 10px;
}

textbox-prompt-colon {
    expand: false;
    str: ":";
}

entry {
    padding: 6px;
    margin: 10px 10px 0px 10px;
    text-color: @fg-col;
    background-color: @bg-col-light;
    border-radius: 6px;
}

listview {
    border: 0px 0px 0px;
    padding: 6px 0px 0px;
    margin: 10px 10px 0px 10px;
    columns: 1;
    background-color: @bg-col;
}

element {
    padding: 6px;
    background-color: @bg-col;
    text-color: @fg-col;
    border-radius: 6px;
}

element-icon {
    size: 24px;
    margin: 0 8px 0 0;
}

element selected {
    background-color:  @selected-col ;
    text-color: @fg-col2  ;
}

mode-switcher {
    spacing: 0;
}

button {
    padding: 10px;
    background-color: @bg-col-light;
    text-color: @grey;
    vertical-align: 0.5; 
    horizontal-align: 0.5;
}

button selected {
    background-color: @bg-col;
    text-color: @blue;
}
EOF

    chown "$TARGET_USER:$TARGET_USER" "$ROFI_CONF"
    log_success "Rofi configurado correctamente."
}

configure_gtk() {
    log_info "Configurando temas GTK 3 y GTK 4 (~/.config/gtk-*/settings.ini)..."
    
    local GTK_CONTENT="[Settings]
gtk-theme-name=Catppuccin-Mocha-Standard-Mauve-Dark
gtk-icon-theme-name=Tela-circle-dark
gtk-font-name=JetBrains Mono Nerd Font 11
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=1
gtk-menu-images=1
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-application-prefer-dark-theme=1
"

    echo "$GTK_CONTENT" > "$CONFIG_DIR/gtk-3.0/settings.ini"
    echo "$GTK_CONTENT" > "$CONFIG_DIR/gtk-4.0/settings.ini"
    chown -R "$TARGET_USER:$TARGET_USER" "$CONFIG_DIR/gtk-3.0" "$CONFIG_DIR/gtk-4.0"
    log_success "Configuraciones GTK generadas."
}

configure_xinit_and_xresources() {
    log_info "Configurando ~/.xinitrc y ~/.Xresources..."

    # ~/.xinitrc
    local XINITRC="$TARGET_HOME/.xinitrc"
    cat << 'EOF' > "$XINITRC"
#!/usr/bin/env bash
# ==============================================================================
# XINITRC - INICIAR BSPWM
# ==============================================================================

# Cargar recursos de X11
[ -f ~/.Xresources ] && xrdb -merge -I$HOME ~/.Xresources

# Cargar configuraciones de usuario
if [ -d /etc/X11/xinit/xinitrc.d ] ; then
    for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
        [ -x "$f" ] && . "$f"
    done
    unset f
fi

# Iniciar BSPWM
exec bspwm
EOF
    chown "$TARGET_USER:$TARGET_USER" "$XINITRC"
    chmod +x "$XINITRC"

    # ~/.Xresources (Colores Catppuccin Mocha para terminales X11)
    local XRESOURCES="$TARGET_HOME/.Xresources"
    cat << 'EOF' > "$XRESOURCES"
! Catppuccin Mocha Xresources
*.foreground: #cdd6f4
*.background: #1e1e2e
*.cursorColor: #f5e0dc

! Black
*.color0: #45475a
*.color8: #585b70

! Red
*.color1: #f38ba8
*.color9: #f38ba8

! Green
*.color2: #a6e3a1
*.color10: #a6e3a1

! Yellow
*.color3: #f9e2af
*.color11: #f9e2af

! Blue
*.color4: #89b4fa
*.color12: #89b4fa

! Magenta
*.color5: #cba6f7
*.color13: #cba6f7

! Cyan
*.color6: #94e2d5
*.color14: #94e2d5

! White
*.color7: #bac2de
*.color15: #a6adc8
EOF
    chown "$TARGET_USER:$TARGET_USER" "$XRESOURCES"

    # Aliases útiles en ~/.bashrc
    local BASHRC="$TARGET_HOME/.bashrc"
    if ! grep -q "BSPWM Custom Aliases" "$BASHRC" 2>/dev/null; then
        cat << 'EOF' >> "$BASHRC"

# --- BSPWM Custom Aliases ---
alias ll='ls -la --color=auto'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias update='sudo pacman -Syu'
alias yayupdate='yay -Syu'
alias fast='fastfetch'
alias polyreload='~/.local/bin/launch_polybar'
alias wall='~/.local/bin/random_wallpaper'
EOF
        chown "$TARGET_USER:$TARGET_USER" "$BASHRC"
    fi

    log_success ".xinitrc, .Xresources y .bashrc actualizados."
}

configure_fastfetch() {
    log_info "Configurando Fastfetch (~/.config/fastfetch/config.jsonc)..."
    local FASTFETCH_DIR="$CONFIG_DIR/fastfetch"
    run_as_user mkdir -p "$FASTFETCH_DIR"
    local FASTFETCH_CONF="$FASTFETCH_DIR/config.jsonc"

    cat << 'EOF' > "$FASTFETCH_CONF"
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "type": "none"
  },
  "display": {
    "separator": " ➜  "
  },
  "modules": [
    {
      "type": "custom",
      "format": "\u001b[38;2;203;166;247m  _  _   _   ___   _   ___   _   _ ___   ___  ____  ______        __  __ \n | \\| | /_\\ / __| /_\\ / __| /_\\ | |/ |_ _| | _ )/ ___||  _ \\ \\      / /  \\/  |\n | .` |/ _ \\ (_ |/ _ \\__ \\/ _ \\| ' < | |  | _ \\\\___ \\| |_) \\ \\ /\\ / /| |\\/| |\n |_|\\_/_/ \\_\\___/_/ \\_\\___/_/ \\_\\_|_\\_\\___| |___/|____/|____/  \\_/\\_/  |_|  |_|"
    },
    {
      "type": "custom",
      "format": "\u001b[38;2;148;226;213m         ─── Nagasaki BSPWM Desktop Environment (Catppuccin Mocha) ───\n"
    },
    {
      "type": "title",
      "color": {
        "user": "38;2;203;166;247",
        "at": "38;2;166;173;200",
        "host": "38;2;137;180;250"
      }
    },
    "separator",
    {
      "type": "os",
      "key": "  󰣇 OS      ",
      "keyColor": "38;2;137;180;250"
    },
    {
      "type": "host",
      "key": "  󰌢 HOST    ",
      "keyColor": "38;2;137;180;250"
    },
    {
      "type": "kernel",
      "key": "  󰌽 KERNEL  ",
      "keyColor": "38;2;148;226;213"
    },
    {
      "type": "uptime",
      "key": "  󱑂 UPTIME  ",
      "keyColor": "38;2;166;227;161"
    },
    {
      "type": "packages",
      "key": "  󰏖 PKGS    ",
      "keyColor": "38;2;249;226;175"
    },
    {
      "type": "shell",
      "key": "  󰞷 SHELL   ",
      "keyColor": "38;2;250;179;135"
    },
    {
      "type": "wm",
      "key": "  󰍹 WM      ",
      "keyColor": "38;2;203;166;247"
    },
    {
      "type": "terminal",
      "key": "  󰞍 TERM    ",
      "keyColor": "38;2;245;194;231"
    },
    {
      "type": "memory",
      "key": "  󰍛 MEMORY  ",
      "keyColor": "38;2;137;180;250"
    },
    "break",
    "colors"
  ]
}
EOF
    chown -R "$TARGET_USER:$TARGET_USER" "$FASTFETCH_DIR"
    log_success "Fastfetch configurado con el diseño Nagasaki."
}

configure_neovim() {
    log_info "Configurando Neovim (~/.config/nvim/init.lua)..."
    local NVIM_DIR="$CONFIG_DIR/nvim"
    run_as_user mkdir -p "$NVIM_DIR"
    local NVIM_INIT="$NVIM_DIR/init.lua"

    cat << 'EOF' > "$NVIM_INIT"
-- ==============================================================================
-- NEOVIM CONFIGURATION - NAGASAKI BSPWM (CATPPUCCIN MOCHA)
-- ==============================================================================

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.termguicolors = true
vim.opt.cursorline = true
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 50
vim.opt.clipboard = "unnamedplus"

vim.g.mapleader = " "
local map = vim.keymap.set

map("n", "<leader>w", "<cmd>w<CR>", { desc = "Guardar archivo" })
map("n", "<leader>q", "<cmd>q<CR>", { desc = "Salir" })
map("n", "<leader>h", "<cmd>nohlsearch<CR>", { desc = "Limpiar búsqueda" })

map("n", "<C-h>", "<C-w>h", { desc = "Mover izquierda" })
map("n", "<C-j>", "<C-w>j", { desc = "Mover abajo" })
map("n", "<C-k>", "<C-w>k", { desc = "Mover arriba" })
map("n", "<C-l>", "<C-w>l", { desc = "Mover derecha" })

vim.cmd("syntax on")
vim.cmd("colorscheme default")

vim.cmd([[
  highlight Normal guibg=#1e1e2e guifg=#cdd6f4
  highlight LineNr guifg=#585b70
  highlight CursorLineNr guifg=#cba6f7 gui=bold
  highlight CursorLine guibg=#313244
  highlight StatusLine guibg=#313244 guifg=#cba6f7
  highlight StatusLineNC guibg=#181825 guifg=#6c7086
  highlight VertSplit guifg=#45475a
]])

vim.opt.statusline = " %f %m %= %y | %l:%c "
EOF
    chown -R "$TARGET_USER:$TARGET_USER" "$NVIM_DIR"
    log_success "Neovim configurado con la paleta Nagasaki Catppuccin."
}

configure_shell() {
    log_info "Configurando identidad Nagasaki en Shell (~/.zshrc & ~/.bashrc)..."
    local ZSHRC="$TARGET_HOME/.zshrc"
    local BASHRC="$TARGET_HOME/.bashrc"

    # --- Configuración ZSH ---
    cat << 'EOF' > "$ZSHRC"
# ==============================================================================
# NAGASAKI BSPWM - ZSH CONFIGURATION (Catppuccin Mocha)
# ==============================================================================

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
setopt sharehistory
setopt inc_append_history

autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

PROMPT='%F{#cba6f7}󰣇 %n@nagasaki%f %F{#89b4fa}%~%f %F{#94e2d5}λ%f '

alias nagasaki="~/.local/bin/nagasaki_fetch"
alias fetch="~/.local/bin/nagasaki_fetch"
alias ls="eza --icons --group-directories-first"
alias ll="eza -la --icons --group-directories-first"
alias la="eza -la --icons --group-directories-first"
alias tree="eza --tree --icons"
alias cat="bat"
alias update="sudo pacman -Syu"
alias rice="~/.local/bin/rice_swapper"
alias wifi="~/.local/bin/rofi_wifi_menu"
alias btm="~/.local/bin/rofi_bluetooth"
alias audio="~/.local/bin/rofi_audio_output"
alias mon="~/.local/bin/rofi_monitors"
alias menu="~/.local/bin/rofi_master_menu"

if [[ -x "$HOME/.local/bin/nagasaki_fetch" ]]; then
    "$HOME/.local/bin/nagasaki_fetch"
fi
EOF

    # --- Configuración BASH ---
    cat << 'EOF' > "$BASHRC"
# ==============================================================================
# NAGASAKI BSPWM - BASH CONFIGURATION
# ==============================================================================

PS1='\[\033[38;2;203;166;247m\]󰣇 \u@nagasaki \[\033[38;2;137;180;250m\]\w \[\033[38;2;148;226;213m\]λ \[\033[0m\]'

alias nagasaki="~/.local/bin/nagasaki_fetch"
alias fetch="~/.local/bin/nagasaki_fetch"
alias ls="eza --icons --group-directories-first"
alias ll="eza -la --icons --group-directories-first"
alias la="eza -la --icons --group-directories-first"
alias tree="eza --tree --icons"
alias cat="bat"
alias update="sudo pacman -Syu"
alias rice="~/.local/bin/rice_swapper"
alias wifi="~/.local/bin/rofi_wifi_menu"
alias btm="~/.local/bin/rofi_bluetooth"
alias audio="~/.local/bin/rofi_audio_output"
alias mon="~/.local/bin/rofi_monitors"
alias menu="~/.local/bin/rofi_master_menu"

if [[ $- == *i* ]] && [ -x "$HOME/.local/bin/nagasaki_fetch" ]; then
    "$HOME/.local/bin/nagasaki_fetch"
fi
EOF

    chown "$TARGET_USER:$TARGET_USER" "$ZSHRC" "$BASHRC"
    log_success "Shell ZSH y BASH configurados con la identidad Nagasaki."
}

configure_cava() {
    log_info "Configurando Cava Visualizer (~/.config/cava/config)..."
    local CAVA_DIR="$CONFIG_DIR/cava"
    run_as_user mkdir -p "$CAVA_DIR"
    local CAVA_CONF="$CAVA_DIR/config"

    cat << 'EOF' > "$CAVA_CONF"
# ==============================================================================
# CAVA CONFIGURATION - CATPPUCCIN MOCHA (NAGASAKI BSPWM)
# ==============================================================================

[general]
framerate = 60
sensitivity = 100
bars = 14
bar_width = 2
bar_spacing = 1

[input]
method = pipewire
source = auto

[output]
method = ncurses

[color]
gradient = 1
gradient_count = 6
gradient_color_1 = '#89b4fa'
gradient_color_2 = '#74c7ec'
gradient_color_3 = '#89dceb'
gradient_color_4 = '#94e2d5'
gradient_color_5 = '#a6e3a1'
gradient_color_6 = '#cba6f7'
EOF
    chown -R "$TARGET_USER:$TARGET_USER" "$CAVA_DIR"
    log_success "Cava configurado con gradiente Catppuccin Mocha."
}

# ------------------------------------------------------------------------------
# 5.1 MOTOR MULTI-RICE GLOBAL (8 TEMAS INSPIRADOS EN GH0STZK)
# ------------------------------------------------------------------------------
setup_rices_engine() {
    log_info "5.1 Configurando Motor Multi-Rice Global con 11 diseños de Polybar únicos inspirados en ciudades japonesas..."

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
        "Hiroshima|#ff5555|#ff007f|#cc1a1b26|#c0caf5|Hiroshima Cyber-Sunset Neon Glass Dock"
        "Hakata|#88c0d0|#81a1c1|#c02e3440|#eceff4|Hakata Nord Triple-Island Glass"
        "Matsuyama|#ea698c|#d7827e|#faf4ed|#575279|Matsuyama Light Cream & Coral Red Border"
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

    # 1. TOKYO (gh0stzk Pamela Style - Pills & Rounded Capsules)
    cat << 'EOF' > "$RICES_DIR/Tokyo/polybar.ini"
[colors]
background = #1a1b26
foreground = #c0caf5
primary    = #7aa2f7
secondary  = #bb9af7
alert      = #f7768e
disabled   = #565f89

[bar/main]
monitor = ${env:MONITOR:}
width = 98%
height = 30pt
offset-x = 1%
offset-y = 8pt
radius = 14
fixed-center = true
background = ${colors.background}
foreground = ${colors.foreground}
line-size = 2pt
padding-left = 2
padding-right = 2
module-margin = 1
font-0 = "JetBrainsMono Nerd Font:size=10;3"
font-1 = "Font Awesome 6 Free Solid:size=10;3"

modules-left = launcher bspwm xwindow
modules-center = date
modules-right = spotify filesystem pulseaudio memory cpu battery

[module/launcher]
type = custom/text
content = " 󰣇 Tokyo "
content-foreground = ${colors.primary}
click-left = ~/.local/bin/rofi_master_menu

[module/bspwm]
type = internal/bspwm
pin-workspaces = true
ws-icon-0 = 1;󰈹 1
ws-icon-1 = 2;󰅩 2
ws-icon-2 = 3;󰓇 3
ws-icon-3 = 4;󰨞 4
ws-icon-4 = 5;󰭹 5
ws-icon-5 = 6;󰉋 6
label-focused = " %icon% "
label-focused-background = ${colors.primary}
label-focused-foreground = ${colors.background}
label-focused-padding = 1
label-occupied = " %icon% "
label-occupied-padding = 1
label-empty = " %icon% "
label-empty-foreground = ${colors.disabled}
label-empty-padding = 1

[module/xwindow]
type = internal/xwindow
label = %title:0:25:...%
label-foreground = ${colors.secondary}

[module/date]
type = internal/date
interval = 1
date = 󰥔 %H:%M:%S
date-alt = 󰃭 %Y-%m-%d
label = %date%
label-foreground = ${colors.primary}

[module/filesystem]
type = internal/fs
mount-0 = /
label-mounted = 󰋊 %percentage_used%%
label-mounted-foreground = ${colors.primary}

[module/pulseaudio]
type = internal/pulseaudio
label-volume = 󰕾 %percentage%%
label-volume-foreground = ${colors.secondary}
label-muted = 󰖁 Mute
label-muted-foreground = ${colors.disabled}

[module/memory]
type = internal/memory
label = 󰍛 %percentage_used%%
label-foreground = ${colors.primary}

[module/cpu]
type = internal/cpu
label = 󰻠 %percentage%%
label-foreground = ${colors.secondary}

[module/battery]
type = internal/battery
battery = BAT0
adapter = AC
label-charging = 󰂄 %percentage%%
label-discharging = 󰁹 %percentage%%

[module/spotify]
type = custom/script
tail = true
interval = 1
format-prefix = "󰓇 "
format-prefix-foreground = ${colors.primary}
format = <label>
exec = ~/.local/bin/spotify_status
click-left = playerctl play-pause --player=ncspot,spotify,%any 2>/dev/null || true
click-right = playerctl next --player=ncspot,spotify,%any 2>/dev/null || true
double-click-left = ~/.local/bin/launch_music_player 2>/dev/null || true
EOF

    # 2. OSAKA (gh0stzk Brenda Style - Floating Sunset Dock)
    cat << 'EOF' > "$RICES_DIR/Osaka/polybar.ini"
[colors]
background = #1e1e2e
foreground = #cdd6f4
primary    = #fab387
secondary  = #cba6f7
alert      = #f38ba8
disabled   = #585b70

[bar/main]
monitor = ${env:MONITOR:}
width = 95%
height = 32pt
offset-x = 2.5%
offset-y = 10pt
radius = 16
fixed-center = true
background = ${colors.background}
foreground = ${colors.foreground}
border-size = 2
border-color = ${colors.primary}
padding-left = 3
padding-right = 3
module-margin = 2
font-0 = "JetBrainsMono Nerd Font:size=10;3"

modules-left = launcher bspwm
modules-center = xwindow
modules-right = spotify date pulseaudio memory sysmenu

[module/launcher]
type = custom/text
content = " 🌇 Osaka Dock "
content-foreground = ${colors.primary}
click-left = ~/.local/bin/rofi_master_menu

[module/bspwm]
type = internal/bspwm
pin-workspaces = true
ws-icon-0 = 1;●
ws-icon-1 = 2;●
ws-icon-2 = 3;●
ws-icon-3 = 4;●
ws-icon-4 = 5;●
ws-icon-default = ○
label-focused = " %icon% "
label-focused-foreground = ${colors.primary}
label-occupied = " %icon% "
label-occupied-foreground = ${colors.secondary}
label-empty = " ○ "
label-empty-foreground = ${colors.disabled}

[module/xwindow]
type = internal/xwindow
label = %title:0:30:...%
label-foreground = ${colors.primary}

[module/date]
type = internal/date
interval = 1
date = %H:%M
label = 󰥔 %date%
label-foreground = ${colors.secondary}

[module/pulseaudio]
type = internal/pulseaudio
label-volume = 󰕾 %percentage%%
label-volume-foreground = ${colors.primary}

[module/memory]
type = internal/memory
label = 󰍛 %percentage_used%%
label-foreground = ${colors.secondary}

[module/sysmenu]
type = custom/text
content = " ⚡ "
content-foreground = ${colors.alert}
click-left = ~/.local/bin/powermenu_rofi

[module/spotify]
type = custom/script
tail = true
interval = 1
format-prefix = "󰓇 "
format-prefix-foreground = ${colors.primary}
format = <label>
exec = ~/.local/bin/spotify_status
click-left = playerctl play-pause --player=ncspot,spotify,%any 2>/dev/null || true
click-right = playerctl next --player=ncspot,spotify,%any 2>/dev/null || true
double-click-left = ~/.local/bin/launch_music_player 2>/dev/null || true
EOF

    # 3. KYOTO (gh0stzk Melissa Style - Emerald Mac Island)
    cat << 'EOF' > "$RICES_DIR/Kyoto/polybar.ini"
[colors]
background = #2b3339
foreground = #d3c6aa
primary    = #a7c080
secondary  = #7fbbb3
alert      = #e6969b
disabled   = #4f5b58

[bar/main]
monitor = ${env:MONITOR:}
width = 98%
height = 28pt
offset-x = 1%
offset-y = 6pt
radius = 8
fixed-center = true
background = ${colors.background}
foreground = ${colors.foreground}
border-bottom-size = 2
border-color = ${colors.primary}
padding-left = 2
padding-right = 2
module-margin = 1
font-0 = "JetBrainsMono Nerd Font:size=10;3"

modules-left = launcher bspwm xwindow
modules-center = date
modules-right = spotify filesystem memory cpu pulseaudio

[module/launcher]
type = custom/text
content = " 󰣇 Kyoto "
content-foreground = ${colors.primary}
click-left = ~/.local/bin/rofi_master_menu

[module/bspwm]
type = internal/bspwm
pin-workspaces = true
ws-icon-0 = 1;󰈹
ws-icon-1 = 2;󰅩
ws-icon-2 = 3;󰓇
ws-icon-3 = 4;󰨞
ws-icon-4 = 5;󰭹
ws-icon-default = 󰍹
label-focused = " %icon% "
label-focused-foreground = ${colors.primary}
label-focused-underline = ${colors.primary}
label-occupied = " %icon% "
label-occupied-foreground = ${colors.secondary}
label-empty = " %icon% "
label-empty-foreground = ${colors.disabled}

[module/xwindow]
type = internal/xwindow
label = %title:0:25:...%
label-foreground = ${colors.secondary}

[module/date]
type = internal/date
interval = 1
date = %A, %d %b %H:%M
label = ⛩️ %date%
label-foreground = ${colors.primary}

[module/filesystem]
type = internal/fs
mount-0 = /
label-mounted = 󰋊 %percentage_used%%
label-mounted-foreground = ${colors.secondary}

[module/memory]
type = internal/memory
label = 󰍛 %percentage_used%%
label-foreground = ${colors.primary}

[module/cpu]
type = internal/cpu
label = 󰻠 %percentage%%
label-foreground = ${colors.secondary}

[module/pulseaudio]
type = internal/pulseaudio
label-volume = 󰕾 %percentage%%
label-volume-foreground = ${colors.primary}

[module/spotify]
type = custom/script
tail = true
interval = 1
format-prefix = "󰓇 "
format-prefix-foreground = ${colors.primary}
format = <label>
exec = ~/.local/bin/spotify_status
click-left = playerctl play-pause --player=ncspot,spotify,%any 2>/dev/null || true
click-right = playerctl next --player=ncspot,spotify,%any 2>/dev/null || true
double-click-left = ~/.local/bin/launch_music_player 2>/dev/null || true
EOF

    # 4. YOKOHAMA (Material Blocks - Contrasting Rectangles)
    cat << 'EOF' > "$RICES_DIR/Yokohama/polybar.ini"
[colors]
background = #212121
foreground = #eeffff
primary    = #80deea
secondary  = #ff80ab
alert      = #ff5252
disabled   = #424242

[bar/main]
monitor = ${env:MONITOR:}
width = 100%
height = 30pt
radius = 0
fixed-center = true
background = ${colors.background}
foreground = ${colors.foreground}
padding-left = 1
padding-right = 1
module-margin = 1
font-0 = "JetBrainsMono Nerd Font:size=10:weight=bold;3"

modules-left = launcher bspwm xwindow
modules-center = date
modules-right = spotify memory cpu pulseaudio sysmenu

[module/launcher]
type = custom/text
content = " 🏙️ Yokohama "
content-foreground = ${colors.primary}
click-left = ~/.local/bin/rofi_master_menu

[module/bspwm]
type = internal/bspwm
pin-workspaces = true
ws-icon-0 = 1;󰈹 1
ws-icon-1 = 2;󰅩 2
ws-icon-2 = 3;󰓇 3
ws-icon-3 = 4;󰨞 4
ws-icon-4 = 5;󰭹 5
ws-icon-default = 󰍹
label-focused = "[%icon%]"
label-focused-background = ${colors.primary}
label-focused-foreground = ${colors.background}
label-focused-padding = 1
label-occupied = "[%icon%]"
label-occupied-padding = 1
label-empty = "[%icon%]"
label-empty-foreground = ${colors.disabled}
label-empty-padding = 1

[module/xwindow]
type = internal/xwindow
label = %title:0:30:...%
label-foreground = ${colors.secondary}

[module/date]
type = internal/date
interval = 1
date = %Y-%m-%d %H:%M:%S
label = %date%
label-foreground = ${colors.primary}

[module/memory]
type = internal/memory
label = MEM:%percentage_used%%
label-foreground = ${colors.secondary}

[module/cpu]
type = internal/cpu
label = CPU:%percentage%%
label-foreground = ${colors.primary}

[module/pulseaudio]
type = internal/pulseaudio
label-volume = VOL:%percentage%%
label-volume-foreground = ${colors.secondary}

[module/sysmenu]
type = custom/text
content = " [OFF] "
content-foreground = ${colors.alert}
click-left = ~/.local/bin/powermenu_rofi

[module/spotify]
type = custom/script
tail = true
interval = 1
format-prefix = "󰓇 "
format-prefix-foreground = ${colors.primary}
format = <label>
exec = ~/.local/bin/spotify_status
click-left = playerctl play-pause --player=ncspot,spotify,%any 2>/dev/null || true
click-right = playerctl next --player=ncspot,spotify,%any 2>/dev/null || true
double-click-left = ~/.local/bin/launch_music_player 2>/dev/null || true
EOF

    # 5. NIKKO (Nordish Badges)
    cat << 'EOF' > "$RICES_DIR/Nikko/polybar.ini"
[colors]
background = #2e3440
foreground = #d8dee9
primary    = #88c0d0
secondary  = #81a1c1
alert      = #bf616a
disabled   = #4c566a

[bar/main]
monitor = ${env:MONITOR:}
width = 98%
height = 28pt
offset-x = 1%
offset-y = 6pt
radius = 6
fixed-center = true
background = ${colors.background}
foreground = ${colors.foreground}
padding-left = 2
padding-right = 2
module-margin = 1
font-0 = "JetBrainsMono Nerd Font:size=10;3"

modules-left = launcher bspwm
modules-center = date
modules-right = spotify memory cpu pulseaudio

[module/launcher]
type = custom/text
content = " ❄️ Nikko "
content-foreground = ${colors.primary}
click-left = ~/.local/bin/rofi_master_menu

[module/bspwm]
type = internal/bspwm
pin-workspaces = true
ws-icon-0 = 1;󰈹 1
ws-icon-1 = 2;󰅩 2
ws-icon-2 = 3;󰓇 3
ws-icon-3 = 4;󰨞 4
ws-icon-4 = 5;󰭹 5
ws-icon-default = 󰍹
label-focused = "%icon%"
label-focused-foreground = ${colors.primary}
label-focused-underline = ${colors.primary}
label-focused-padding = 1
label-occupied = "%icon%"
label-occupied-foreground = ${colors.secondary}
label-occupied-padding = 1
label-empty = "%icon%"
label-empty-foreground = ${colors.disabled}
label-empty-padding = 1

[module/date]
type = internal/date
interval = 1
date = %H:%M:%S
label = 󰥔 %date%
label-foreground = ${colors.primary}

[module/memory]
type = internal/memory
label = 󰍛 %percentage_used%%
label-foreground = ${colors.secondary}

[module/cpu]
type = internal/cpu
label = 󰻠 %percentage%%
label-foreground = ${colors.primary}

[module/pulseaudio]
type = internal/pulseaudio
label-volume = 󰕾 %percentage%%
label-volume-foreground = ${colors.secondary}

[module/spotify]
type = custom/script
tail = true
interval = 1
format-prefix = "󰓇 "
format-prefix-foreground = ${colors.primary}
format = <label>
exec = ~/.local/bin/spotify_status
click-left = playerctl play-pause --player=ncspot,spotify,%any 2>/dev/null || true
click-right = playerctl next --player=ncspot,spotify,%any 2>/dev/null || true
double-click-left = ~/.local/bin/launch_music_player 2>/dev/null || true
EOF

    # 6. CATPPUCCIN MOCHA (Default Full-Width)
    cat << 'EOF' > "$RICES_DIR/CatppuccinMocha/polybar.ini"
[colors]
background = #1e1e2e
foreground = #cdd6f4
primary    = #89b4fa
secondary  = #cba6f7
alert      = #f38ba8
disabled   = #585b70

[bar/main]
monitor = ${env:MONITOR:}
width = 100%
height = 30pt
radius = 0
fixed-center = true
background = ${colors.background}
foreground = ${colors.foreground}
padding-left = 2
padding-right = 2
module-margin = 1
font-0 = "JetBrainsMono Nerd Font:size=10;3"

modules-left = launcher bspwm xwindow
modules-center = date
modules-right = spotify filesystem memory cpu pulseaudio battery sysmenu

[module/launcher]
type = custom/text
content = " 󰣇 Catppuccin "
content-foreground = ${colors.primary}
click-left = ~/.local/bin/rofi_master_menu

[module/bspwm]
type = internal/bspwm
pin-workspaces = true
ws-icon-0 = 1;󰈹 1
ws-icon-1 = 2;󰅩 2
ws-icon-2 = 3;󰓇 3
ws-icon-3 = 4;󰨞 4
ws-icon-4 = 5;󰭹 5
ws-icon-5 = 6;󰉋 6
label-focused = %icon%
label-focused-background = #313244
label-focused-foreground = ${colors.secondary}
label-focused-underline = ${colors.secondary}
label-focused-padding = 2
label-occupied = %icon%
label-occupied-padding = 2
label-empty = %icon%
label-empty-foreground = ${colors.disabled}
label-empty-padding = 2

[module/xwindow]
type = internal/xwindow
label = %title:0:30:...%
label-foreground = ${colors.secondary}

[module/date]
type = internal/date
interval = 1
date = %A, %d %b %H:%M:%S
label = %date%
label-foreground = ${colors.primary}

[module/filesystem]
type = internal/fs
mount-0 = /
label-mounted = 󰋊 %percentage_used%%

[module/memory]
type = internal/memory
label = 󰍛 %percentage_used%%

[module/cpu]
type = internal/cpu
label = 󰻠 %percentage%%

[module/pulseaudio]
type = internal/pulseaudio
label-volume = 󰕾 %percentage%%

[module/battery]
type = internal/battery
battery = BAT0
adapter = AC
label-charging = 󰂄 %percentage%%
label-discharging = 󰁹 %percentage%%

[module/sysmenu]
type = custom/text
content = " ⏻ "
content-foreground = ${colors.alert}
click-left = ~/.local/bin/powermenu_rofi

[module/spotify]
type = custom/script
tail = true
interval = 1
format-prefix = "󰓇 "
format-prefix-foreground = ${colors.secondary}
format = <label>
exec = ~/.local/bin/spotify_status
click-left = playerctl play-pause --player=ncspot,spotify,%any 2>/dev/null || true
click-right = playerctl next --player=ncspot,spotify,%any 2>/dev/null || true
double-click-left = ~/.local/bin/launch_music_player 2>/dev/null || true
EOF

    # 7. DRACULA (Dual-Bar Isabel Style Inspired by gh0stzk)
    cat << 'EOF' > "$RICES_DIR/Dracula/polybar.ini"
[colors]
background = #282a36
foreground = #f8f8f2
current    = #44475a
purple     = #bd93f9
pink       = #ff79c6
cyan       = #8be9fd
green      = #50fa7b
yellow     = #f1fa8c
orange     = #ffb86c
red        = #ff5555
comment    = #6272a4

[bar/top]
monitor = ${env:MONITOR:}
width = 98%
height = 26pt
offset-x = 1%
offset-y = 6pt
radius = 8
fixed-center = true
background = ${colors.background}
foreground = ${colors.foreground}
border-size = 1pt
border-color = ${colors.current}
padding-left = 2
padding-right = 2
module-margin = 1
font-0 = "JetBrainsMono Nerd Font:size=9:weight=bold;3"
font-1 = "Font Awesome 6 Free Solid:size=9;3"

modules-left = launcher arch-badge xwindow
modules-center = 
modules-right = cpu-badge memory-badge disk-badge net-badge date-badge

[bar/bottom]
monitor = ${env:MONITOR:}
bottom = true
width = 98%
height = 24pt
offset-x = 1%
offset-y = 6pt
radius = 8
fixed-center = true
background = ${colors.background}
foreground = ${colors.foreground}
border-size = 1pt
border-color = ${colors.current}
padding-left = 2
padding-right = 2
module-margin = 1
font-0 = "JetBrainsMono Nerd Font:size=9:weight=bold;3"
font-1 = "Font Awesome 6 Free Solid:size=9;3"

modules-left = bspwm bspwm-mode
modules-center = spotify
modules-right = volume-badge battery-badge sysmenu

[module/launcher]
type = custom/text
content = " ▲ "
content-foreground = ${colors.purple}
click-left = ~/.local/bin/rofi_master_menu

[module/arch-badge]
type = custom/text
content = " Arch Linux "
content-background = ${colors.current}
content-foreground = ${colors.cyan}
content-padding = 1

[module/xwindow]
type = internal/xwindow
label = " %title:0:30:...% "
label-foreground = ${colors.comment}

[module/cpu-badge]
type = internal/cpu
interval = 2
format = <label>
format-background = ${colors.current}
format-padding = 1
label = " CPU: %percentage:2%% "
label-foreground = ${colors.purple}

[module/memory-badge]
type = internal/memory
interval = 2
format = <label>
format-background = ${colors.current}
format-padding = 1
label = " RAM: %percentage_used:2%% "
label-foreground = ${colors.pink}

[module/disk-badge]
type = internal/fs
mount-0 = /
interval = 10
format-mounted = <label-mounted>
format-mounted-background = ${colors.current}
format-mounted-padding = 1
label-mounted = " DISK: %percentage_used%% "
label-mounted-foreground = ${colors.green}

[module/net-badge]
type = internal/network
interface-type = wired,wireless
interval = 3.0
format-connected = <label-connected>
format-connected-background = ${colors.current}
format-connected-padding = 1
label-connected = " NET: %downspeed% "
label-connected-foreground = ${colors.orange}
format-disconnected = <label-disconnected>
format-disconnected-background = ${colors.current}
format-disconnected-padding = 1
label-disconnected = " NET: Off "
label-disconnected-foreground = ${colors.comment}

[module/date-badge]
type = internal/date
interval = 1.0
time = %H:%M:%S
date = %a %d %b
format = <label>
format-background = ${colors.current}
format-padding = 1
label = " 󱑂 %date% %time% "
label-foreground = ${colors.yellow}

[module/bspwm]
type = internal/bspwm
pin-workspaces = true
ws-icon-0 = 1;TERM
ws-icon-1 = 2;SYS
ws-icon-2 = 3;WWW
ws-icon-3 = 4;CHAT
ws-icon-4 = 5;CODE
ws-icon-5 = 6;MEDIA
ws-icon-default = DESK

label-focused = " %icon% "
label-focused-background = ${colors.purple}
label-focused-foreground = ${colors.background}
label-focused-padding = 1

label-occupied = " %icon% "
label-occupied-foreground = ${colors.pink}
label-occupied-padding = 1

label-empty = " %icon% "
label-empty-foreground = ${colors.comment}
label-empty-padding = 1

[module/bspwm-mode]
type = internal/bspwm
format = <label-mode>
label-monocle = " [Monocle] "
label-monocle-foreground = ${colors.cyan}
label-tiled = " [Tiled] "
label-tiled-foreground = ${colors.green}
label-floating = " [Float] "
label-floating-foreground = ${colors.orange}

[module/spotify]
type = custom/script
tail = true
interval = 1
format-prefix = "󰓇 "
format-prefix-foreground = ${colors.green}
format = <label>
exec = ~/.local/bin/spotify_status
click-left = playerctl play-pause --player=ncspot,spotify,%any 2>/dev/null || true
click-right = playerctl next --player=ncspot,spotify,%any 2>/dev/null || true
double-click-left = ~/.local/bin/launch_music_player 2>/dev/null || true

[module/volume-badge]
type = internal/pulseaudio
format-volume = <label-volume>
format-volume-background = ${colors.current}
format-volume-padding = 1
label-volume = " VOL: %percentage%% "
label-volume-foreground = ${colors.cyan}
format-muted = <label-muted>
format-muted-background = ${colors.current}
format-muted-padding = 1
label-muted = " VOL: Mute "
label-muted-foreground = ${colors.red}

[module/battery-badge]
type = internal/battery
battery = BAT0
adapter = AC
full-at = 99
low-at = 15
format-charging = <label-charging>
format-charging-background = ${colors.current}
format-charging-padding = 1
label-charging = " BAT: %percentage%% 󰂄 "
label-charging-foreground = ${colors.green}
format-discharging = <label-discharging>
format-discharging-background = ${colors.current}
format-discharging-padding = 1
label-discharging = " BAT: %percentage%% 󰁹 "
label-discharging-foreground = ${colors.yellow}
format-full = <label-full>
format-full-background = ${colors.current}
format-full-padding = 1
label-full = " BAT: Full 󰁹 "
label-full-foreground = ${colors.green}

[module/sysmenu]
type = custom/text
content = " ⏻ "
content-foreground = ${colors.red}
click-left = ~/.local/bin/powermenu_rofi
EOF

    # 8. GRUVBOX (Retro Gold Blocks)
    cat << 'EOF' > "$RICES_DIR/Gruvbox/polybar.ini"
[colors]
background = #282828
foreground = #ebdbb2
primary    = #d79921
secondary  = #fe8019
alert      = #fb4934
disabled   = #928374

[bar/main]
monitor = ${env:MONITOR:}
width = 100%
height = 30pt
radius = 0
fixed-center = true
background = ${colors.background}
foreground = ${colors.foreground}
padding-left = 2
padding-right = 2
module-margin = 1
font-0 = "JetBrainsMono Nerd Font:size=10:weight=bold;3"

modules-left = launcher bspwm xwindow
modules-center = date
modules-right = spotify memory cpu pulseaudio sysmenu

[module/launcher]
type = custom/text
content = " 🪵 Gruvbox "
content-foreground = ${colors.primary}
click-left = ~/.local/bin/rofi_master_menu

[module/bspwm]
type = internal/bspwm
pin-workspaces = true
ws-icon-0 = 1;󰈹 1
ws-icon-1 = 2;󰅩 2
ws-icon-2 = 3;󰓇 3
ws-icon-3 = 4;󰨞 4
ws-icon-4 = 5;󰭹 5
ws-icon-default = 󰍹
label-focused = "<%icon%>"
label-focused-background = ${colors.primary}
label-focused-foreground = ${colors.background}
label-focused-padding = 1
label-occupied = "<%icon%>"
label-occupied-foreground = ${colors.secondary}
label-occupied-padding = 1
label-empty = "<%icon%>"
label-empty-foreground = ${colors.disabled}
label-empty-padding = 1

[module/xwindow]
type = internal/xwindow
label = %title:0:25:...%
label-foreground = ${colors.secondary}

[module/date]
type = internal/date
interval = 1
date = %H:%M:%S
label = %date%
label-foreground = ${colors.primary}

[module/memory]
type = internal/memory
label = MEM:%percentage_used%%
label-foreground = ${colors.secondary}

[module/cpu]
type = internal/cpu
label = CPU:%percentage%%
label-foreground = ${colors.primary}

[module/pulseaudio]
type = internal/pulseaudio
label-volume = VOL:%percentage%%
label-volume-foreground = ${colors.secondary}

[module/sysmenu]
type = custom/text
content = " [OFF] "
content-foreground = ${colors.alert}
click-left = ~/.local/bin/powermenu_rofi

[module/spotify]
type = custom/script
tail = true
interval = 1
format-prefix = "󰓇 "
format-prefix-foreground = ${colors.primary}
format = <label>
exec = ~/.local/bin/spotify_status
click-left = playerctl play-pause --player=ncspot,spotify,%any 2>/dev/null || true
click-right = playerctl next --player=ncspot,spotify,%any 2>/dev/null || true
double-click-left = ~/.local/bin/launch_music_player 2>/dev/null || true
EOF

    # 9. HIROSHIMA (Cyber-Sunset Neon Glass Dock Islands)
    cat << 'EOF' > "$RICES_DIR/Hiroshima/polybar.ini"
[colors]
background = #cc1a1b26
foreground = #c0caf5
primary    = #ff5555
secondary  = #ff007f
cyan       = #00f0ff
alert      = #ff0055
disabled   = #565f89

[bar/left]
monitor = ${env:MONITOR:}
width = 28%
height = 30pt
offset-x = 1.5%
offset-y = 8pt
radius = 12
fixed-center = true
background = ${colors.background}
foreground = ${colors.foreground}
border-size = 2
border-color = ${colors.secondary}
padding-left = 2
padding-right = 2
module-margin = 1
font-0 = "JetBrainsMono Nerd Font:size=10:weight=bold;3"
modules-left = launcher bspwm xwindow
enable-ipc = true
wm-restack = bspwm

[bar/center]
monitor = ${env:MONITOR:}
width = 22%
height = 30pt
offset-x = 39%
offset-y = 8pt
radius = 12
fixed-center = true
background = ${colors.background}
foreground = ${colors.foreground}
border-size = 2
border-color = ${colors.primary}
font-0 = "JetBrainsMono Nerd Font:size=10:weight=bold;3"
modules-center = date
enable-ipc = true
wm-restack = bspwm

[bar/right]
monitor = ${env:MONITOR:}
width = 35%
height = 30pt
offset-x = 63.5%
offset-y = 8pt
radius = 12
fixed-center = true
background = ${colors.background}
foreground = ${colors.foreground}
border-size = 2
border-color = ${colors.cyan}
padding-left = 2
padding-right = 2
module-margin = 1
font-0 = "JetBrainsMono Nerd Font:size=10:weight=bold;3"
modules-right = spotify cpu memory pulseaudio battery sysmenu
enable-ipc = true
wm-restack = bspwm

[module/launcher]
type = custom/text
content = " 🔴 Hiroshima "
content-foreground = ${colors.primary}
click-left = ~/.local/bin/rofi_master_menu

[module/bspwm]
type = internal/bspwm
pin-workspaces = true
ws-icon-0 = 1;󰈹
ws-icon-1 = 2;󰅩
ws-icon-2 = 3;󰓇
ws-icon-3 = 4;󰨞
ws-icon-4 = 5;󰭹
ws-icon-default = 󰍹
label-focused = " %icon% "
label-focused-background = ${colors.secondary}
label-focused-foreground = #ffffff
label-focused-padding = 1
label-occupied = " %icon% "
label-occupied-foreground = ${colors.cyan}
label-occupied-padding = 1
label-empty = " %icon% "
label-empty-foreground = ${colors.disabled}
label-empty-padding = 1

[module/xwindow]
type = internal/xwindow
label = %title:0:22:...%
label-foreground = ${colors.cyan}

[module/date]
type = internal/date
interval = 1
date = %H:%M:%S
date-alt = %A, %d %b %Y
label = "󰥔 %date%"
label-foreground = ${colors.primary}

[module/cpu]
type = internal/cpu
label = "󰻠 %percentage%%"
label-foreground = ${colors.cyan}

[module/memory]
type = internal/memory
label = "󰍛 %percentage_used%%"
label-foreground = ${colors.secondary}

[module/pulseaudio]
type = internal/pulseaudio
label-volume = "󰕾 %percentage%%"
label-volume-foreground = ${colors.primary}
label-muted = "󰖁 Mute"
label-muted-foreground = ${colors.disabled}

[module/battery]
type = internal/battery
battery = BAT0
adapter = AC
label-charging = "󰂄 %percentage%%"
label-discharging = "󰁹 %percentage%%"
label-charging-foreground = ${colors.cyan}
label-discharging-foreground = ${colors.primary}

[module/sysmenu]
type = custom/text
content = " ⏻ "
content-foreground = ${colors.alert}
click-left = ~/.local/bin/powermenu_rofi

[module/spotify]
type = custom/script
tail = true
interval = 1
format-prefix = "󰓇 "
format-prefix-foreground = ${colors.secondary}
format = <label>
exec = ~/.local/bin/spotify_status
click-left = playerctl play-pause --player=ncspot,spotify,%any 2>/dev/null || true
click-right = playerctl next --player=ncspot,spotify,%any 2>/dev/null || true
double-click-left = ~/.local/bin/launch_music_player 2>/dev/null || true
EOF

    # 10. HAKATA (Nord Triple-Island Glass)
    cat << 'EOF' > "$RICES_DIR/Hakata/polybar.ini"
[colors]
background = #d02e3440
foreground = #eceff4
primary    = #88c0d0
secondary  = #81a1c1
green      = #a3be8c
yellow     = #ebcb8b
alert      = #bf616a
disabled   = #4c566a

[bar/left]
monitor = ${env:MONITOR:}
width = 28%
height = 28pt
offset-x = 1.5%
offset-y = 6pt
radius = 14
fixed-center = true
background = ${colors.background}
foreground = ${colors.foreground}
border-size = 1
border-color = ${colors.primary}
padding-left = 2
padding-right = 2
module-margin = 1
font-0 = "JetBrainsMono Nerd Font:size=9:weight=bold;3"
modules-left = launcher bspwm xwindow
enable-ipc = true
wm-restack = bspwm

[bar/center]
monitor = ${env:MONITOR:}
width = 22%
height = 28pt
offset-x = 39%
offset-y = 6pt
radius = 14
fixed-center = true
background = ${colors.background}
foreground = ${colors.foreground}
border-size = 1
border-color = ${colors.primary}
font-0 = "JetBrainsMono Nerd Font:size=9:weight=bold;3"
modules-center = date
enable-ipc = true
wm-restack = bspwm

[bar/right]
monitor = ${env:MONITOR:}
width = 35%
height = 28pt
offset-x = 63.5%
offset-y = 6pt
radius = 14
fixed-center = true
background = ${colors.background}
foreground = ${colors.foreground}
border-size = 1
border-color = ${colors.primary}
padding-left = 2
padding-right = 2
module-margin = 1
font-0 = "JetBrainsMono Nerd Font:size=9:weight=bold;3"
modules-right = spotify cpu-pill memory-pill volume-pill battery-pill sysmenu
enable-ipc = true
wm-restack = bspwm

[module/launcher]
type = custom/text
content = " 🌊 Hakata "
content-foreground = ${colors.primary}
click-left = ~/.local/bin/rofi_master_menu

[module/bspwm]
type = internal/bspwm
pin-workspaces = true
ws-icon-0 = 1;󰈹 1
ws-icon-1 = 2;󰅩 2
ws-icon-2 = 3;󰓇 3
ws-icon-3 = 4;󰨞 4
ws-icon-4 = 5;󰭹 5
ws-icon-default = 󰍹
label-focused = " %icon% "
label-focused-background = ${colors.secondary}
label-focused-foreground = #2e3440
label-occupied = " %icon% "
label-occupied-foreground = ${colors.primary}
label-empty = " %icon% "
label-empty-foreground = ${colors.disabled}

[module/xwindow]
type = internal/xwindow
label = " %title:0:22:...% "
label-foreground = ${colors.primary}

[module/date]
type = internal/date
interval = 1.0
time = %H:%M
date = %A %d %b
label = "󰥔 %date% - %time%"
label-foreground = ${colors.yellow}

[module/cpu-pill]
type = internal/cpu
interval = 2
label = "󰻠 %percentage%%"
label-foreground = ${colors.primary}

[module/memory-pill]
type = internal/memory
interval = 2
label = "󰍛 %percentage_used%%"
label-foreground = ${colors.secondary}

[module/volume-pill]
type = internal/pulseaudio
label-volume = "󰕾 %percentage%%"
label-volume-foreground = ${colors.green}
label-muted = "󰝟 Mute"
label-muted-foreground = ${colors.alert}

[module/battery-pill]
type = internal/battery
battery = BAT0
adapter = AC
label-charging = "󰂄 %percentage%%"
label-discharging = "󰁹 %percentage%%"
label-charging-foreground = ${colors.green}
label-discharging-foreground = ${colors.yellow}

[module/sysmenu]
type = custom/text
content = " ⏻ "
content-foreground = ${colors.alert}
click-left = ~/.local/bin/powermenu_rofi

[module/spotify]
type = custom/script
tail = true
interval = 1
format-prefix = "󰓇 "
format-prefix-foreground = ${colors.primary}
format = <label>
exec = ~/.local/bin/spotify_status
click-left = playerctl play-pause --player=ncspot,spotify,%any 2>/dev/null || true
click-right = playerctl next --player=ncspot,spotify,%any 2>/dev/null || true
double-click-left = ~/.local/bin/launch_music_player 2>/dev/null || true
EOF

    # 11. MATSUYAMA (Light Cream & Coral Red Border)
    cat << 'EOF' > "$RICES_DIR/Matsuyama/polybar.ini"
[colors]
background = #faf4ed
foreground = #575279
primary    = #ea698c
secondary  = #d7827e
border-col = #ea698c
focused-bg = #e8e0d5
alert      = #d20f39
disabled   = #b5b0a8

[bar/main]
monitor = ${env:MONITOR:}
width = 98%
height = 26pt
offset-x = 1%
offset-y = 6pt
radius = 8
fixed-center = true

background = ${colors.background}
foreground = ${colors.foreground}

line-size = 2pt
line-color = ${colors.primary}

border-size = 1pt
border-color = ${colors.border-col}

padding-left = 1
padding-right = 1
module-margin = 1

separator = |
separator-foreground = ${colors.border-col}

font-0 = "JetBrainsMono Nerd Font:size=10:weight=bold;3"
font-1 = "Font Awesome 6 Free Solid:size=10;3"

modules-left = bspwm xwindow
modules-center = 
modules-right = spotify pulseaudio memory cpu battery network date sysmenu

cursor-click = pointer
cursor-scroll = ns-resize
enable-ipc = true
wm-restack = bspwm

[module/bspwm]
type = internal/bspwm
pin-workspaces = true
ws-icon-0 = 1;󰈹 1
ws-icon-1 = 2;󰅩 2
ws-icon-2 = 3;󰓇 3
ws-icon-3 = 4;󰨞 4
ws-icon-4 = 5;󰭹 5
ws-icon-default = 󰍹

label-focused = " %icon% "
label-focused-background = ${colors.focused-bg}
label-focused-foreground = #282828
label-focused-underline = ${colors.primary}
label-focused-padding = 1

label-occupied = " %icon% "
label-occupied-foreground = ${colors.foreground}
label-occupied-padding = 1

label-urgent = " %icon%! "
label-urgent-background = ${colors.alert}
label-urgent-foreground = ${colors.background}
label-urgent-padding = 1

label-empty = " %icon% "
label-empty-foreground = ${colors.disabled}
label-empty-padding = 1

[module/xwindow]
type = internal/xwindow
label = " %title:0:30:...% "
label-foreground = ${colors.secondary}

[module/pulseaudio]
type = internal/pulseaudio
format-volume = <label-volume>
label-volume = " %percentage%% 󰕾 "
label-volume-foreground = ${colors.foreground}
format-muted = <label-muted>
label-muted = " muted 󰝟 "
label-muted-foreground = ${colors.alert}

[module/network]
type = internal/network
interface-type = wired,wireless
interval = 3.0
format-connected = <label-connected>
label-connected = " 󰤨 %essid% "
label-connected-foreground = ${colors.foreground}
format-disconnected = <label-disconnected>
label-disconnected = " 󰤭 Disconnected "
label-disconnected-foreground = ${colors.disabled}

[module/cpu]
type = internal/cpu
interval = 2
label = " CPU 󰻠 %percentage:2%% "
label-foreground = ${colors.foreground}

[module/memory]
type = internal/memory
interval = 2
label = " RAM 󰍛 %percentage_used:2%% "
label-foreground = ${colors.foreground}

[module/battery]
type = internal/battery
full-at = 99
low-at = 15
battery = BAT0
adapter = AC
poll-interval = 5
format-charging = <label-charging>
label-charging = " %percentage%% 󰂄 "
format-discharging = <label-discharging>
label-discharging = " %percentage%% 󰁹 "
format-full = <label-full>
label-full = " Full 󰁹 "
label-charging-foreground = ${colors.foreground}
label-discharging-foreground = ${colors.foreground}
label-full-foreground = ${colors.foreground}

[module/date]
type = internal/date
interval = 1.0
time = %H:%M
date = %A, %d %b
label = " 󱑂 %time% "
label-foreground = ${colors.foreground}

[module/sysmenu]
type = custom/text
label = " ⏻ "
label-foreground = ${colors.primary}
click-left = ~/.local/bin/powermenu_rofi

[module/spotify]
type = custom/script
tail = true
interval = 1
format-prefix = "󰓇 "
format-prefix-foreground = ${colors.primary}
format = <label>
exec = ~/.local/bin/spotify_status
click-left = playerctl play-pause --player=ncspot,spotify,%any 2>/dev/null || true
click-right = playerctl next --player=ncspot,spotify,%any 2>/dev/null || true
double-click-left = ~/.local/bin/launch_music_player 2>/dev/null || true
EOF

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
    log_success "Motor Multi-Rice global de 11 temas con barras Polybar 100% independientes configurado en $RICES_DIR."
}

# ------------------------------------------------------------------------------
# 5.2 SCRIPTS DE PRODUCTIVIDAD AVANZADOS
# ------------------------------------------------------------------------------
setup_productivity_scripts() {
    log_info "5.2 Creando scripts de productividad avanzados..."

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
# 6. SCRIPTS PERSONALIZADOS EN ~/.local/bin/
# ------------------------------------------------------------------------------
setup_custom_scripts() {
    log_info "6. Creando scripts de utilidad en $BIN_DIR..."
    run_as_user mkdir -p "$BIN_DIR"

    # Script: launch_polybar (Detecta monitores y lanza el estilo activo del Rice)
    local LAUNCH_POLY="$BIN_DIR/launch_polybar"
    cat << 'EOF' > "$LAUNCH_POLY"
#!/usr/bin/env bash
killall -q polybar
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.1; done

CURRENT_THEME="$HOME/.config/polybar/config.ini"

if [ -f "$HOME/.config/bspwm/current_rice" ]; then
    RICE="$(cat "$HOME/.config/bspwm/current_rice")"
    if [ -f "$HOME/.config/bspwm/rices/$RICE/polybar.ini" ]; then
        CURRENT_THEME="$HOME/.config/bspwm/rices/$RICE/polybar.ini"
    fi
elif [ -f "$HOME/.config/polybar/current_style" ]; then
    SAVED_THEME="$(cat "$HOME/.config/polybar/current_style")"
    [ -f "$SAVED_THEME" ] && CURRENT_THEME="$SAVED_THEME"
fi

BARS=$(grep -Po '^\[bar/\K[^\]]+' "$CURRENT_THEME" 2>/dev/null)
[ -z "$BARS" ] && BARS="main"

if type "xrandr" > /dev/null 2>&1; then
    for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
        for b in $BARS; do
            MONITOR=$m polybar --reload "$b" -c "$CURRENT_THEME" &
        done
    done
else
    for b in $BARS; do
        polybar --reload "$b" -c "$CURRENT_THEME" &
    done
fi
EOF

    # Script: random_wallpaper (Aplica un fondo aleatorio con feh)
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

    # Script: polybar_theme_selector (Selector interactivo Rofi para los 11 Rices y sus barras)
    local THEME_SELECT="$BIN_DIR/polybar_theme_selector"
    cat << 'EOF' > "$THEME_SELECT"
#!/usr/bin/env bash
MENU_OPTIONS="1. 🌸 Tokyo Pills (gh0stzk Pamela style)\n2. 🌇 Osaka Sunset Dock (gh0stzk Brenda style)\n3. ⛩️ Kyoto Emerald Mac (gh0stzk Melissa style)\n4. 🏙️ Yokohama Material Blocks\n5. ❄️ Nikko Nordish Badges\n6. ☕ Catppuccin Mocha Default\n7. 🧛 Dracula Dark Violet\n8. 🪵 Gruvbox Retro Gold\n9. 🔴 Hiroshima Neon Glass Dock\n10. 🌊 Hakata Nord Triple Island\n11. 🍁 Matsuyama Autumn Gold Glass\n12. 🔄 Recargar Barra Actual\n13. ✏️ Abrir Rice Editor"

CHOSEN=$(echo -e "$MENU_OPTIONS" | rofi -dmenu -i -p "Estilo Polybar & Rice:" -theme ~/.config/rofi/config.rasi)

case "$CHOSEN" in
    "1."*) ~/.local/bin/rice_swapper "Tokyo" ;;
    "2."*) ~/.local/bin/rice_swapper "Osaka" ;;
    "3."*) ~/.local/bin/rice_swapper "Kyoto" ;;
    "4."*) ~/.local/bin/rice_swapper "Yokohama" ;;
    "5."*) ~/.local/bin/rice_swapper "Nikko" ;;
    "6."*) ~/.local/bin/rice_swapper "CatppuccinMocha" ;;
    "7."*) ~/.local/bin/rice_swapper "Dracula" ;;
    "8."*) ~/.local/bin/rice_swapper "Gruvbox" ;;
    "9."*) ~/.local/bin/rice_swapper "Hiroshima" ;;
    "10."*) ~/.local/bin/rice_swapper "Hakata" ;;
    "11."*) ~/.local/bin/rice_swapper "Matsuyama" ;;
    "12."*) ~/.local/bin/launch_polybar; notify-send "Polybar" "Polybar recargada exitosamente" ;;
    "13."*) ~/.local/bin/rice_editor ;;
esac
EOF

    # Script CLI: polytheme (Cambio rápido por terminal estilo repo)
    local POLYTHEME_CLI="$BIN_DIR/polytheme"
    cat << 'EOF' > "$POLYTHEME_CLI"
#!/usr/bin/env bash
# CLI Selector para Polybar Themes / Rices
show_help() {
    echo "Uso: polytheme [opción]"
    echo "Opciones disponibles:"
    echo "  -1 : Tokyo (Pamela Style)"
    echo "  -2 : Osaka (Brenda Sunset Dock)"
    echo "  -3 : Kyoto (Melissa Emerald Mac)"
    echo "  -4 : Yokohama (Material Blocks)"
    echo "  -5 : Nikko (Nordish Badges)"
    echo "  -6 : Catppuccin Mocha Default"
    echo "  -7 : Dracula (Dark Violet)"
    echo "  -8 : Gruvbox (Retro Gold)"
    echo "  -9 : Hiroshima (Neon Glass Dock)"
    echo "  -10: Hakata (Nord Triple Island)"
    echo "  -11: Matsuyama (Autumn Gold Glass)"
    echo "  -r : Recargar barra actual"
    echo "  -h : Mostrar esta ayuda"
}

case "$1" in
    -1|1) ~/.local/bin/rice_swapper "Tokyo" ;;
    -2|2) ~/.local/bin/rice_swapper "Osaka" ;;
    -3|3) ~/.local/bin/rice_swapper "Kyoto" ;;
    -4|4) ~/.local/bin/rice_swapper "Yokohama" ;;
    -5|5) ~/.local/bin/rice_swapper "Nikko" ;;
    -6|6) ~/.local/bin/rice_swapper "CatppuccinMocha" ;;
    -7|7) ~/.local/bin/rice_swapper "Dracula" ;;
    -8|8) ~/.local/bin/rice_swapper "Gruvbox" ;;
    -9|9) ~/.local/bin/rice_swapper "Hiroshima" ;;
    -10|10) ~/.local/bin/rice_swapper "Hakata" ;;
    -11|11) ~/.local/bin/rice_swapper "Matsuyama" ;;
    -r|r)
        ~/.local/bin/launch_polybar
        echo "✓ Polybar recargada"
        ;;
    -h|h|--help)
        show_help
        ;;
    *)
        ~/.local/bin/polybar_theme_selector
        ;;
esac
EOF

    # Script: powermenu_rofi
    local POWERMENU="$BIN_DIR/powermenu_rofi"
    cat << 'EOF' > "$POWERMENU"
#!/usr/bin/env bash
OPTIONS="⏻ Apagar\n🔄 Reiniciar\n🚪 Cerrar Sesión\n🔒 Bloquear"
CHOSEN=$(echo -e "$OPTIONS" | rofi -dmenu -i -p "Sistema:" -theme ~/.config/rofi/config.rasi)

case "$CHOSEN" in
    *Apagar*)
        systemctl poweroff
        ;;
    *Reiniciar*)
        systemctl reboot
        ;;
    *Cerrar*)
        bspc quit
        ;;
    *Bloquear*)
        ~/.local/bin/blur_lockscreen
        ;;
esac
EOF

    # Script: rofi_wifi_menu (Gestor gráfico Wi-Fi con nmcli)
    local WIFI_MENU="$BIN_DIR/rofi_wifi_menu"
    cat << 'EOF' > "$WIFI_MENU"
#!/usr/bin/env bash
notify() {
    notify-send -u normal -i network-wireless "Wi-Fi" "$1"
}

WIFI_STATE=$(nmcli -fields WIFI g 2>/dev/null || echo "enabled")

if [[ "$WIFI_STATE" =~ "disabled" ]]; then
    TOGGLE="󰤮 Encender Wi-Fi"
    CHOSEN=$(echo -e "$TOGGLE" | rofi -dmenu -i -p "Wi-Fi Desactivado:" -theme ~/.config/rofi/config.rasi)
    if [ "$CHOSEN" = "$TOGGLE" ]; then
        nmcli radio wifi on
        notify "Wi-Fi activado"
    fi
    exit 0
fi

TOGGLE="󰤭 Apagar Wi-Fi\n🔄 Rescanear Redes"
CURRENT_SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)

WIFI_LIST=$(nmcli --fields "SECURITY,SSID,SIGNAL,BARS" dev wifi list 2>/dev/null | sed 1d | awk -F'  +' '{ if ($2 != "--" && $2 != "") printf "%-4s %-24s (%s%%) %s\n", ($1 ~ /WPA|WEP/ ? "🔒" : "🔓"), $2, $3, $4 }' | sort -u)

if [ -n "$CURRENT_SSID" ]; then
    HEADER="✔ Conectado a: $CURRENT_SSID\n🔌 Desconectar ($CURRENT_SSID)\n$TOGGLE"
else
    HEADER="$TOGGLE"
fi

CHOSEN=$(echo -e "$HEADER\n$WIFI_LIST" | rofi -dmenu -i -p "Redes Wi-Fi:" -theme ~/.config/rofi/config.rasi)

[ -z "$CHOSEN" ] && exit 0

case "$CHOSEN" in
    *"Apagar Wi-Fi"*)
        nmcli radio wifi off
        notify "Wi-Fi apagado"
        ;;
    *"Rescanear Redes"*)
        nmcli dev wifi rescan
        notify "Escaneo de redes completado"
        ~/.local/bin/rofi_wifi_menu
        ;;
    *"Desconectar"*)
        WIFI_IFACE=$(nmcli -t -f DEVICE,TYPE dev | grep ':wifi$' | cut -d: -f1 | head -1)
        [ -n "$WIFI_IFACE" ] && nmcli dev disconnect iface "$WIFI_IFACE"
        notify "Desconectado de $CURRENT_SSID"
        ;;
    *"✔ Conectado"*)
        ;;
    *)
        SSID=$(echo "$CHOSEN" | awk '{print $2}')
        [ -z "$SSID" ] && exit 0

        if nmcli connection show "$SSID" &>/dev/null; then
            notify "Conectando a '$SSID'..."
            if nmcli connection up "$SSID"; then
                notify "Conectado exitosamente a '$SSID'"
            else
                notify "Error al conectar a '$SSID'"
            fi
        else
            if echo "$CHOSEN" | grep -q "🔒"; then
                PASS=$(rofi -dmenu -p "Contraseña para $SSID:" -password -theme ~/.config/rofi/config.rasi)
                [ -z "$PASS" ] && exit 0
                notify "Conectando a '$SSID'..."
                if nmcli dev wifi connect "$SSID" password "$PASS"; then
                    notify "Conectado exitosamente a '$SSID'"
                else
                    notify "Error: Contraseña incorrecta o fallo con '$SSID'"
                fi
            else
                notify "Conectando a red abierta '$SSID'..."
                if nmcli dev wifi connect "$SSID"; then
                    notify "Conectado exitosamente a '$SSID'"
                else
                    notify "Error al conectar a '$SSID'"
                fi
            fi
        fi
        ;;
esac
EOF

    # Script: rofi_bluetooth (Gestor gráfico Bluetooth con bluetoothctl)
    local BT_MENU="$BIN_DIR/rofi_bluetooth"
    cat << 'EOF' > "$BT_MENU"
#!/usr/bin/env bash
notify() {
    notify-send -u normal -i bluetooth "Bluetooth" "$1"
}

if ! command -v bluetoothctl &>/dev/null; then
    notify "bluetoothctl no está instalado."
    exit 1
fi

POWER_STATUS=$(bluetoothctl show | grep "Powered: yes")

if [ -z "$POWER_STATUS" ]; then
    OPTIONS="⚡ Encender Bluetooth"
    CHOSEN=$(echo -e "$OPTIONS" | rofi -dmenu -i -p "Bluetooth:" -theme ~/.config/rofi/config.rasi)
    if [ "$CHOSEN" = "⚡ Encender Bluetooth" ]; then
        bluetoothctl power on
        notify "Bluetooth Encendido"
    fi
    exit 0
fi

OPTIONS="🚫 Apagar Bluetooth\n🔄 Escanear Dispositivos\n📋 Dispositivos Emparejados"
CHOSEN=$(echo -e "$OPTIONS" | rofi -dmenu -i -p "Bluetooth:" -theme ~/.config/rofi/config.rasi)

case "$CHOSEN" in
    *"Apagar"*)
        bluetoothctl power off
        notify "Bluetooth Apagado"
        ;;
    *"Escanear"*)
        notify "Escaneando dispositivos (5s)..."
        bluetoothctl --timeout 5 scan on >/dev/null 2>&1
        DEVICES=$(bluetoothctl devices | awk '{ $1=""; print substr($0,2) }')
        if [ -z "$DEVICES" ]; then
            notify "No se detectaron dispositivos nuevos."
            exit 0
        fi
        CHOSEN_DEV=$(echo -e "$DEVICES" | rofi -dmenu -i -p "Dispositivos Cercanos:" -theme ~/.config/rofi/config.rasi)
        [ -z "$CHOSEN_DEV" ] && exit 0
        MAC=$(bluetoothctl devices | grep "$CHOSEN_DEV" | awk '{print $2}' | head -1)
        if [ -n "$MAC" ]; then
            notify "Emparejando con $CHOSEN_DEV..."
            bluetoothctl pair "$MAC"
            bluetoothctl trust "$MAC"
            bluetoothctl connect "$MAC"
            notify "Conectado a $CHOSEN_DEV"
        fi
        ;;
    *"Emparejados"*)
        PAIRED=$(bluetoothctl paired-devices | awk '{ $1=""; print substr($0,2) }')
        if [ -z "$PAIRED" ]; then
            notify "No tienes dispositivos emparejados."
            exit 0
        fi
        CHOSEN_DEV=$(echo -e "$PAIRED" | rofi -dmenu -i -p "Dispositivos Emparejados:" -theme ~/.config/rofi/config.rasi)
        [ -z "$CHOSEN_DEV" ] && exit 0
        MAC=$(bluetoothctl paired-devices | grep "$CHOSEN_DEV" | awk '{print $2}' | head -1)
        if [ -n "$MAC" ]; then
            ACTION=$(echo -e "🔌 Conectar\n❌ Desconectar\n🗑️ Desemparejar (Olvidar)" | rofi -dmenu -i -p "$CHOSEN_DEV:" -theme ~/.config/rofi/config.rasi)
            case "$ACTION" in
                *"Conectar"*)
                    bluetoothctl connect "$MAC"
                    notify "Conectado a $CHOSEN_DEV"
                    ;;
                *"Desconectar"*)
                    bluetoothctl disconnect "$MAC"
                    notify "Desconectado de $CHOSEN_DEV"
                    ;;
                *"Desemparejar"*)
                    bluetoothctl remove "$MAC"
                    notify "Dispositivo olvidado: $CHOSEN_DEV"
                    ;;
            esac
        fi
        ;;
esac
EOF

    # Script: rofi_audio_output (Selector interactivo de salida de audio)
    local AUDIO_MENU="$BIN_DIR/rofi_audio_output"
    cat << 'EOF' > "$AUDIO_MENU"
#!/usr/bin/env bash
DEFAULT_SINK=$(pactl get-default-sink 2>/dev/null || true)
SINKS=$(pactl list sinks 2>/dev/null)

if [ -z "$SINKS" ]; then
    notify-send "Audio" "No se detectaron salidas de audio disponibles."
    exit 1
fi

SINK_NAMES=()
SINK_RAW=()

while IFS= read -r line; do
    if [[ "$line" =~ ^Sink\ #[0-9]+ ]]; then
        sink_name=""
        sink_desc=""
    elif [[ "$line" =~ Name:\ (.*) ]]; then
        sink_name="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ Description:\ (.*) ]]; then
        sink_desc="${BASH_REMATCH[1]}"
        if [ -n "$sink_name" ] && [ -n "$sink_desc" ]; then
            PREFIX="  "
            [ "$sink_name" = "$DEFAULT_SINK" ] && PREFIX="✔ "
            SINK_NAMES+=("${PREFIX}🔊 $sink_desc")
            SINK_RAW+=("$sink_name")
        fi
    fi
done <<< "$SINKS"

MENU_ITEMS=$(printf "%s\n" "${SINK_NAMES[@]}")
CHOSEN=$(echo -e "$MENU_ITEMS" | rofi -dmenu -i -p "Salida de Audio:" -theme ~/.config/rofi/config.rasi)

[ -z "$CHOSEN" ] && exit 0

for i in "${!SINK_NAMES[@]}"; do
    if [ "${SINK_NAMES[$i]}" = "$CHOSEN" ]; then
        TARGET_SINK="${SINK_RAW[$i]}"
        pactl set-default-sink "$TARGET_SINK"
        for input in $(pactl list short sink-inputs 2>/dev/null | cut -f1); do
            pactl move-sink-input "$input" "$TARGET_SINK" 2>/dev/null || true
        done
        CLEAN_NAME=$(echo "$CHOSEN" | sed 's/^[✔ ]*🔊 //')
        notify-send -i audio-speakers "Salida de Audio" "Cambiado a:\n$CLEAN_NAME"
        break
    fi
done
EOF

    # Script: rofi_clipboard (Historial de portapapeles)
    local CLIP_MENU="$BIN_DIR/rofi_clipboard"
    cat << 'EOF' > "$CLIP_MENU"
#!/usr/bin/env bash
if command -v greenclip &>/dev/null; then
    rofi -modi "clipboard:greenclip print" -show clipboard -run-command '{cmd}' -theme ~/.config/rofi/config.rasi
else
    CACHE_FILE="$HOME/.cache/clipboard_history.txt"
    mkdir -p "$(dirname "$CACHE_FILE")"
    touch "$CACHE_FILE"
    
    CURRENT=$(xclip -selection clipboard -o 2>/dev/null || true)
    if [ -n "$CURRENT" ]; then
        grep -vxF "$CURRENT" "$CACHE_FILE" > "$CACHE_FILE.tmp" 2>/dev/null || true
        echo "$CURRENT" | cat - "$CACHE_FILE.tmp" | head -n 40 > "$CACHE_FILE" 2>/dev/null || true
        rm -f "$CACHE_FILE.tmp"
    fi
    
    CHOSEN=$(cat "$CACHE_FILE" | rofi -dmenu -i -p "Portapapeles:" -theme ~/.config/rofi/config.rasi)
    if [ -n "$CHOSEN" ]; then
        echo -n "$CHOSEN" | xclip -selection clipboard
        echo -n "$CHOSEN" | xclip -selection primary
        notify-send -i edit-paste "Portapapeles" "Copiado al búfer"
    fi
fi
EOF

    # Script: rofi_monitors (Gestor de resolución y monitores)
    local MON_MENU="$BIN_DIR/rofi_monitors"
    cat << 'EOF' > "$MON_MENU"
#!/usr/bin/env bash
MONITORS=($(xrandr --query | grep " connected" | cut -d" " -f1))
COUNT="${#MONITORS[@]}"

if [ "$COUNT" -lt 2 ]; then
    OPTIONS="⚙️ Abrir ARandR (Configuración Avanzada)\n🔄 Reiniciar Pantalla (${MONITORS[0]:-Principal})"
    CHOSEN=$(echo -e "$OPTIONS" | rofi -dmenu -i -p "Pantallas ($COUNT detectada):" -theme ~/.config/rofi/config.rasi)
    case "$CHOSEN" in
        *"ARandR"*) arandr & ;;
        *"Reiniciar"*)
            xrandr --auto
            ~/.local/bin/launch_polybar
            ~/.local/bin/random_wallpaper
            ;;
    esac
    exit 0
fi

PRIMARY="${MONITORS[0]}"
SECONDARY="${MONITORS[1]}"

OPTIONS="🖥️ Solo Pantalla Principal ($PRIMARY)\n💻 Solo Pantalla Secundaria ($SECONDARY)\n➡️ Extender a la Derecha ($PRIMARY + $SECONDARY)\n⬅️ Extender a la Izquierda ($SECONDARY + $PRIMARY)\n👥 Duplicar Pantallas (Espejo)\n⚙️ Abrir ARandR (Avanzado)"

CHOSEN=$(echo -e "$OPTIONS" | rofi -dmenu -i -p "Configurar Monitores:" -theme ~/.config/rofi/config.rasi)

case "$CHOSEN" in
    *"Solo Pantalla Principal"*)
        xrandr --output "$PRIMARY" --auto --primary --output "$SECONDARY" --off
        ;;
    *"Solo Pantalla Secundaria"*)
        xrandr --output "$SECONDARY" --auto --primary --output "$PRIMARY" --off
        ;;
    *"Extender a la Derecha"*)
        xrandr --output "$PRIMARY" --auto --primary --output "$SECONDARY" --auto --right-of "$PRIMARY"
        ;;
    *"Extender a la Izquierda"*)
        xrandr --output "$PRIMARY" --auto --primary --output "$SECONDARY" --auto --left-of "$PRIMARY"
        ;;
    *"Duplicar"*)
        xrandr --output "$PRIMARY" --auto --output "$SECONDARY" --auto --same-as "$PRIMARY"
        ;;
    *"ARandR"*)
        arandr &
        exit 0
        ;;
esac

sleep 0.5
bspc wm -r
~/.local/bin/launch_polybar
~/.local/bin/random_wallpaper
notify-send -i video-display "Monitores" "Disposición de pantallas actualizada"
EOF

    # Script: rofi_master_menu (Menú Maestro Integrador Completo)
    local MASTER_MENU="$BIN_DIR/rofi_master_menu"
    cat << 'EOF' > "$MASTER_MENU"
#!/usr/bin/env bash
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
export DISPLAY="${DISPLAY:-:0}"

OPTIONS="🚀 Lanzador de Aplicaciones\n🛠️ Mantenimiento & Tweaks (Actualizaciones / Limpieza)\n✏️ Rice Editor (Ajustar Tema)\n🎭 Selector de Rice (Tema Global)\n📶 Redes Wi-Fi\n🔷 Dispositivos Bluetooth\n🎧 Selector de Salida de Audio\n📋 Historial de Portapapeles\n🖥️ Configurar Monitores\n📊 Selector Estilo Polybar\n🖼️ Selector de Wallpaper\n🔄 Wallpaper Aleatorio\n📌 Terminal Scratchpad\n📸 Captura de Pantalla\n🔒 Bloquear Pantalla\n⚡ Menú de Apagado"

CHOSEN=$(echo -e "$OPTIONS" | rofi -dmenu -i -p "Menú Principal:" -theme ~/.config/rofi/config.rasi)

case "$CHOSEN" in
    *Lanzador*)
        rofi -show drun -theme ~/.config/rofi/config.rasi
        ;;
    *Mantenimiento*)
        ~/.local/bin/bspwm_tweaks
        ;;
    *Rice*Editor*)
        ~/.local/bin/rice_editor
        ;;
    *Spotify*|*Reproductor*)
        ~/.local/bin/launch_music_player
        ;;
    *Wi-Fi*)
        ~/.local/bin/rofi_wifi_menu
        ;;
    *Bluetooth*)
        ~/.local/bin/rofi_bluetooth
        ;;
    *Audio*)
        ~/.local/bin/rofi_audio_output
        ;;
    *Portapapeles*)
        ~/.local/bin/rofi_clipboard
        ;;
    *Monitores*)
        ~/.local/bin/rofi_monitors
        ;;
    *Selector*Rice*|*Tema*Global*)
        ~/.local/bin/rice_swapper
        ;;
    *Polybar*)
        ~/.local/bin/polybar_theme_selector
        ;;
    *Wallpaper*|*Selector*)
        ~/.local/bin/rofi_wallpaper_picker
        ;;
    *Aleatorio*)
        ~/.local/bin/random_wallpaper
        ;;
    *Scratchpad*)
        ~/.local/bin/scratchpad
        ;;
    *Captura*)
        ~/.local/bin/shot_tool area
        ;;
    *Bloquear*)
        ~/.local/bin/blur_lockscreen
        ;;
    *Apagado*)
        ~/.local/bin/powermenu_rofi
        ;;
esac
EOF

    # Script: notify_volume (Retroalimentación OSD de volumen con barra Dunst)
    local NOTIFY_VOL="$BIN_DIR/notify_volume"
    cat << 'EOF' > "$NOTIFY_VOL"
#!/usr/bin/env bash
case "$1" in
    up)
        if command -v pamixer &>/dev/null; then
            pamixer -u -i 5
        else
            pactl set-sink-mute @DEFAULT_SINK@ 0
            pactl set-sink-volume @DEFAULT_SINK@ +5%
        fi
        ;;
    down)
        if command -v pamixer &>/dev/null; then
            pamixer -u -d 5
        else
            pactl set-sink-mute @DEFAULT_SINK@ 0
            pactl set-sink-volume @DEFAULT_SINK@ -5%
        fi
        ;;
    mute)
        if command -v pamixer &>/dev/null; then
            pamixer -t
        else
            pactl set-sink-mute @DEFAULT_SINK@ toggle
        fi
        ;;
esac

if command -v pamixer &>/dev/null; then
    VOL=$(pamixer --get-volume)
    MUTE=$(pamixer --get-mute)
else
    VOL=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -Po '[0-9]+(?=%)' | head -1)
    MUTE_RAW=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}')
    [ "$MUTE_RAW" = "yes" ] && MUTE="true" || MUTE="false"
fi

[ -z "$VOL" ] && VOL=0

if [ "$MUTE" = "true" ] || [ "$VOL" -eq 0 ]; then
    dunstify -a "VOLUME" -r 2593 -u low -i audio-volume-muted "Volumen: Silenciado" -h int:value:0
else
    if [ "$VOL" -ge 65 ]; then
        ICON="audio-volume-high"
    elif [ "$VOL" -ge 30 ]; then
        ICON="audio-volume-medium"
    else
        ICON="audio-volume-low"
    fi
    dunstify -a "VOLUME" -r 2593 -u low -h int:value:"$VOL" -i "$ICON" "Volumen: ${VOL}%"
fi
EOF

    # Script: notify_brightness (Retroalimentación OSD de brillo con barra Dunst)
    local NOTIFY_BRI="$BIN_DIR/notify_brightness"
    cat << 'EOF' > "$NOTIFY_BRI"
#!/usr/bin/env bash
case "$1" in
    up)
        brightnessctl set +5% >/dev/null 2>&1 || xbacklight -inc 5
        ;;
    down)
        brightnessctl set 5%- >/dev/null 2>&1 || xbacklight -dec 5
        ;;
esac

if command -v brightnessctl &>/dev/null; then
    BRI=$(brightnessctl -m | awk -F, '{print substr($4, 0, length($4)-1)}')
else
    BRI=$(xbacklight -get 2>/dev/null | cut -d. -f1)
fi

[ -z "$BRI" ] && BRI=50

dunstify -a "BRIGHTNESS" -r 2594 -u low -h int:value:"$BRI" -i display-brightness "Brillo: ${BRI}%"
EOF

    # Script: nagasaki_fetch (Identidad y Fetch Banner de Nagasaki BSPWM)
    local NAGASAKI_FETCH="$BIN_DIR/nagasaki_fetch"
    cat << 'EOF' > "$NAGASAKI_FETCH"
#!/usr/bin/env bash
CLR_RESET="\033[0m"
CLR_MAUVE="\033[38;2;203;166;247m"
CLR_BLUE="\033[38;2;137;180;250m"
CLR_CYAN="\033[38;2;148;226;213m"
CLR_GREEN="\033[38;2;166;227;161m"
CLR_PEACH="\033[38;2;250;179;135m"
CLR_TEXT="\033[38;2;205;214;244m"
CLR_SUBTEXT="\033[38;2;166;173;200m"

echo -e "${CLR_MAUVE}"
cat << "BANNER"
  _  _   _   ___   _   ___   _   _ ___   ___  ____  ______        __  __ 
 | \| | /_\ / __| /_\ / __| /_\ | |/ |_ _| | _ )/ ___||  _ \ \      / /  \/  |
 | .` |/ _ \ (_ |/ _ \__ \/ _ \| ' < | |  | _ \\___ \| |_) \ \ /\ / /| |\/| |
 |_|\_/_/ \_\___/_/ \_\___/_/ \_\_|\_\___| |___/|____/|____/  \_/\_/  |_|  |_|
BANNER
echo -e "${CLR_CYAN}         ─── Nagasaki BSPWM Desktop Environment (Catppuccin Mocha) ───${CLR_RESET}\n"

if command -v fastfetch &>/dev/null; then
    fastfetch --logo none --structure Title:Separator:OS:Host:Kernel:Uptime:Packages:Shell:WM:Terminal:Memory:Colors 2>/dev/null || true
else
    USER_HOST="${USER}@$(hostname)"
    OS_NAME=$(grep -oP '(?<=^PRETTY_NAME=")[^"]+' /etc/os-release 2>/dev/null || echo "Arch Linux")
    KERNEL=$(uname -r)
    UPTIME=$(uptime -p 2>/dev/null | sed 's/up //' || echo "Desconocido")
    WM="bspwm"
    SHELL_NAME=$(basename "$SHELL")
    RAM=$(free -h 2>/dev/null | awk '/^Mem:/ {print $3 "/" $2}' || echo "N/A")

    echo -e "${CLR_MAUVE}   USUARIO   :${CLR_RESET} ${CLR_TEXT}${USER_HOST}${CLR_RESET}"
    echo -e "${CLR_BLUE}  󰣇 SISTEMA   :${CLR_RESET} ${CLR_TEXT}${OS_NAME}${CLR_RESET}"
    echo -e "${CLR_CYAN}  󰌽 KERNEL    :${CLR_RESET} ${CLR_TEXT}${KERNEL}${CLR_RESET}"
    echo -e "${CLR_GREEN}  󱑂 UPTIME    :${CLR_RESET} ${CLR_TEXT}${UPTIME}${CLR_RESET}"
    echo -e "${CLR_PEACH}  󰍹 WM        :${CLR_RESET} ${CLR_TEXT}${WM}${CLR_RESET}"
    echo -e "${CLR_MAUVE}  󰞷 SHELL     :${CLR_RESET} ${CLR_TEXT}${SHELL_NAME}${CLR_RESET}"
    echo -e "${CLR_BLUE}  󰍛 MEMORIA   :${CLR_RESET} ${CLR_TEXT}${RAM}${CLR_RESET}"
    echo ""
    echo -e "  \033[41m   \033[42m   \033[43m   \033[44m   \033[45m   \033[46m   \033[47m   \033[0m\n"
fi
EOF

    # Script: spotify_status (Estado de música para Polybar)
    local SPOTIFY_STATUS="$BIN_DIR/spotify_status"
    cat << 'EOF' > "$SPOTIFY_STATUS"
#!/usr/bin/env bash
if ! command -v playerctl &>/dev/null; then
    echo "ncspot"
    exit 0
fi

STATUS=$(playerctl status 2>/dev/null)
if [ "$STATUS" = "Playing" ] || [ "$STATUS" = "Paused" ]; then
    ARTIST=$(playerctl metadata artist 2>/dev/null)
    TITLE=$(playerctl metadata title 2>/dev/null)
    [ "$STATUS" = "Paused" ] && ICON="⏸" || ICON="▶"
    if [ -n "$ARTIST" ] && [ -n "$TITLE" ]; then
        TRACK="$ICON $ARTIST - $TITLE"
    elif [ -n "$TITLE" ]; then
        TRACK="$ICON $TITLE"
    else
        TRACK="$ICON Spotify"
    fi
    echo "${TRACK:0:32}"
else
    echo "ncspot"
fi
EOF

    # Script: launch_music_player (Lanzador interactivo de ncspot + cava en Kitty)
    local LAUNCH_MUSIC="$BIN_DIR/launch_music_player"
    cat << 'EOF' > "$LAUNCH_MUSIC"
#!/usr/bin/env bash
if command -v ncspot &>/dev/null; then
    kitty --title "Nagasaki Music Player" sh -c "cava & ncspot; pkill cava" &
elif command -v spotify &>/dev/null; then
    spotify &
    kitty --title "Nagasaki Cava Visualizer" cava &
else
    kitty --title "Nagasaki Visualizer" cava &
fi
EOF

    # Script: rice_editor (Editor interactivo de Temas y Estética BSPWM)
    local RICE_EDITOR="$BIN_DIR/rice_editor"
    cat << 'EOF' > "$RICE_EDITOR"
#!/usr/bin/env bash
# ==============================================================================
# RICE EDITOR - Editor Interactivo de Temas y Estética BSPWM
# ==============================================================================

notify() {
    notify-send -u low -i preferences-desktop-theme "Rice Editor" "$1"
}

CURRENT_RICE="CatppuccinMocha"
[ -f "$HOME/.config/bspwm/current_rice" ] && CURRENT_RICE="$(cat "$HOME/.config/bspwm/current_rice")"

MENU_OPTIONS="1. 📐 Cambiar Gaps (Espacio entre ventanas)\n2. 🖼️ Cambiar Ancho de Bordes\n3. 🎨 Cambiar Color de Borde Enfocado\n4. ✨ Ajustar Redondeado de Esquinas (Picom)\n5. 🖼️ Cambiar Wallpaper de este Rice\n6. 💾 Guardar Cambios en Rice Actual ($CURRENT_RICE)\n7. ➕ Guardar como Nuevo Rice Personalizado"

CHOSEN=$(echo -e "$MENU_OPTIONS" | rofi -dmenu -i -p "Rice Editor [$CURRENT_RICE]:" -theme ~/.config/rofi/config.rasi)

case "$CHOSEN" in
    "1."*)
        GAP=$(rofi -dmenu -p "Ingresa tamaño de Gap (ej: 0, 5, 10, 15, 20):" -theme ~/.config/rofi/config.rasi)
        if [[ "$GAP" =~ ^[0-9]+$ ]]; then
            bspc config window_gap "$GAP"
            notify "Gaps ajustados a ${GAP}px"
        fi
        ;;
    "2."*)
        BORDER=$(rofi -dmenu -p "Ingresa ancho de borde (ej: 0, 1, 2, 3, 4):" -theme ~/.config/rofi/config.rasi)
        if [[ "$BORDER" =~ ^[0-9]+$ ]]; then
            bspc config border_width "$BORDER"
            notify "Bordes ajustados a ${BORDER}px"
        fi
        ;;
    "3."*)
        COLOR_OPT="1. Mauve (#cba6f7)\n2. Blue (#89b4fa)\n3. Red (#f38ba8)\n4. Green (#a6e3a1)\n5. Peach (#fab387)\n6. Cyan (#94e2d5)\n7. Código Hex Personalizado"
        CHOSEN_CLR=$(echo -e "$COLOR_OPT" | rofi -dmenu -i -p "Selecciona color de borde enfocado:")
        HEX=""
        case "$CHOSEN_CLR" in
            "1."*) HEX="#cba6f7" ;;
            "2."*) HEX="#89b4fa" ;;
            "3."*) HEX="#f38ba8" ;;
            "4."*) HEX="#a6e3a1" ;;
            "5."*) HEX="#fab387" ;;
            "6."*) HEX="#94e2d5" ;;
            "7."*) HEX=$(rofi -dmenu -p "Ingresa código Hex (ej: #ff5555):") ;;
        esac
        if [ -n "$HEX" ]; then
            bspc config focused_border_color "$HEX"
            notify "Color de borde enfocado cambiado a $HEX"
        fi
        ;;
    "4."*)
        RAD=$(rofi -dmenu -p "Ingresa radio de redondeado para Picom (ej: 0, 8, 12, 16):" -theme ~/.config/rofi/config.rasi)
        if [[ "$RAD" =~ ^[0-9]+$ ]] && [ -f "$HOME/.config/picom/picom.conf" ]; then
            sed -i "s/corner-radius = .*/corner-radius = $RAD;/" "$HOME/.config/picom/picom.conf"
            pkill picom; picom --config "$HOME/.config/picom/picom.conf" -b &
            notify "Esquinas redondeadas en Picom ajustadas a ${RAD}px"
        fi
        ;;
    "5."*)
        WALL_DIR="$HOME/Pictures/wallpapers"
        if [ -d "$WALL_DIR" ]; then
            IMG=$(find "$WALL_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.webp" \) | rofi -dmenu -i -p "Seleccionar Wallpaper para Rice:")
            if [ -n "$IMG" ]; then
                feh --bg-fill "$IMG"
                notify "Wallpaper aplicado: $(basename "$IMG")"
            fi
        fi
        ;;
    "6."*)
        ENV_FILE="$HOME/.config/bspwm/rices/$CURRENT_RICE/theme.env"
        if [ -f "$ENV_FILE" ]; then
            F_COLOR="$(bspc config focused_border_color)"
            sed -i "s/BORDER_FOCUSED=.*/BORDER_FOCUSED=\"$F_COLOR\"/" "$ENV_FILE"
            notify "Cambios guardados en el Rice: $CURRENT_RICE"
        fi
        ;;
    "7."*)
        NEW_RICE=$(rofi -dmenu -p "Nombre para el nuevo Rice (sin espacios):")
        if [ -n "$NEW_RICE" ]; then
            NEW_DIR="$HOME/.config/bspwm/rices/$NEW_RICE"
            mkdir -p "$NEW_DIR"
            cp -r "$HOME/.config/bspwm/rices/$CURRENT_RICE/"* "$NEW_DIR/" 2>/dev/null || true
            echo "$NEW_RICE" > "$HOME/.config/bspwm/current_rice"
            notify "Nuevo Rice creado y activado: $NEW_RICE"
        fi
        ;;
esac
EOF

    # Script: notify_media (Notificación Toast OSD de reproducción multimedia)
    local NOTIFY_MEDIA="$BIN_DIR/notify_media"
    cat << 'EOF' > "$NOTIFY_MEDIA"
#!/usr/bin/env bash
if ! command -v playerctl &>/dev/null; then exit 0; fi
STATUS=$(playerctl status 2>/dev/null)
if [ -n "$STATUS" ]; then
    ARTIST=$(playerctl metadata artist 2>/dev/null || echo "Desconocido")
    TITLE=$(playerctl metadata title 2>/dev/null || echo "Música")
    ALBUM=$(playerctl metadata album 2>/dev/null || echo "")
    notify-send -u low -i audio-x-generic "󰎈 Reproduciendo" "<b>$TITLE</b>\n$ARTIST ($ALBUM)"
fi
EOF

    # Script: rofi_system_info (Applet Rofi de información de recursos)
    local ROFI_SYS="$BIN_DIR/rofi_system_info"
    cat << 'EOF' > "$ROFI_SYS"
#!/usr/bin/env bash
RAM=$(free -h | awk '/Mem:/ {print $3 "/" $2}')
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8"%"}')
DISK=$(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')
UPTIME=$(uptime -p | sed 's/up //')
IP_LOCAL=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}')
[ -z "$IP_LOCAL" ] && IP_LOCAL="Desconectado"

INFO="🧠 Memoria RAM: $RAM\n⚡ Uso CPU: $CPU\n💾 Disco (/): $DISK\n⏱️ Uptime: $UPTIME\n🌐 IP Local: $IP_LOCAL"
echo -e "$INFO" | rofi -dmenu -i -p "Información del Sistema:" -theme ~/.config/rofi/config.rasi
EOF

    # Script: night_mode (Filtro de Luz Azul / Modo Noche)
    local NIGHT_SCRIPT="$BIN_DIR/night_mode"
    cat << 'EOF' > "$NIGHT_SCRIPT"
#!/usr/bin/env bash
STATE_FILE="$HOME/.config/night_mode_state"
notify() { notify-send -u low -i display "Modo Noche" "$1"; }

if [ -f "$STATE_FILE" ]; then
    rm -f "$STATE_FILE"
    pkill gammastep 2>/dev/null || pkill redshift 2>/dev/null || xrandr --output $(xrandr | grep " connected" | cut -d" " -f1 | head -n1) --gamma 1:1:1
    notify "Modo Noche Desactivado (Luz normal)"
else
    touch "$STATE_FILE"
    if command -v gammastep &>/dev/null; then
        gammastep -O 4500 &
    elif command -v redshift &>/dev/null; then
        redshift -O 4500 &
    else
        xrandr --output $(xrandr | grep " connected" | cut -d" " -f1 | head -n1) --gamma 1.0:0.9:0.8
    fi
    notify "Modo Noche Activado (4500K Filtro Cálido)"
fi
EOF

    # Script: rofi_recent_files (Selector de archivos recientes)
    local RECENT_FILES="$BIN_DIR/rofi_recent_files"
    cat << 'EOF' > "$RECENT_FILES"
#!/usr/bin/env bash
RECENT=$(find ~/Downloads ~/Documents ~/Pictures -type f -mtime -7 2>/dev/null | sort -r | head -n 25)
if [ -z "$RECENT" ]; then
    notify-send -u low "Archivos Recientes" "No se encontraron archivos recientes."
    exit 0
fi

CHOSEN=$(echo "$RECENT" | rofi -dmenu -i -p "Archivos Recientes:" -theme ~/.config/rofi/config.rasi)
if [ -n "$CHOSEN" ] && [ -f "$CHOSEN" ]; then
    xdg-open "$CHOSEN" &
fi
EOF

    # Script: blur_lock (Bloqueo de pantalla con desenfoque suave)
    local BLUR_LOCK_SCRIPT="$BIN_DIR/blur_lock"
    cat << 'EOF' > "$BLUR_LOCK_SCRIPT"
#!/usr/bin/env bash
TMP_IMG="/tmp/lockscreen_blur.png"
if command -v maim &>/dev/null && command -v convert &>/dev/null; then
    maim "$TMP_IMG"
    convert "$TMP_IMG" -blur 0x8 "$TMP_IMG"
    i3lock -i "$TMP_IMG"
elif command -v betterlockscreen &>/dev/null; then
    betterlockscreen -l blur
else
    i3lock -c 1e1e2e
fi
rm -f "$TMP_IMG" 2>/dev/null
EOF

    # Script: rofi_power_profile (Perfil de energía)
    local PWR_PROF="$BIN_DIR/rofi_power_profile"
    cat << 'EOF' > "$PWR_PROF"
#!/usr/bin/env bash
notify() { notify-send -u low -i power-profile "Perfil de Energía" "$1"; }

OPTIONS="1. ⚡ Alto Rendimiento (Performance)\n2. ⚖️ Equilibrado (Balanced)\n3. 🔋 Ahorro de Batería (Power-saver)"
CHOSEN=$(echo -e "$OPTIONS" | rofi -dmenu -i -p "Perfil de Energía:" -theme ~/.config/rofi/config.rasi)

case "$CHOSEN" in
    "1."*)
        powerprofilesctl set performance 2>/dev/null || true
        notify "Perfil cambiado a: Alto Rendimiento"
        ;;
    "2."*)
        powerprofilesctl set balanced 2>/dev/null || true
        notify "Perfil cambiado a: Equilibrado"
        ;;
    "3."*)
        powerprofilesctl set power-saver 2>/dev/null || true
        notify "Perfil cambiado a: Ahorro de Batería"
        ;;
esac
EOF

    # Script: bspwm_tweaks (Panel Visual de Mantenimiento y Tweaks)
    local TWEAKS_SCRIPT="$BIN_DIR/bspwm_tweaks"
    cat << 'EOF' > "$TWEAKS_SCRIPT"
#!/usr/bin/env bash
# ==============================================================================
# NAGASAKI CONTROL CENTER & SYSTEM TWEAKS / MAINTENANCE PANEL
# ==============================================================================

notify() {
    notify-send -u low -i preferences-system "Nagasaki Control Center" "$1"
}

MENU_OPTIONS="1. 🔄 Actualizar Sistema Completo (Pacman & AUR)\n2. 📦 Comprobar Actualizaciones Pendientes\n3. 🧹 Limpiar Caché de Pacman\n4. 🗑️ Eliminar Paquetes Huérfanos\n5. 🧹 Limpiar Caché de Usuario (~/.cache)\n6. 🎮 Alternar Compositor Picom (Modo Gaming ON/OFF)\n7. 🧠 Liberar Memoria RAM (Drop Caches)\n8. 🔕 Alternar Modo No Molestar (Dunst DND)\n9. 🔄 Reiniciar Todos los Demonios (Polybar/SXHKD/Picom/Dunst)\n10. 🔍 Diagnóstico de Servicios Fallidos"

CHOSEN=$(echo -e "$MENU_OPTIONS" | rofi -dmenu -i -p "Mantenimiento & Tweaks:" -theme ~/.config/rofi/config.rasi)

case "$CHOSEN" in
    "1."*)
        if command -v yay &>/dev/null; then
            kitty --title "Actualización del Sistema" sh -c "yay -Syu; echo 'Presiona Enter para cerrar...'; read" &
        else
            kitty --title "Actualización del Sistema" sh -c "sudo pacman -Syu; echo 'Presiona Enter para cerrar...'; read" &
        fi
        notify "Iniciada actualización del sistema en Kitty..."
        ;;
    "2."*)
        PENDING=$(checkupdates 2>/dev/null | wc -l || echo "0")
        notify "Tienes $PENDING paquetes pendientes por actualizar."
        ;;
    "3."*)
        if command -v paccache &>/dev/null; then
            sudo paccache -r 2>/dev/null || notify "Se requiere sudo para paccache"
            notify "Caché de pacman limpiada exitosamente (paccache)."
        else
            sudo pacman -Sc --noconfirm 2>/dev/null || notify "Se requiere sudo para pacman"
            notify "Caché de pacman limpiada exitosamente."
        fi
        ;;
    "4."*)
        ORPHANS=$(pacman -Qtdq 2>/dev/null)
        if [ -n "$ORPHANS" ]; then
            sudo pacman -Rns --noconfirm $ORPHANS 2>/dev/null
            notify "Paquetes huérfanos eliminados: $ORPHANS"
        else
            notify "No se encontraron paquetes huérfanos en el sistema."
        fi
        ;;
    "5."*)
        rm -rf ~/.cache/* 2>/dev/null || true
        notify "Caché de usuario (~/.cache) limpiada."
        ;;
    "6."*)
        if pgrep -x picom >/dev/null; then
            pkill picom
            notify "Modo Gaming ACTIVADO (Picom deshabilitado para máximo FPS)"
        else
            picom --config ~/.config/picom/picom.conf -b &
            notify "Modo Gaming DESACTIVADO (Picom y transparencias activas)"
        fi
        ;;
    "7."*)
        sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true
        notify "Memoria RAM caché liberada exitosamente."
        ;;
    "8."*)
        dunstctl set-paused toggle
        PAUSED=$(dunstctl is-paused)
        if [ "$PAUSED" = "true" ]; then
            notify "Modo No Molestar (DND) ACTIVADO"
        else
            notify "Modo No Molestar (DND) DESACTIVADO"
        fi
        ;;
    "9."*)
        pkill -USR1 -x sxhkd || true
        ~/.local/bin/launch_polybar &
        pkill picom; picom --config ~/.config/picom/picom.conf -b &
        notify "Todos los demonios han sido reiniciados correctamente."
        ;;
    "10."*)
        FAILED=$(systemctl --failed --no-legend 2>/dev/null)
        if [ -z "$FAILED" ]; then
            notify "Todos los servicios systemd están operando normalmente (0 fallos)."
        else
            notify "Servicios fallidos detectados:\n$FAILED"
        fi
        ;;
esac
EOF

    # Script: nagasaki_welcome (Menú TUI interactivo de bienvenida)
    local WELCOME_SCRIPT="$BIN_DIR/nagasaki_welcome"
    cat << 'EOF' > "$WELCOME_SCRIPT"
#!/usr/bin/env bash
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

CLR_RESET="\033[0m"
CLR_MAUVE="\033[38;2;203;166;247m"
CLR_BLUE="\033[38;2;137;180;250m"
CLR_CYAN="\033[38;2;148;226;213m"
CLR_GREEN="\033[38;2;166;227;161m"
CLR_PEACH="\033[38;2;250;179;135m"
CLR_TEXT="\033[38;2;205;214;244m"
CLR_SUBTEXT="\033[38;2;166;173;200m"

clear
echo -e "${CLR_MAUVE}"
cat << "BANNER"
  _  _   _   ___   _   ___   _   _ ___   ___  ____  ______        __  __ 
 | || | /_\ / __| /_\ / __| /_\ | | _ \ / __||  _ \|  _ \ \      / / |  \/  |
 | __ |/ _ \\__ \/ _ \\__ \/ _ \| |  _/ \__ \| |_) | |_) \ \ /\ / /  | |\/| |
 |_||_/_/ \_\___/_/ \_\___/_/ \_\_|_|   |___/|____/|____/ \_/\_/   |_|  |_|
BANNER
echo -e "${CLR_CYAN}         Entorno BSPWM Minimalista, Estético & Modular para Arch Linux${CLR_RESET}\n"

CURRENT_RICE="CatppuccinMocha"
[ -f "$HOME/.config/bspwm/current_rice" ] && CURRENT_RICE="$(cat "$HOME/.config/bspwm/current_rice")"

echo -e "${CLR_TEXT}  Rice Activo  :${CLR_RESET} ${CLR_GREEN}${CURRENT_RICE}${CLR_RESET}"
echo -e "${CLR_TEXT}  Usuario      :${CLR_RESET} ${CLR_BLUE}$(whoami)${CLR_RESET}"
echo -e "${CLR_TEXT}  Kernel       :${CLR_RESET} ${CLR_SUBTEXT}$(uname -r)${CLR_RESET}"
echo -e "${CLR_TEXT}  Uptime       :${CLR_RESET} ${CLR_PEACH}$(uptime -p | sed 's/up //')${CLR_RESET}\n"

echo -e "${CLR_MAUVE}=== Accesos Rápidos de Nagasaki BSPWM ===${CLR_RESET}"
echo -e "  ${CLR_CYAN}[1]${CLR_RESET} ✏️  Rice Editor (Ajustar gaps, bordes, esquinas) ${CLR_SUBTEXT}[Super + Shift + R]${CLR_RESET}"
echo -e "  ${CLR_CYAN}[2]${CLR_RESET} 🛠️  Control Center & Tweaks (Actualizaciones / Mantenimiento) ${CLR_SUBTEXT}[Super + Shift + T]${CLR_RESET}"
echo -e "  ${CLR_CYAN}[3]${CLR_RESET} 🎭 Selector de Rice & Temas Globales ${CLR_SUBTEXT}[Super + P]${CLR_RESET}"
echo -e "  ${CLR_CYAN}[4]${CLR_RESET} 📸 Nagasaki Showcase (Preparar escena para captura de GitHub) ${CLR_SUBTEXT}[Comando]${CLR_RESET}"
echo -e "  ${CLR_CYAN}[5]${CLR_RESET} ⌨️  Ver Lista Completa de Atajos de Teclado ${CLR_SUBTEXT}[sxhkdrc]${CLR_RESET}"
echo -e "  ${CLR_CYAN}[6]${CLR_RESET} 🚪 Salir al Terminal"
echo ""

read -p "Selecciona una opción [1-6]: " opt
case "$opt" in
    1) ~/.local/bin/rice_editor ;;
    2) ~/.local/bin/bspwm_tweaks ;;
    3) ~/.local/bin/polybar_theme_selector ;;
    4) ~/.local/bin/nagasaki_showcase ;;
    5) 
        echo -e "\n${CLR_MAUVE}=== Principal Shortcuts (sxhkd) ===${CLR_RESET}"
        echo -e "  Super + Enter       : Abrir Kitty Terminal"
        echo -e "  Super + d           : Menú Maestro Rofi"
        echo -e "  Super + Shift + r   : Rice Editor"
        echo -e "  Super + Shift + t   : Mantenimiento & Tweaks"
        echo -e "  Super + n           : Gestor Wi-Fi Rofi"
        echo -e "  Super + i           : Información del Sistema"
        echo -e "  Super + f           : Archivos Recientes"
        echo -e "  Super + Shift + n   : Modo Noche (Filtro 4500K)"
        echo -e "  Super + u/m/c       : Scratchpads (Term/Música/Calc)"
        echo -e "  Print               : Captura de Pantalla interactiva"
        echo ""
        read -p "Presiona Enter para continuar..."
        ;;
    *) exit 0 ;;
esac
EOF

    # Script: nagasaki_showcase (Captura automatizada para GitHub / Unixporn)
    local SHOWCASE_SCRIPT="$BIN_DIR/nagasaki_showcase"
    cat << 'EOF' > "$SHOWCASE_SCRIPT"
#!/usr/bin/env bash
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
export DISPLAY="${DISPLAY:-:0}"

notify() {
    notify-send -u low -i camera-photo "Nagasaki Showcase" "$1" 2>/dev/null || true
}

SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SCREENSHOT_DIR"
FILE="$SCREENSHOT_DIR/nagasaki_showcase_$(date +%Y%m%d_%H%M%S).png"

notify "Preparando escena de presentación..."

kitty --title "Nagasaki Fetch" sh -c "~/.local/bin/nagasaki_fetch 2>/dev/null || fastfetch; sleep 6" &
sleep 0.6

if command -v cava &>/dev/null; then
    kitty --title "Nagasaki Visualizer" sh -c "cava; sleep 6" &
    sleep 0.6
fi

rofi -show drun &
sleep 1.2

if command -v maim &>/dev/null; then
    maim "$FILE"
elif command -v scrot &>/dev/null; then
    scrot "$FILE"
elif command -v import &>/dev/null; then
    import -window root "$FILE"
fi

pkill -f "Nagasaki Fetch" 2>/dev/null || true
pkill -f "Nagasaki Visualizer" 2>/dev/null || true
pkill rofi 2>/dev/null || true

if [ -f "$FILE" ]; then
    if command -v xclip &>/dev/null; then
        xclip -selection clipboard -t image/png -i "$FILE" 2>/dev/null || true
    fi
    notify "Captura de Showcase completada exitosamente:\n$FILE"
else
    notify "No se pudo tomar la captura. Verifica que maim, scrot o imagemagick estén instalados."
fi
EOF

    chmod +x "$LAUNCH_POLY" "$WALL_SCRIPT" "$THEME_SELECT" "$POLYTHEME_CLI" "$POWERMENU" "$MASTER_MENU" "$NOTIFY_VOL" "$NOTIFY_BRI" "$WIFI_MENU" "$BT_MENU" "$AUDIO_MENU" "$CLIP_MENU" "$MON_MENU" "$NAGASAKI_FETCH" "$SPOTIFY_STATUS" "$LAUNCH_MUSIC" "$RICE_EDITOR" "$NOTIFY_MEDIA" "$ROFI_SYS" "$NIGHT_SCRIPT" "$RECENT_FILES" "$BLUR_LOCK_SCRIPT" "$PWR_PROF" "$TWEAKS_SCRIPT" "$WELCOME_SCRIPT" "$SHOWCASE_SCRIPT" 2>/dev/null || true
    chmod +x "$BIN_DIR"/* 2>/dev/null || true
    chown -R "$TARGET_USER:$TARGET_USER" "$BIN_DIR"
    log_success "Scripts de utilidades, applets de Rofi, OSDs y Reproductor de Música creados con permisos de ejecución."
}

# ------------------------------------------------------------------------------
# 7. DESCARGA DEL REPOSITORIO DE WALLPAPERS
# ------------------------------------------------------------------------------
download_wallpapers() {
    log_info "7. Descargando colección de wallpapers desde https://github.com/dharmx/walls.git..."
    
    if [ ! -d "$WALLPAPERS_DIR/.git" ]; then
        run_as_user git clone --depth 1 https://github.com/dharmx/walls.git "$WALLPAPERS_DIR" || {
            log_warning "No se pudo clonar el repositorio de wallpapers. Se creará un fondo predeterminado."
        }
    else
        log_info "El repositorio de wallpapers ya existe. Actualizando..."
        (
            cd "$WALLPAPERS_DIR"
            run_as_user git pull || true
        )
    fi

    # Aplicar un wallpaper inicial inmediatamente si feh y X están activos, o generar cache
    if [ -x "$BIN_DIR/random_wallpaper" ]; then
        run_as_user "$BIN_DIR/random_wallpaper" || true
    fi
    log_success "Colección de wallpapers lista en $WALLPAPERS_DIR."
}

# ------------------------------------------------------------------------------
# 8. POST-INSTALACIÓN Y SERVICIOS DEL SISTEMA
# ------------------------------------------------------------------------------
post_installation() {
    log_info "8. Configurando servicios del sistema, Display Manager y grupos de usuario..."

    # 1. Agregar usuario a los grupos recomendados
    log_info "Añadiendo a '$TARGET_USER' a grupos audio, video, network, storage, wheel, input..."
    run_as_root usermod -aG audio,video,network,storage,wheel,input "$TARGET_USER" || true

    # 2. Habilitar NetworkManager & Bluetooth
    log_info "Habilitando servicio NetworkManager..."
    run_as_root systemctl enable NetworkManager --now || true
    log_info "Habilitando servicio Bluetooth..."
    run_as_root systemctl enable bluetooth --now 2>/dev/null || true

    # 3. Habilitar Display Manager (SDDM)
    log_info "Habilitando Display Manager SDDM..."
    run_as_root systemctl enable sddm || true

    # Crear entrada de sesión X11 para BSPWM en SDDM si no existe
    run_as_root mkdir -p /usr/share/xsessions
    cat << 'EOF' | run_as_root tee /usr/share/xsessions/bspwm.desktop > /dev/null
[Desktop Entry]
Name=bspwm
Comment=Binary Space Partitioning Window Manager
Exec=bspwm
Type=XSession
EOF

    # 4. Servicios de audio Pipewire a nivel de usuario
    log_info "Habilitando servicios de usuario para Pipewire & Wireplumber..."
    run_as_user systemctl --user enable pipewire wireplumber pipewire-pulse 2>/dev/null || true

    log_success "Servicios y configuraciones del sistema completados con éxito."
}

# ------------------------------------------------------------------------------
# 9. RESUMEN FINAL Y FINALIZACIÓN
# ------------------------------------------------------------------------------
finish_installation() {
    clear
    echo -e "${CLR_GREEN}${CLR_BOLD}"
    cat << "EOF"
  _   _ _____ _     _     ___     ____  _   _  ____ ____ _____ ____ ____  
 | | | | ____| |   | |   / _ \   / ___|| | | |/ ___/ ___| ____/ ___/ ___| 
 | |_| |  _| | |   | |  | | | |  \___ \| | | | |  | |   |  _| \___ \___ \ 
 |  _  | |___| |___| |___ |_| |   ___) | |_| | |__| |___| |___ ___) |__) |
 |_| |_|_____|_____|_____|\___/  |____/ \___/ \____\____|_____|____/____/  
EOF
    echo -e "${CLR_RESET}"
    echo -e "${CLR_BLUE}==============================================================================${CLR_RESET}"
    echo -e "${CLR_GREEN} ✓ INSTALACIÓN Y CONFIGURACIÓN DE BSPWM COMPLETADA CON ÉXITO${CLR_RESET}"
    echo -e "${CLR_BLUE}==============================================================================${CLR_RESET}"
    echo -e "${CLR_CYAN}Resumen de Componentes Instalados y Configurados:${CLR_RESET}"
    echo -e " • ${CLR_MAUVE}Window Manager:${CLR_RESET}   bspwm + sxhkd (Catppuccin Mocha border & gap rules)"
    echo -e " • ${CLR_MAUVE}Barra de Estado:${CLR_RESET}   Polybar (Multi-monitor + selector de temas)"
    echo -e " • ${CLR_MAUVE}Lanzador:${CLR_RESET}          Rofi (drun, run, window con tema Catppuccin)"
    echo -e " • ${CLR_MAUVE}Compositor:${CLR_RESET}        Picom (Bordes redondeados, sombras y transparencia)"
    echo -e " • ${CLR_MAUVE}Terminal:${CLR_RESET}          Kitty (JetBrains Mono Nerd Font 12px + Mocha)"
    echo -e " • ${CLR_MAUVE}Notificaciones:${CLR_RESET}    Dunst (Notificaciones estéticas)"
    echo -e " • ${CLR_MAUVE}Display Manager:${CLR_RESET}   SDDM (Inicia automáticamente al reiniciar)"
    echo -e " • ${CLR_MAUVE}Wallpapers:${CLR_RESET}        Colección dharmx/walls en ~/Pictures/wallpapers/"
    echo ""
    echo -e "${CLR_CYAN}Atajos de Teclado Principales:${CLR_RESET}"
    echo -e " • ${CLR_YELLOW}Super + Enter${CLR_RESET}        -> Abrir Terminal Kitty"
    echo -e " • ${CLR_YELLOW}Super + d${CLR_RESET}            -> Lanzador de aplicaciones Rofi"
    echo -e " • ${CLR_YELLOW}Super + q${CLR_RESET}            -> Cerrar ventana activa"
    echo -e " • ${CLR_YELLOW}Super + {1-4}${CLR_RESET}        -> Cambiar de escritorio (Workspaces)"
    echo -e " • ${CLR_YELLOW}Super + Shift + {1-4}${CLR_RESET}-> Mover ventana a escritorio"
    echo -e " • ${CLR_YELLOW}Super + {h,j,k,l}${CLR_RESET}    -> Navegar entre ventanas (Vim keys)"
    echo -e " • ${CLR_YELLOW}Super + p${CLR_RESET}            -> Selector de estilos de Polybar"
    echo -e " • ${CLR_YELLOW}Super + b${CLR_RESET}            -> Cambiar fondo de pantalla al azar"
    echo -e " • ${CLR_YELLOW}Print / Super+Print${CLR_RESET}  -> Capturas de pantalla con Scrot"
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
    install_optional_packages
    setup_directories_and_backup
    configure_bspwm
    configure_sxhkd
    configure_polybar
    configure_picom
    configure_dunst
    configure_kitty
    configure_rofi
    configure_gtk
    configure_xinit_and_xresources
    configure_fastfetch
    configure_neovim
    configure_shell
    configure_cava
    setup_rices_engine
    setup_productivity_scripts
    setup_custom_scripts
    download_wallpapers
    post_installation
    fix_permissions
    finish_installation
}

main "$@"
