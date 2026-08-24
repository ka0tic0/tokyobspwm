 🌿 Nagasaki BSPWM - Entorno Minimalista, Estético & Modular para Arch Linux

Instalador automatizado y conjunto de utilidades nativas para configurar un entorno completo de escritorio **BSPWM** sobre **Arch Linux**, con la estética **Catppuccin Mocha**, motor de **11 Rices inspirados en ciudades japonesas**, sincronizador GTK en vivo, **Rice Editor** interactivo y **Control Center & Panel de Mantenimiento**.

---

## 📦 Componentes del Entorno

| Componente | Herramienta | Descripción |
| :--- | :--- | :--- |
| **Window Manager** | `bspwm` | Gestor de ventanas tipo mosaico (*tiling*) con gaps dinámicos y bordes personalizables. |
| **Atajos de Teclado** | `sxhkd` | Demonio de combinaciones de teclas ultrarrápido y desacoplado. |
| **Barra de Estado** | `polybar` | Barra modular multimonitor con 11 estilos intercambiables en caliente. |
| **Lanzador & Applets** | `rofi` | Menú maestro para aplicaciones, Wi-Fi, audio, archivos recientes, mantenimiento y Rices. |
| **Rice Editor** | `rice_editor` | Editor interactivo nativo para ajustar gaps, bordes, esquinas de Picom y guardar temas. |
| **Control Center** | `bspwm_tweaks` | Panel visual de mantenimiento: actualización del sistema (Pacman/AUR), limpieza y Modo Gaming. |
| **Compositor** | `picom` | Transparencias, sombras suaves y esquinas redondeadas (*rounded corners*). |
| **Terminal** | `kitty` | Terminal acelerada por GPU configurada con JetBrains Mono Nerd Font y Fastfetch. |
| **Notificaciones & OSDs** | `dunst` | Notificaciones estilo toast integradas con barras OSD gráficas de volumen y brillo. |
| **Scratchpads** | `tdrop` | Ventanas emergentes flotantes para terminal, música y calculadora. |
| **Display Manager** | `sddm` | Inicio de sesión gráfico. |
| **Audio** | `pipewire` + `wireplumber` | Servidor de sonido moderno con selección rápida de salida de audio en Rofi. |
| **Gestor de Archivos** | `thunar` | Explorador de archivos ligero con soporte de miniaturas y automount. |

---

## 🎨 Motor Multi-Rice (11 Temas Incluidos)

El entorno incluye 11 diseños de Polybar y esquemas estéticos completos que sincronizan automáticamente Polybar, Rofi y temas GTK3/4/Iconos:

1. **🌸 Tokyo Night Pills** (*Estilo Pamela*)
2. **🌇 Osaka Sunset Dock** (*Estilo Brenda*)
3. **⛩️ Kyoto Emerald Mac Island** (*Estilo Melissa*)
4. **🏙️ Yokohama Material Blocks**
5. **❄️ Nikko Nordish Badges**
6. **☕ Catppuccin Mocha Default**
7. **🧛 Dracula Dark Violet**
8. **🪵 Gruvbox Retro Gold**
9. **🔴 Hiroshima Cyber-Sunset Neon Glass**
10. **🌊 Hakata Nord Triple Island**
11. **🍁 Matsuyama Autumn Gold Glass**

---

## ⌨️ Atajos de Teclado Principales (`sxhkd`)

### 🚀 Lanzadores & Menús
| Atajo | Acción |
| :--- | :--- |
| <kbd>Super</kbd> + <kbd>Enter</kbd> | Abrir terminal **Kitty** |
| <kbd>Super</kbd> + <kbd>d</kbd> | Abrir **Menú Maestro Rofi** |
| <kbd>Super</kbd> + <kbd>p</kbd> | Selector interactivo de estilos Polybar / Rice |
| <kbd>Super</kbd> + <kbd>r</kbd> | Cambiador global de Rices (`rice_swapper`) |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>r</kbd> | **✏️ Rice Editor** (Ajustar gaps, bordes, esquinas Picom en caliente) |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>t</kbd> | **🛠️ Control Center & Tweaks** (Actualización `yay`, limpiezas, Modo Gaming) |
| <kbd>Super</kbd> + <kbd>n</kbd> | **📶 Gestor Wi-Fi Rofi** (`rofi_wifi_menu`) |
| <kbd>Super</kbd> + <kbd>i</kbd> | **📊 Información del Sistema Rofi** (RAM, CPU, Disco, IP, Uptime) |
| <kbd>Super</kbd> + <kbd>f</kbd> | **📁 Archivos Recientes y Descargas** (`rofi_recent_files`) |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>n</kbd> | **🌙 Modo Noche** (Activar/Desactivar filtro cálido 4500K) |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>l</kbd> | **🔒 Bloqueo de Pantalla con Desenfoque** (`blur_lock`) |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>p</kbd> | **🔋 Perfiles de Energía** (Rendimiento / Equilibrado / Ahorro) |

### 📌 Scratchpads Flotantes
| Atajo | Acción |
| :--- | :--- |
| <kbd>Super</kbd> + <kbd>u</kbd> | Terminal flotante emergente |
| <kbd>Super</kbd> + <kbd>m</kbd> | Reproductor de Música / Cava |
| <kbd>Super</kbd> + <kbd>c</kbd> | Calculadora rápida |

### 🪟 Control de Ventanas & Workspaces
| Atajo | Acción |
| :--- | :--- |
| <kbd>Super</kbd> + <kbd>q</kbd> | Cerrar ventana activa |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>q</kbd> | Forzar cierre de ventana |
| <kbd>Super</kbd> + <kbd>h, j, k, l</kbd> | Mover el foco entre ventanas (estilo Vim) |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>h, j, k, l</kbd> | Mover la posición de la ventana activa |
| <kbd>Super</kbd> + <kbd>t</kbd> / <kbd>m</kbd> / <kbd>f</kbd> | Cambiar layout: *Tiled* / *Monocle* / *Fullscreen* |
| <kbd>Super</kbd> + <kbd>Espacio</kbd> | Alternar estado flotante |
| <kbd>Super</kbd> + <kbd>1-4</kbd> | Cambiar al escritorio 1, 2, 3 o 4 |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>1-4</kbd> | Mover ventana al escritorio 1, 2, 3 o 4 |

### 🔊 Multimedia, Brillo & Capturas
| Atajo | Acción |
| :--- | :--- |
| <kbd>Print</kbd> | **📸 Captura de Pantalla interactiva** (Completa / Área / Ventana) con auto-copia al portapapeles |
| <kbd>Teclas de Volumen</kbd> | Subir / Bajar / Silenciar volumen con **OSD gráfico animado** |
| <kbd>Teclas de Brillo</kbd> | Subir / Bajar brillo de pantalla con **OSD gráfico animado** |

---

## 🛠️ Herramientas Exclusivas Incluidas en `~/.local/bin/`

- **`rice_editor`**: Permite cambiar los gaps de las ventanas, ancho y color de bordes, redondeado de Picom y wallpaper del Rice en caliente.
- **`bspwm_tweaks`**: Panel de control para actualizar todo el sistema (Pacman + AUR), vaciar cachés de pacman y usuario, eliminar huérfanos y alternar el compositor para juegos.
- **`rofi_wifi_menu`**: Escanea y conecta a redes Wi-Fi de forma nativa desde Rofi.
- **`rofi_system_info`**: Reporte visual instantáneo del uso de recursos del sistema.
- **`night_mode`**: Filtro cálido de pantalla para proteger la vista por las noches.
- **`shot_tool`**: Capturador de pantalla integrado con `maim`/`scrot` y `xclip`.

---

## 🚀 Instalación

1. Clona este repositorio en tu sistema:
   ```bash
   git clone https://github.com/tu-usuario/BspwmArch.git
   cd BspwmArch
   ```

2. Haz ejecutable el script principal e inícialo:
   ```bash
   chmod +x nagasakibspwm.sh
   ./nagasakibspwm.sh
   ```

### 💡 Banderas CLI disponibles:
```bash
./nagasakibspwm.sh --help       # Muestra las opciones disponibles
```
