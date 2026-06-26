# Prerequisites

Before installing Touchstone, ensure you have the following dependencies available on your system.

## Required

### WezTerm Terminal Emulator

Touchstone uses WezTerm's multiplexing API to create the three-pane consent window (execution / code review / inspector). WezTerm is available on Linux, macOS, and Windows.

- **Homepage:** [https://wezterm.org](https://wezterm.org)
- **Minimum version:** 20240203 or later

### PAM (Pluggable Authentication Modules)

PAM is standard on virtually all Linux distributions and is used by Touchstone to authenticate the user before granting privileged access to an AI agent. No additional PAM installation is typically required -- the development headers are needed only at build time.

## Optional

### FIDO2 / YubiKey Hardware Authentication

For hardware-bound consent (recommended), you need:

- A FIDO2-compatible security key (YubiKey 5 series, SoloKeys, etc.)
- `pam_u2f` -- PAM module for U2F/FIDO2 authentication
- `libfido2` -- FIDO2 client library

Without a hardware key, Touchstone falls back to password-only authentication.

### NixOS Flake

If you are on NixOS, the Touchstone flake handles all dependencies automatically. See [installation.md](installation.md) for details.

---

## Distro-Specific Install Commands

### Ubuntu / Debian

```bash
# WezTerm (via official APT repo)
curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /etc/apt/keyrings/wezterm-fury.gpg
echo 'deb [signed-by=/etc/apt/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list
sudo apt update
sudo apt install wezterm

# PAM development headers (build-time only)
sudo apt install libpam0g-dev

# Optional: FIDO2 / YubiKey support
sudo apt install libpam-u2f libfido2-dev
```

### Fedora

```bash
# WezTerm (via COPR or Flatpak -- see wezterm.org for current instructions)
sudo dnf copr enable wezfurlong/wezterm-nightly
sudo dnf install wezterm

# PAM development headers
sudo dnf install pam-devel

# Optional: FIDO2 / YubiKey support
sudo dnf install pam-u2f libfido2-devel
```

### Arch Linux

```bash
# WezTerm
sudo pacman -S wezterm

# PAM development headers (included with base-devel)
sudo pacman -S pam

# Optional: FIDO2 / YubiKey support
sudo pacman -S pam-u2f libfido2
```

### NixOS

No manual dependency installation required. The Touchstone flake provides a NixOS module that declares all dependencies:

```nix
# In your flake.nix inputs
inputs.touchstone.url = "github:your-org/touchstone";

# In your NixOS configuration
{ inputs, ... }:
{
  imports = [ inputs.touchstone.nixosModules.default ];
  services.touchstone.enable = true;
}
```

This pulls in WezTerm, PAM integration, and optionally `pam_u2f` + `libfido2` if `services.touchstone.fido2.enable = true` is set.
