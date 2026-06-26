# PAM + FIDO2 Integration

Touchstone delegates authentication to the operating system's PAM (Pluggable Authentication Modules) stack. This document covers how PAM and FIDO2 work together to provide hardware-bound consent.

## How PAM Authentication Works

When `sudo` runs, it invokes PAM with the `sudo` service configuration (typically `/etc/pam.d/sudo`). PAM processes a stack of modules in order:

```
auth  required  pam_unix.so        # Verify password
auth  required  pam_u2f.so         # Require FIDO2 touch
```

Each module returns `success` or `failure`. The `required` control means both must succeed -- the user must enter the correct password AND touch the FIDO2 key.

## How pam_u2f Works

`pam_u2f` implements the FIDO2/U2F challenge-response protocol:

1. **Challenge:** PAM sends a random challenge to the FIDO2 authenticator via USB HID.
2. **User presence:** The authenticator's LED blinks. The user physically touches the key.
3. **Response:** The authenticator signs the challenge with its private key (which never leaves the device).
4. **Verification:** `pam_u2f` verifies the signature against the registered public key stored in `~/.config/Yubico/u2f_keys`.

The private key is generated on the device during registration and cannot be extracted. This is the hardware binding -- authentication requires physical possession of the specific key that was registered.

## Setting Up FIDO2 for Sudo

### Step 1: Install Dependencies

```bash
# Ubuntu/Debian
sudo apt install libpam-u2f libfido2-dev

# Fedora
sudo dnf install pam-u2f libfido2-devel

# Arch
sudo pacman -S pam-u2f libfido2

# NixOS (in configuration.nix)
security.pam.u2f.enable = true;
```

### Step 2: Register Your Key

Insert your FIDO2 key (YubiKey, SoloKey, etc.) and run:

```bash
mkdir -p ~/.config/Yubico
pamu2fcfg > ~/.config/Yubico/u2f_keys
```

When prompted, touch the key. This generates a registration record containing the public key and key handle.

To register additional backup keys, append to the file:

```bash
pamu2fcfg -n >> ~/.config/Yubico/u2f_keys
```

### Step 3: Configure PAM

Edit `/etc/pam.d/sudo`:

```
# Password authentication
auth  required  pam_unix.so

# FIDO2 hardware authentication
auth  required  pam_u2f.so  cue  [cue_prompt=Touch your security key]
```

Options:

| Option | Purpose |
|--------|---------|
| `cue` | Display a prompt when waiting for touch |
| `cue_prompt=...` | Custom prompt text |
| `authfile=/path` | Override default u2f_keys location |
| `nouserok` | Allow users without registered keys to pass (use during migration) |
| `debug` | Log debug output to syslog |
| `interactive` | Wait for key insertion if not present |

### Step 4: Test

Open a new terminal (keep a root shell open as backup) and run:

```bash
sudo whoami
```

You should be prompted for your password, then for a key touch. If both succeed, the output is `root`.

## Control Values: required vs sufficient

The PAM control value determines how a module's result affects the overall authentication:

### required (Recommended for Touchstone)

```
auth  required  pam_unix.so
auth  required  pam_u2f.so
```

Both modules must succeed. Password AND key touch are mandatory. This is the strongest configuration for Touchstone because it ensures hardware presence at every privilege boundary.

### sufficient

```
auth  sufficient  pam_u2f.so
auth  required    pam_unix.so
```

If `pam_u2f` succeeds, authentication passes immediately (password is skipped). If the key is not present, PAM falls back to password-only.

**This weakens Touchstone's security model.** An attacker who steals the YubiKey does not need the password. Use `sufficient` only during initial migration or testing.

### requisite

```
auth  requisite  pam_unix.so
auth  required   pam_u2f.so
```

If `pam_unix` fails, PAM stops immediately without trying `pam_u2f`. This avoids unnecessary key touch prompts on wrong passwords but otherwise behaves like `required`.

## Why Hardware > Software Tokens

For AI agent consent, hardware tokens have specific properties that software tokens (TOTP, push notifications, SMS) do not:

| Property | Hardware (FIDO2) | Software (TOTP/Push) |
|----------|------------------|----------------------|
| Phishing resistant | Yes (origin-bound) | No (codes can be intercepted) |
| Requires physical presence | Yes (touch) | No (can be approved remotely) |
| Extractable secret | No (key never leaves device) | Yes (TOTP seeds can be stolen) |
| Agent can generate | No | Possibly (if agent has access to TOTP secret) |
| Replay resistant | Yes (challenge-response) | Partial (time-window for TOTP) |

The critical property for Touchstone is **physical presence**. A software token could theoretically be approved by a compromised process or an agent that has access to the token secret. A FIDO2 touch requires a human finger on a physical device.

## NixOS Configuration

On NixOS, PAM is configured declaratively:

```nix
# In your NixOS configuration
{
  security.pam.u2f = {
    enable = true;
    cue = true;
    control = "required";
  };

  # Ensure the FIDO2 libraries are available
  environment.systemPackages = with pkgs; [
    yubikey-manager
    libfido2
  ];

  # udev rules for FIDO2 devices
  services.udev.packages = [ pkgs.yubikey-personalization ];
}
```

After rebuilding (`sudo nixos-rebuild switch`), the PAM configuration is applied system-wide.

## FIDO2 Timing on Chained Authentication

When multiple FIDO2 prompts fire in rapid succession (e.g., SSH auth followed immediately by sudo auth through a tunnel), the key may require a brief cooldown between operations.

This is documented in detail in [cross-host-auth.md](cross-host-auth.md).

**Summary:** The first touch may time out. Wait for the prompt, touch again. This is FIDO2 protocol behavior, not a Touchstone defect.

## Troubleshooting PAM + FIDO2

### Key not detected

```bash
# Check that the key is recognized
fido2-token -L

# Check udev rules
ls /etc/udev/rules.d/*fido* /etc/udev/rules.d/*yubi* 2>/dev/null
```

### Authentication always fails

```bash
# Verify key is registered
cat ~/.config/Yubico/u2f_keys

# Test with debug mode
# Add "debug" to pam_u2f.so line, then check syslog
sudo grep pam_u2f /var/log/auth.log
```

### Locked out

If you misconfigure PAM and cannot authenticate:

1. Boot into single-user mode or use a live USB.
2. Mount the root filesystem.
3. Edit `/etc/pam.d/sudo` to remove or comment out the `pam_u2f.so` line.
4. Reboot and fix the configuration.

Always keep a root shell open when testing PAM changes.
