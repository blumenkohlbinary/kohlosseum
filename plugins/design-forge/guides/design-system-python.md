# Design System Guide für design-forge (Python Desktop)

**Quellen:** `Wissen/Design System Architektur-Guide.md` (Python-Teil)
**Scope:** PyQt6, CustomTkinter, Tkinter+ttk — 3-Tier Token-Architektur für Python-Desktop-UIs
**Verwendet von:** `system-auditor` (bei Python-Projekten), `color-auditor`, `typography-auditor`
**Web-Pendant:** `design-system.md`

---

## 1. Quickstart: Die 7 kritischsten Regeln

| # | Regel | Schwellenwert | Quelle | Prüfer-Agent |
|---|-------|---------------|--------|--------------|
| 1 | 3-Tier Token-Architektur | Primitive → Semantic → Component | Matrix A #40 | system-auditor |
| 2 | Keine Hardcoded Hex in Widget-Code | Tokens via DesignTheme-Dataclass | Matrix A #42 | system-auditor |
| 3 | snake_case Naming | `color_action_primary_hover` | Matrix A #49 | system-auditor |
| 4 | Spacing-Grid | [4, 8, 12, 16, 24, 32, 48, 64] | Matrix A #41 | layout-auditor |
| 5 | Kontrast ≥4.5:1 | WCAG AA | Matrix A #1 | color-auditor |
| 6 | 5 Elevation-Level | `(offset_x, offset_y, blur, alpha)` | Matrix A #43 | system-auditor |
| 7 | Font-Scale konsistent | Display/Heading/Body/Label/Code | Matrix A #44 | typography-auditor |

---

## 2. 3-Tier Token-Architektur in Python

```python
from dataclasses import dataclass, field
from typing import Dict

# Tier 1: Primitives
@dataclass
class ColorPalette:
    blue_40: str = "#1A437C"
    blue_80: str = "#003DA5"
    neutral_0: str = "#000000"
    neutral_100: str = "#FFFFFF"
    # ... 

# Tier 2: Semantic
@dataclass
class SemanticColors:
    action_primary: str
    action_primary_hover: str
    text_primary: str
    background_default: str
    
# Tier 3: Component
@dataclass
class ButtonTokens:
    bg: str                   # → SemanticColors.action_primary
    text: str                 # → SemanticColors.text_inverse
    padding: int              # → Spacing.md
    radius: int               # → Radius.md
```

**REGEL:** Component-Tokens referenzieren NUR Semantic, niemals direkt Primitive.

---

## 3. DesignTheme Dataclass

```python
@dataclass
class DesignTheme:
    palette: ColorPalette = field(default_factory=ColorPalette)
    colors: SemanticColors = field(default_factory=_default_light_semantic)
    spacing: Spacing = field(default_factory=Spacing)
    typography: Typography = field(default_factory=Typography)
    radius: Radius = field(default_factory=Radius)
    elevation: Elevation = field(default_factory=Elevation)
    duration: Duration = field(default_factory=Duration)

    def apply_theme(self, mode: str = "light"):
        if mode == "dark":
            self.colors = _default_dark_semantic(self.palette)
        else:
            self.colors = _default_light_semantic(self.palette)
```

---

## 4. PyQt6 — QSS als Design System

### 4.1 Token-Injection in QSS

```python
def render_qss(theme: DesignTheme) -> str:
    return f"""
    QPushButton {{
        background-color: {theme.colors.action_primary};
        color: {theme.colors.text_inverse};
        padding: {theme.spacing.md}px;
        border-radius: {theme.radius.md}px;
    }}
    QPushButton:hover {{
        background-color: {theme.colors.action_primary_hover};
    }}
    QPushButton:pressed {{
        background-color: {theme.colors.action_primary_active};
    }}
    QPushButton:disabled {{
        background-color: {theme.colors.action_primary_disabled};
        color: {theme.colors.text_disabled};
    }}
    """

app.setStyleSheet(render_qss(theme))
```

### 4.2 ThemeManager für Live-Switch

```python
class ThemeManager(QObject):
    theme_changed = pyqtSignal(DesignTheme)
    
    def __init__(self, app: QApplication):
        self.app = app
        self._theme = DesignTheme()
    
    def switch_mode(self, mode: str):
        self._theme.apply_theme(mode)
        self.app.setStyleSheet(render_qss(self._theme))
        self.theme_changed.emit(self._theme)
```

---

## 5. CustomTkinter — Theme JSON-Architecture

### 5.1 Theme-JSON-Struktur

```json
{
  "CTk": {
    "fg_color": ["#F0F0F0", "#1F1F1F"]
  },
  "CTkButton": {
    "fg_color": ["#003DA5", "#1A437C"],
    "hover_color": ["#00266A", "#0C2A5A"],
    "border_width": [0, 0],
    "corner_radius": [8, 8]
  },
  "_DesignForge_Tokens": {
    "spacing": { "xs": 4, "sm": 8, "md": 16, "lg": 24, "xl": 32 },
    "elevation": [0, 1, 2, 3, 4, 5],
    "duration": { "swift": 200, "standard": 400, "slow": 600 }
  }
}
```

### 5.2 Anwendung

```python
import customtkinter as ctk

ctk.set_default_color_theme("path/to/design-forge-theme.json")
ctk.set_appearance_mode("System")  # dark/light/system
```

---

## 6. Tkinter + ttk.Style als Token-Träger

```python
import tkinter as tk
from tkinter import ttk

def apply_theme_to_ttk(root: tk.Tk, theme: DesignTheme) -> ttk.Style:
    style = ttk.Style(root)
    style.theme_use("clam")
    
    style.configure("Primary.TButton",
        background=theme.colors.action_primary,
        foreground=theme.colors.text_inverse,
        padding=(theme.spacing.md, theme.spacing.sm))
    
    style.map("Primary.TButton",
        background=[
            ("active",   theme.colors.action_primary_hover),
            ("pressed",  theme.colors.action_primary_active),
            ("disabled", theme.colors.action_primary_disabled)
        ])
    
    return style
```

---

## 7. Framework-Vergleich

| Merkmal | PyQt6 (QSS) | CustomTkinter | Tkinter + ttk.Style |
|---------|-------------|----------------|----------------------|
| Styling-Syntax | QSS (CSS-ähnlich) | JSON | Python API |
| Dark Mode | Via QSS-Regeneration | Built-in | Manuell |
| Theme-Switch zur Laufzeit | ✅ | ✅ | ✅ |
| Vector-Icons | SVG support | PIL fallback | PhotoImage |
| Token-Flexibilität | Hoch | Mittel | Hoch (manueller Aufwand) |
| Elevation/Shadow | Via drawRoundedRect | Limited | Canvas custom |

---

## 8. DesignLinter für Python-Code

Der `system-auditor` nutzt diese Regex-Patterns für Python-spezifische Checks:

| Pattern | Fix |
|---------|-----|
| `fg="#[0-9A-F]{6}"` hardcodiert | → `fg=theme.colors.action_primary` |
| `padding=\d+` Magic Number | → Spacing-Token |
| `fg="#[0-9A-F]{6}"` ohne theme-context | → ERROR |
| Fehlende `_hover`, `_active`, `_disabled` Varianten | → WARN |

Implementierung als `scripts/python_lint.py` (optional M6+).

---

## 9. Leitprinzipien

1. **DesignTheme-Dataclass als Single-Source** — alle Widgets lesen nur von `theme.*`
2. **snake_case strikt** — `color_action_primary_hover`, nicht camelCase
3. **Theme-Switch ohne Reload** — ThemeManager broadcastet Signal
4. **Elevation maschinenlesbar** — Tupel `(offset_x, offset_y, blur, alpha)` nicht Strings
5. **WCAG AA auch Desktop** — Kontrast-Regeln gelten für PyQt-UIs genauso

---

## 10. Quellenverweise

- **Primär:** `Wissen/Design System Architektur-Guide.md` §4
- **PyQt6 Docs:** https://www.riverbankcomputing.com/static/Docs/PyQt6/
- **CustomTkinter:** https://customtkinter.tomschimansky.com/
- **Regel-Index:** Plan §15 Matrix A #40-61 (3-Tier), #49 (snake_case)
