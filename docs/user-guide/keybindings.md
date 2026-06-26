# Keybindings

Touchstone uses a dedicated WezTerm configuration with keybindings for pane navigation, resizing, and management. These bindings are active in every Touchstone window.

## Pane Navigation

| Shortcut | Action |
|----------|--------|
| `Ctrl+1` | Jump to execution pane (top) |
| `Ctrl+2` | Jump to code review pane (middle) |
| `Ctrl+3` | Jump to inspector pane (bottom) |
| `Alt+Up` | Move focus to pane above |
| `Alt+Down` | Move focus to pane below |
| `Alt+Left` | Move focus to pane left |
| `Alt+Right` | Move focus to pane right |

`Ctrl+1/2/3` is the fastest way to switch between the three Touchstone panes. `Alt+Arrow` works directionally if you have created additional panes manually.

Mouse click also focuses a pane (pane focus follows mouse is enabled).

## Pane Resizing

| Shortcut | Action |
|----------|--------|
| `Ctrl+Shift+Up` | Grow pane upward (3 rows) |
| `Ctrl+Shift+Down` | Grow pane downward (3 rows) |
| `Ctrl+Shift+Left` | Grow pane leftward (3 columns) |
| `Ctrl+Shift+Right` | Grow pane rightward (3 columns) |

Each press resizes by 3 units. Hold the keys to resize continuously.

## Pane Zoom

| Shortcut | Action |
|----------|--------|
| `Ctrl+Shift+X` | Toggle zoom on current pane |

Zooming maximizes the current pane to fill the entire window. Press again to restore the three-pane layout. Useful for reading long scripts in the code review pane or scrolling through output in the execution pane.

## Scrollback

| Shortcut | Action |
|----------|--------|
| `Shift+PageUp` | Scroll up one page |
| `Shift+PageDown` | Scroll down one page |

Scrollback works in all panes. In the code review pane, `less` handles its own scrolling (arrow keys, Page Up/Down, `g`/`G`).

## Pane Management

| Shortcut | Action |
|----------|--------|
| `Ctrl+Shift+O` | Split pane horizontally (side by side) |
| `Ctrl+Shift+E` | Split pane vertically (top and bottom) |
| `Ctrl+Shift+W` | Close current pane |

These are available if you want to create additional panes beyond the default three. Touchstone creates and destroys its three panes automatically -- you typically do not need these.

## Quick Reference

```
Ctrl+1          -> Execution pane
Ctrl+2          -> Code review pane
Ctrl+3          -> Inspector pane
Alt+Arrow       -> Navigate between panes
Ctrl+Shift+Arrow -> Resize pane
Ctrl+Shift+X    -> Zoom/unzoom pane
Shift+PageUp    -> Scroll up
Shift+PageDown  -> Scroll down
Ctrl+Shift+O    -> Split horizontal
Ctrl+Shift+E    -> Split vertical
Ctrl+Shift+W    -> Close pane
```
