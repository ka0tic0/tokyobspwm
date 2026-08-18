#!/bin/bash

# =========================================================================
# Script de Instalación Automatizada - BSPWM + Tokyonight (Arch Linux)
# =========================================================================

set -e # Detener si hay un error crítico

# Colores terminal
C_DEF="\033[0m"
C_GREEN="\033[0;32m"
C_YELLOW="\033[0;33m"
C_RED="\033[0;31m"
C_BLUE="\033[0;34m"
C_CYAN="\033[0;36m"

msg_ok() { echo -e "${C_GREEN}[✓] $1${C_DEF}"; }
msg_warn() { echo -e "${C_YELLOW}[!] $1${C_DEF}"; }
msg_err() { echo -e "${C_RED}[✗] $1${C_DEF}"; }
msg_info() { echo -e "${C_CYAN}[i] $1${C_DEF}"; }

# Verificación de usuario (no ejecutar como root)
if [ "$EUID" -eq 0 ]; then
  msg_err "Por favor, NO ejecutes este script como root. Ejecútalo como usuario normal con permisos sudo."
  msg_info "yay y la configuración del entorno de usuario fallarán si se ejecutan como root."
  exit 1
fi

# Verificar conexión a internet
msg_info "Verificando conexión a internet..."
if ! ping -c 1 archlinux.org &> /dev/null; then
  msg_err "No hay conexión a internet. Abortando."
  exit 1
fi
msg_ok "Conexión a internet verificada."

# Backup de configuraciones
backup_config() {
  local dir=$1
  if [ -d "$HOME/.config/$dir" ]; then
    msg_warn "Respaldando configuración existente de $dir..."
    mv "$HOME/.config/$dir" "$HOME/.config/${dir}.backup.$(date +%Y%m%d%H%M%S)"
  fi
}

# ---------------------------------------------------------
# Funciones de Instalación
# ---------------------------------------------------------

update_system() {
  msg_info "Actualizando el sistema..."
  sudo pacman -Syu --noconfirm || { msg_err "Fallo al actualizar el sistema"; exit 1; }
  msg_ok "Sistema actualizado."
}

install_yay() {
  if ! command -v yay &> /dev/null; then
    msg_info "Instalando yay (AUR helper)..."
    sudo pacman -S --needed --noconfirm git base-devel
    rm -rf /tmp/yay
    git clone --depth 1 https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    cd - > /dev/null
    rm -rf /tmp/yay
    msg_ok "yay instalado."
  else
    msg_ok "yay ya está instalado."
  fi
}

install_packages() {
  msg_info "Instalando paquetes principales desde pacman..."
  
  local packages=(
    # Servidor X y BSPWM
    xorg-server xorg-xinit xorg-xrandr xorg-xsetroot
    bspwm sxhkd
    # Terminal, Barra, Lanzador, Compositor, Notificaciones, Bloqueo
    kitty rofi picom dunst i3lock
    # Multimedia, Archivos, Red
    feh thunar thunar-volman thunar-archive-plugin
    networkmanager network-manager-applet
    pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol
    # Fuentes y Utilidades
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji ttf-font-awesome ttf-nerd-fonts-symbols
    lxappearance git curl wget unzip scrot jq imagemagick
    # Display Manager
    sddm
  )

  sudo pacman -S --needed --noconfirm "${packages[@]}"
  msg_ok "Paquetes principales instalados."
}

install_optional() {
  msg_info "Instalación de paquetes opcionales desde AUR..."
  read -p "¿Deseas instalar paquetes opcionales de AUR (brave-bin, neovim, htop, fastfetch, tokyonight-gtk-theme-git, tela-circle-icon-theme-nord)? [S/n]: " opt_install
  if [[ "$opt_install" =~ ^[Ss]$ ]] || [[ -z "$opt_install" ]]; then
    msg_info "Instalando paquetes opcionales (esto puede tomar unos minutos)..."
    yay -S --needed --noconfirm --answerclean=None --answerdiff=None --noeditmenu --nodiffmenu \
      brave-bin neovim htop fastfetch tokyonight-gtk-theme-git tela-circle-icon-theme-nord || msg_warn "Algunos paquetes opcionales fallaron al instalarse, continuando."
    msg_ok "Fase de paquetes opcionales terminada."
  else
    msg_info "Saltando paquetes opcionales."
  fi
}

# ---------------------------------------------------------
# Funciones de Configuración
# ---------------------------------------------------------

configure_dirs() {
  msg_info "Creando estructura de directorios..."
  mkdir -p ~/.config/{bspwm,sxhkd,polybar,picom,dunst,rofi,kitty,gtk-3.0,gtk-4.0}
  mkdir -p ~/.local/bin
  xdg-user-dirs-update || msg_warn "xdg-user-dirs no instalado o falló, omitiendo."
  msg_ok "Directorios creados."
}

configure_bspwm() {
  msg_info "Configurando BSPWM..."
  backup_config "bspwm"
  mkdir -p ~/.config/bspwm
  
  cat > ~/.config/bspwm/bspwmrc << 'EOF'
#!/bin/bash

# Autostart
sxhkd &
picom --config ~/.config/picom/picom.conf &
~/.local/bin/launch_polybar &
dunst &
nm-applet &
~/.local/bin/set_random_wallpaper &
~/.local/bin/auto_wallpaper_daemon &
xsetroot -cursor_name left_ptr &

# Monitores
bspc monitor -d 1 2 3 4

# Reglas de ventanas
bspc config border_width         2
bspc config window_gap          10
bspc config split_ratio          0.52
bspc config borderless_monocle   true
bspc config gapless_monocle      true

# Colores Tokyonight
bspc config normal_border_color  "#1a1b26"
bspc config active_border_color  "#414868"
bspc config focused_border_color "#7aa2f7"
bspc config presel_feedback_color "#bb9af7"

# Reglas específicas
bspc rule -a Rofi state=floating center=true
bspc rule -a Thunar state=floating center=true
bspc rule -a Pavucontrol state=floating center=true
bspc rule -a Lxappearance state=floating center=true
EOF
  chmod +x ~/.config/bspwm/bspwmrc
  msg_ok "BSPWM configurado."
}

configure_sxhkd() {
  msg_info "Configurando SXHKD..."
  backup_config "sxhkd"
  mkdir -p ~/.config/sxhkd
  
  cat > ~/.config/sxhkd/sxhkdrc << 'EOF'
# Lanzar Terminal
super + Return
	kitty

# Rofi Control Hub (Menú Principal con todas las opciones)
super + a
	~/.local/bin/rofi_hub

# Lanzadores Rofi Tradicionales
super + space
	rofi -show drun -theme ~/.config/rofi/config.rasi

super + r
	rofi -show run -theme ~/.config/rofi/config.rasi

super + w
	rofi -show window -theme ~/.config/rofi/config.rasi

# Menu de Apagado / Bloqueo en Rofi
super + x
	~/.local/bin/powermenu

# Seleccionar Wallpaper mediante Rofi
super + shift + w
	~/.local/bin/rofi_wallpaper_select

# Cambiar Wallpaper aleatorio
super + ctrl + w
	~/.local/bin/set_random_wallpaper

# Cambiar Tema de Polybar mediante Rofi
super + shift + p
	~/.local/bin/polybar_theme_select

# Bloquear pantalla
super + alt + l
	i3lock -c 1a1b26

super + Escape
	pkill -USR1 -x sxhkd

# BSPWM - Ventanas
super + q
	bspc node -c

super + shift + r
	bspc wm -r

super + m
	bspc desktop -l next

super + t
	bspc node -t tiled

super + shift + t
	bspc node -t pseudo_tiled

super + f
	bspc node -t fullscreen

super + shift + f
	bspc node -t floating

# Vim keys para mover foco
super + {h,j,k,l}
	bspc node -f {west,south,north,east}

# Vim keys para mover ventana
super + shift + {h,j,k,l}
	bspc node -m {west,south,north,east}

# Escritorios
super + {1-4}
	bspc desktop -f '^{1-4}'

super + shift + {1-4}
	bspc node -d '^{1-4}' -f

# Ajustar Gaps
super + ctrl + h
	bspc config -d focused window_gap $(( $(bspc config -d focused window_gap) - 2 ))
super + ctrl + l
	bspc config -d focused window_gap $(( $(bspc config -d focused window_gap) + 2 ))

# Controles Multimedia
XF86AudioRaiseVolume
	pactl set-sink-volume @DEFAULT_SINK@ +5%
XF86AudioLowerVolume
	pactl set-sink-volume @DEFAULT_SINK@ -5%
XF86AudioMute
	pactl set-sink-mute @DEFAULT_SINK@ toggle

# Captura de pantalla
Print
	scrot '%Y-%m-%d-%H%M%S_screenshot.png' -e 'mv $f ~/Pictures/'
EOF
  msg_ok "SXHKD configurado."
}

configure_rofi() {
  msg_info "Configurando Tema Estético de Rofi..."
  backup_config "rofi"
  mkdir -p ~/.config/rofi
  
  cat > ~/.config/rofi/config.rasi << 'EOF'
configuration {
    modi: "drun,run,window";
    font: "JetBrains Mono Nerd Font 11";
    show-icons: true;
    icon-theme: "Tela-circle-nord";
    display-drun: " ";
    display-run: " ";
    display-window: " ";
    drun-display-format: "{name}";
}

* {
    bg-col:  #1a1b26;
    bg-col-light: #24283b;
    border-col: #7aa2f7;
    selected-col: #414868;
    blue: #7aa2f7;
    fg-col: #c0caf5;
    fg-col2: #f7768e;
    grey: #565f89;

    width: 600;
    font: "JetBrains Mono Nerd Font 11";
}

element-text, element-icon , case-indicator {
    background-color: inherit;
    text-color:       inherit;
}

window {
    height: 380px;
    border: 2px;
    border-color: @border-col;
    background-color: @bg-col;
    border-radius: 12px;
}

mainbox {
    background-color: @bg-col;
}

inputbar {
    children: [prompt,entry];
    background-color: @bg-col-light;
    border-radius: 8px;
    margin: 20px 20px 0px 20px;
    padding: 2px;
}

prompt {
    background-color: @blue;
    padding: 6px;
    text-color: @bg-col;
    border-radius: 6px;
    margin: 8px 0px 8px 8px;
}

textbox-prompt-colon {
    expand: false;
    str: ":";
}

entry {
    padding: 6px;
    margin: 8px 0px 8px 8px;
    text-color: @fg-col;
    background-color: @bg-col-light;
}

listview {
    border: 0px 0px 0px;
    padding: 6px 0px 0px;
    margin: 10px 20px 20px 20px;
    columns: 2;
    lines: 5;
    background-color: @bg-col;
}

element {
    padding: 8px;
    background-color: @bg-col;
    text-color: @fg-col  ;
    border-radius: 8px;
}

element-icon {
    size: 24px;
}

element selected {
    background-color:  @selected-col ;
    text-color: @blue  ;
}
EOF
  msg_ok "Rofi configurado."
}

configure_picom() {
  msg_info "Configurando Picom..."
  backup_config "picom"
  mkdir -p ~/.config/picom
  
  cat > ~/.config/picom/picom.conf << 'EOF'
backend = "glx";
vsync = true;
glx-no-stencil = true;
glx-copy-from-front = false;

# Sombras
shadow = true;
shadow-radius = 7;
shadow-offset-x = -7;
shadow-offset-y = -7;
shadow-opacity = 0.5;
shadow-exclude = [
  "name = 'Notification'",
  "class_g = 'Conky'",
  "class_g ?= 'Notify-osd'",
  "class_g = 'Cairo-clock'",
  "_GTK_FRAME_EXTENTS@:c"
];

# Opacidad
active-opacity = 1.0;
inactive-opacity = 0.8;
frame-opacity = 1.0;
inactive-opacity-override = false;
opacity-rule = [
  "85:class_g = 'kitty' && focused",
  "75:class_g = 'kitty' && !focused",
  "90:class_g = 'Rofi'"
];

# Esquinas redondeadas
corner-radius = 10;
rounded-corners-exclude = [
  "window_type = 'dock'",
  "window_type = 'desktop'"
];

# Fading
fading = true;
fade-in-step = 0.03;
fade-out-step = 0.03;
fade-delta = 4;
EOF
  msg_ok "Picom configurado."
}

configure_dunst() {
  msg_info "Configurando Dunst..."
  backup_config "dunst"
  mkdir -p ~/.config/dunst
  
  cat > ~/.config/dunst/dunstrc << 'EOF'
[global]
    monitor = 0
    follow = mouse
    width = 300
    height = 100
    origin = top-right
    offset = 10x40
    scale = 0
    notification_limit = 0
    progress_bar = true
    progress_bar_height = 10
    progress_bar_frame_width = 1
    progress_bar_min_width = 150
    progress_bar_max_width = 300
    indicate_hidden = yes
    transparency = 20
    separator_height = 2
    padding = 15
    horizontal_padding = 15
    text_icon_padding = 0
    frame_width = 2
    frame_color = "#7aa2f7"
    gap_size = 10
    separator_color = frame
    sort = yes
    idle_threshold = 120
    font = JetBrains Mono Nerd Font 11
    line_height = 0
    markup = full
    format = "<b>%s</b>\n%b"
    alignment = left
    vertical_alignment = center
    show_age_threshold = 60
    word_wrap = yes
    ellipsize = middle
    ignore_newline = no
    stack_duplicates = true
    hide_duplicate_count = false
    show_indicators = yes
    icon_position = left
    min_icon_size = 0
    max_icon_size = 64
    sticky_history = yes
    history_length = 20
    dmenu = /usr/bin/dmenu -p dunst:
    browser = /usr/bin/xdg-open
    always_run_script = true
    title = Dunst
    class = Dunst
    corner_radius = 10
    ignore_dbusclose = false

[urgency_low]
    background = "#1a1b26"
    foreground = "#c0caf5"
    frame_color = "#7aa2f7"
    timeout = 10

[urgency_normal]
    background = "#1a1b26"
    foreground = "#c0caf5"
    frame_color = "#7aa2f7"
    timeout = 10

[urgency_critical]
    background = "#1a1b26"
    foreground = "#c0caf5"
    frame_color = "#f7768e"
    timeout = 0
EOF
  msg_ok "Dunst configurado."
}

configure_kitty() {
  msg_info "Configurando Kitty..."
  backup_config "kitty"
  mkdir -p ~/.config/kitty
  
  cat > ~/.config/kitty/kitty.conf << 'EOF'
font_family      JetBrains Mono Nerd Font
bold_font        auto
italic_font      auto
bold_italic_font auto
font_size 12.0

background_opacity 0.85
scrollback_lines 10000
mouse_hide_wait 3.0
window_padding_width 10
confirm_os_window_close 0

# Tokyonight Colors
foreground #c0caf5
background #1a1b26
selection_foreground #c0caf5
selection_background #33467c

cursor #c0caf5
cursor_text_color #1a1b26

url_color #7aa2f7

active_border_color #7aa2f7
inactive_border_color #292e42
bell_border_color #e0af68

# black
color0 #15161e
color8 #414868
# red
color1 #f7768e
color9 #f7768e
# green
color2 #9ece6a
color10 #9ece6a
# yellow
color3 #e0af68
color11 #e0af68
# blue
color4 #7aa2f7
color12 #7aa2f7
# magenta
color5 #bb9af7
color13 #bb9af7
# cyan
color6 #7dcfff
color14 #7dcfff
# white
color7 #a9b1d6
color15 #c0caf5
EOF
  msg_ok "Kitty configurado."
}

configure_polybar() {
  msg_info "Configurando Polybar y sus 4 temas (Tokyo, Osaka, Yokohama, Nikko)..."
  backup_config "polybar"
  
  # Clonar el repo solicitado
  if [ -d "/tmp/Polybar-khanhas" ]; then
    rm -rf /tmp/Polybar-khanhas
  fi
  git clone --depth 1 https://github.com/khanhas/Polybar.git /tmp/Polybar-khanhas || true
  
  mkdir -p ~/.config/polybar/themes/{tokyo,osaka,yokohama,nikko}

  # Plantilla base para temas
  generate_polybar_theme() {
    local theme_name=$1
    local primary_color=$2
    local secondary_color=$3
    local bg_color=$4
    local dest_file=$5

    cat > "$dest_file" << EOF
[colors]
background = ${bg_color}
background-alt = #24283b
foreground = #c0caf5
primary = ${primary_color}
secondary = ${secondary_color}
alert = #f7768e
disabled = #565f89
green = #9ece6a
yellow = #e0af68

[bar/main]
width = 100%
height = 30pt
radius = 0
background = \${colors.background}
foreground = \${colors.foreground}
line-size = 3pt
border-size = 4pt
border-color = #00000000
padding-left = 0
padding-right = 1
module-margin = 1
separator = |
separator-foreground = \${colors.disabled}

font-0 = JetBrains Mono Nerd Font:size=11;2
font-1 = FontAwesome:size=11;2

modules-left = xworkspaces xwindow
modules-right = filesystem pulseaudio memory cpu battery network date

cursor-click = pointer
cursor-scroll = ns-resize
enable-ipc = true
wm-restack = bspwm

[module/xworkspaces]
type = internal/xworkspaces
label-active = %icon% %name%
label-active-background = \${colors.background-alt}
label-active-underline= \${colors.primary}
label-active-padding = 1
label-occupied = %icon% %name%
label-occupied-padding = 1
label-urgent = %icon% %name%
label-urgent-background = \${colors.alert}
label-urgent-padding = 1
label-empty = %icon% %name%
label-empty-foreground = \${colors.disabled}
label-empty-padding = 1

# Iconos con workspaces
icon-0 = 1;
icon-1 = 2;
icon-2 = 3;
icon-3 = 4;
icon-default = 
format = <label-state>

[module/xwindow]
type = internal/xwindow
label = %title:0:50:...%

[module/filesystem]
type = internal/fs
interval = 25
mount-0 = /
label-mounted = %{F${primary_color}}%{F-} %percentage_used%%
label-unmounted = %mountpoint% not mounted

[module/pulseaudio]
type = internal/pulseaudio
format-volume-prefix = " "
format-volume-prefix-foreground = \${colors.primary}
format-volume = <label-volume>
label-volume = %percentage%%
label-muted =  muted
label-muted-foreground = \${colors.disabled}

[module/memory]
type = internal/memory
interval = 2
format-prefix = " "
format-prefix-foreground = \${colors.primary}
label = %percentage_used:2%%

[module/cpu]
type = internal/cpu
interval = 2
format-prefix = " "
format-prefix-foreground = \${colors.primary}
label = %percentage:2%%

[module/network]
type = internal/network
interface-type = wireless
interval = 3.0
format-connected = <label-connected>
label-connected = %{F${primary_color}}%{F-} %essid%
format-disconnected = %{F#f7768e}%{F-} disconnected

[module/battery]
type = internal/battery
full-at = 99
low-at = 15
battery = BAT0
adapter = ADP1
poll-interval = 5
format-charging = <label-charging>
label-charging = %{F#9ece6a}%{F-} %percentage%%
format-discharging = <label-discharging>
label-discharging = %{F#e0af68}%{F-} %percentage%%
label-full = %{F#9ece6a}%{F-} 100%

[module/date]
type = internal/date
interval = 1
date = %H:%M
date-alt = %Y-%m-%d %H:%M:%S
label = %date%
label-foreground = \${colors.primary}

[settings]
screenchange-reload = true
pseudo-transparency = true
EOF
  }

  # Tema 1: Tokyo (Classic Blue)
  generate_polybar_theme "Tokyo" "#7aa2f7" "#bb9af7" "#1a1b26" ~/.config/polybar/themes/tokyo/config.ini
  # Tema 2: Osaka (Cherry Blossom Pink/Magenta)
  generate_polybar_theme "Osaka" "#f7768e" "#bb9af7" "#1f1d2e" ~/.config/polybar/themes/osaka/config.ini
  # Tema 3: Yokohama (Cyan / Ocean)
  generate_polybar_theme "Yokohama" "#7dcfff" "#7aa2f7" "#16161e" ~/.config/polybar/themes/yokohama/config.ini
  # Tema 4: Nikko (Autumn Yellow / Emerald)
  generate_polybar_theme "Nikko" "#e0af68" "#9ece6a" "#1a1c23" ~/.config/polybar/themes/nikko/config.ini

  # Configuración por defecto -> Tokyo
  cp ~/.config/polybar/themes/tokyo/config.ini ~/.config/polybar/config.ini

  msg_ok "Polybar configurado con temas Tokyo, Osaka, Yokohama y Nikko."
}

configure_gtk() {
  msg_info "Configurando temas GTK..."
  mkdir -p ~/.config/gtk-3.0 ~/.config/gtk-4.0

  local gtk_settings="[Settings]
gtk-theme-name=Tokyonight-Dark-B
gtk-icon-theme-name=Tela-circle-nord
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
gtk-xft-hintstyle=hintmedium
gtk-xft-rgba=rgb
gtk-application-prefer-dark-theme=1"

  echo "$gtk_settings" > ~/.config/gtk-3.0/settings.ini
  echo "$gtk_settings" > ~/.config/gtk-4.0/settings.ini
  
  # .Xresources
  cat > ~/.Xresources << 'EOF'
*background: #1a1b26
*foreground: #c0caf5
*color0:     #15161e
*color1:     #f7768e
*color2:     #9ece6a
*color3:     #e0af68
*color4:     #7aa2f7
*color5:     #bb9af7
*color6:     #7dcfff
*color7:     #a9b1d6
*color8:     #414868
*color9:     #f7768e
*color10:    #9ece6a
*color11:    #e0af68
*color12:    #7aa2f7
*color13:    #bb9af7
*color14:    #7dcfff
*color15:    #c0caf5
EOF
  xrdb -merge ~/.Xresources || true
  msg_ok "GTK configurado."
}

setup_scripts() {
  msg_info "Configurando scripts personalizados (Rofi Hub, Rofi Wallpaper Selector, PowerMenu, Polybar Theme Selector, Auto Wallpaper)..."
  
  # 1. Script Launch Polybar
  cat > ~/.local/bin/launch_polybar << 'EOF'
#!/usr/bin/env bash
killall -q polybar
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done
if type "xrandr"; then
  for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
    MONITOR=$m polybar --reload main -c ~/.config/polybar/config.ini &
  done
else
  polybar --reload main -c ~/.config/polybar/config.ini &
fi
EOF
  chmod +x ~/.local/bin/launch_polybar

  # 2. Script Statusbar Launcher
  cat > ~/.local/bin/statusbar_launcher << 'EOF'
#!/bin/bash
~/.local/bin/launch_polybar &
EOF
  chmod +x ~/.local/bin/statusbar_launcher

  # 3. Script Powermenu (Rofi)
  cat > ~/.local/bin/powermenu << 'EOF'
#!/bin/bash

lock="🔒 Bloquear Pantalla"
logout="🚪 Cerrar Sesión"
suspend="💤 Suspender"
reboot="🔄 Reiniciar"
shutdown=" Apagar"

options="$lock\n$logout\n$suspend\n$reboot\n$shutdown"

chosen=$(echo -e "$options" | rofi -dmenu -i -p "Power Menu" -theme-str 'window {width: 280px; height: 260px;} listview {columns: 1; lines: 5;}')

case "$chosen" in
    "$lock")
        i3lock -c 1a1b26
        ;;
    "$logout")
        bspc quit
        ;;
    "$suspend")
        systemctl suspend
        ;;
    "$reboot")
        systemctl reboot
        ;;
    "$shutdown")
        systemctl poweroff
        ;;
esac
EOF
  chmod +x ~/.local/bin/powermenu

  # 4. Script Selector de Temas Polybar en Rofi
  cat > ~/.local/bin/polybar_theme_select << 'EOF'
#!/bin/bash

themes="Tokyo\nOsaka\nYokohama\nNikko"

chosen=$(echo -e "$themes" | rofi -dmenu -i -p "Tema Polybar" -theme-str 'window {width: 300px; height: 220px;} listview {columns: 1; lines: 4;}')

if [ -n "$chosen" ]; then
    theme_lower=$(echo "$chosen" | tr '[:upper:]' '[:lower:]')
    if [ -f "$HOME/.config/polybar/themes/$theme_lower/config.ini" ]; then
        cp "$HOME/.config/polybar/themes/$theme_lower/config.ini" "$HOME/.config/polybar/config.ini"
        ~/.local/bin/launch_polybar
        dunstify -i dialog-information "Polybar" "Tema activo: $chosen" 2>/dev/null || true
    fi
fi
EOF
  chmod +x ~/.local/bin/polybar_theme_select

  # 5. Script Selector de Wallpapers en Rofi
  cat > ~/.local/bin/rofi_wallpaper_select << 'EOF'
#!/bin/bash

WALL_DIR="$HOME/Pictures/wallpapers"

if [ ! -d "$WALL_DIR" ]; then
  dunstify -i dialog-warning "Wallpapers" "No existe la carpeta $WALL_DIR" 2>/dev/null || true
  exit 1
fi

# Listar imágenes
selected=$(find "$WALL_DIR" -type f \( -name '*.jpg' -o -name '*.png' -o -name '*.jpeg' \) -exec basename {} \; | sort | rofi -dmenu -i -p "Seleccionar Wallpaper" -theme-str 'window {width: 450px; height: 350px;} listview {columns: 1; lines: 7;}')

if [ -n "$selected" ]; then
    FULL_PATH=$(find "$WALL_DIR" -type f -name "$selected" | head -n 1)
    if [ -n "$FULL_PATH" ]; then
        feh --bg-fill "$FULL_PATH"
        dunstify -i dialog-information "Wallpaper" "Fondo de pantalla actualizado" 2>/dev/null || true
    fi
fi
EOF
  chmod +x ~/.local/bin/rofi_wallpaper_select

  # 6. Rofi Control Hub (Menú de Control Principal)
  cat > ~/.local/bin/rofi_hub << 'EOF'
#!/bin/bash

opt_apps="🚀 Lanzar Aplicación"
opt_poly="💈 Tema Polybar (Tokyo, Osaka...)"
opt_wall_select="🖼️ Elegir Wallpaper"
opt_wall_rand="🎲 Wallpaper Aleatorio"
opt_lock="🔒 Bloquear Pantalla"
opt_power=" Menú de Apagado"

options="$opt_apps\n$opt_poly\n$opt_wall_select\n$opt_wall_rand\n$opt_lock\n$opt_power"

chosen=$(echo -e "$options" | rofi -dmenu -i -p "Control Hub" -theme-str 'window {width: 380px; height: 300px;} listview {columns: 1; lines: 6;}')

case "$chosen" in
    "$opt_apps")
        rofi -show drun -theme ~/.config/rofi/config.rasi
        ;;
    "$opt_poly")
        ~/.local/bin/polybar_theme_select
        ;;
    "$opt_wall_select")
        ~/.local/bin/rofi_wallpaper_select
        ;;
    "$opt_wall_rand")
        ~/.local/bin/set_random_wallpaper
        dunstify -i dialog-information "Wallpaper" "Nuevo fondo aleatorio aplicado" 2>/dev/null || true
        ;;
    "$opt_lock")
        i3lock -c 1a1b26
        ;;
    "$opt_power")
        ~/.local/bin/powermenu
        ;;
esac
EOF
  chmod +x ~/.local/bin/rofi_hub

  # 7. Daemon para Cambio Automático de Wallpapers cada 15 min
  cat > ~/.local/bin/auto_wallpaper_daemon << 'EOF'
#!/bin/bash

INTERVAL=900 # 15 minutos

while true; do
  ~/.local/bin/set_random_wallpaper
  sleep $INTERVAL
done
EOF
  chmod +x ~/.local/bin/auto_wallpaper_daemon

  msg_ok "Scripts de Rofi y utilidades creados en ~/.local/bin/."
}

download_wallpaper() {
  msg_info "Descargando Wallpapers (esto puede tardar unos segundos)..."
  mkdir -p ~/Pictures/wallpapers
  if [ ! -d "/tmp/walls" ]; then
    git clone --depth 1 https://github.com/dharmx/walls.git /tmp/walls || true
  fi
  if [ -d "/tmp/walls" ]; then
    cp -r /tmp/walls/* ~/Pictures/wallpapers/ || true
    rm -rf /tmp/walls
  fi

  # Script para wallpaper aleatorio
  cat > ~/.local/bin/set_random_wallpaper << 'EOF'
#!/bin/bash
WALL_DIR="$HOME/Pictures/wallpapers"
if [ -d "$WALL_DIR" ]; then
  WALL=$(find "$WALL_DIR" -type f \( -name '*.jpg' -o -name '*.png' -o -name '*.jpeg' \) | shuf -n 1)
  if [ -n "$WALL" ]; then
    feh --bg-fill "$WALL"
  fi
fi
EOF
  chmod +x ~/.local/bin/set_random_wallpaper
  msg_ok "Wallpapers configurados."
}

post_install() {
  msg_info "Tareas de post-instalación..."
  
  # Habilitar servicios
  sudo systemctl enable NetworkManager || true
  sudo systemctl enable sddm || true
  systemctl --user enable pipewire wireplumber --now 2>/dev/null || true
  
  # Grupos de usuario
  sudo usermod -aG audio,video,network,storage,wheel $USER || true

  # Aliases en ~/.bashrc
  if ! grep -q "alias ls='ls --color=auto'" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << 'EOF'

# Aliases Personalizados
alias ls='ls --color=auto'
alias ll='ls -alF'
alias grep='grep --color=auto'
alias up='sudo pacman -Syu'
alias v='nvim'
alias hub='~/.local/bin/rofi_hub'
alias powermenu='~/.local/bin/powermenu'
alias polytheme='~/.local/bin/polybar_theme_select'
alias wallselect='~/.local/bin/rofi_wallpaper_select'
EOF
  fi

  # .xinitrc (fallback si no usa SDDM)
  cat > ~/.xinitrc << 'EOF'
exec bspwm
EOF

  msg_ok "Post-instalación completada."
}

# =========================================================================
# Flujo Principal
# =========================================================================

echo -e "${C_CYAN}"
echo "========================================================="
echo "   Instalador de Entorno BSPWM - Estética Tokyonight     "
echo "========================================================="
echo -e "${C_DEF}"

read -p "¿Deseas continuar con la actualización del sistema e instalación? [S/n]: " init_install
if [[ "$init_install" =~ ^[Nn]$ ]]; then
  msg_info "Instalación abortada por el usuario."
  exit 0
fi

update_system
install_yay
install_packages
install_optional

configure_dirs
configure_bspwm
configure_sxhkd
configure_rofi
configure_picom
configure_dunst
configure_kitty
configure_polybar
configure_gtk
setup_scripts
download_wallpaper
post_install

echo -e "\n${C_GREEN}=========================================================${C_DEF}"
echo -e "${C_GREEN}¡Instalación Completada con Éxito!${C_DEF}"
echo -e "${C_CYAN}Resumen de Rofi Hub e Integraciones:${C_DEF}"
echo " - Rofi Control Hub (Super + A): Menú central para acceder a todas las configuraciones."
echo " - Selector de Wallpapers en Rofi (Super + Shift + W): Explora y elige el fondo de pantalla en Rofi."
echo " - Selector de Temas Polybar en Rofi (Super + Shift + P): Cambia entre Tokyo, Osaka, Yokohama y Nikko."
echo " - Power Menu en Rofi (Super + X): Bloqueo, reinicio, apagado, suspender y cerrar sesión."
echo " - Wallpaper Aleatorio (Super + Ctrl + W / Daemon en segundo plano cada 15 min)."
echo -e "${C_GREEN}=========================================================${C_DEF}\n"

read -p "¿Deseas reiniciar el sistema ahora? [S/n]: " reboot_system
if [[ "$reboot_system" =~ ^[Ss]$ ]] || [[ -z "$reboot_system" ]]; then
  msg_info "Reiniciando en 3 segundos..."
  sleep 3
  sudo reboot
else
  msg_info "Puedes reiniciar más tarde manualmente."
fi
