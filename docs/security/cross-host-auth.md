# Cross-Host Authentication

Touchstone supports privilege consent across SSH tunnels, including complex multi-hop chains where authentication crosses host boundaries.

## Tested Scenarios

### Direct SSH + Remote Sudo

```bash
ts-run ssh -t user@remote "sudo whoami"
```

The WezTerm window shows both the SSH authentication and the remote sudo prompt. The user authenticates at each boundary.

### Double-Hop Reverse SSH + Sudo (Hardest Test)

```bash
ts-run ssh -t user@remote "ssh -t localuser@local-ip 'sudo whoami'"
```

**Flow:**
1. Local machine → SSH → Remote server (key + password auth)
2. Remote server → reverse SSH → back to local machine (FIDO2 auth)
3. Local machine sudo via reverse tunnel (password + YubiKey touch)
4. Returns `root`

This proves that hardware-bound PAM auth survives a double-hop reverse tunnel. The YubiKey is physically present on the originating machine, and `pam_u2f` demands physical touch at every privilege boundary — even when the sudo command arrives through a reverse SSH tunnel.

## Known Behavior: FIDO2 Timing on Chained Auth

When multiple FIDO2 authentication prompts fire in rapid succession through SSH tunnels (e.g., reverse SSH auth immediately followed by sudo auth), the YubiKey may require a brief cooldown between touch operations.

**Symptoms:**
- First touch prompt may time out or fail
- "Please touch the FIDO authenticator" appears multiple times
- Second touch succeeds

**Why this happens:**
The FIDO2 protocol requires the authenticator to complete one operation before starting another. When SSH and sudo prompts arrive through tunnels with minimal delay, the device may still be processing the previous operation when the next prompt arrives.

**This is expected behavior** — PAM retries automatically, and the second touch completes successfully. This is a characteristic of the FIDO2 protocol under rapid chained authentication, not a Touchstone defect.

**Mitigation:**
- Wait for the "Please touch" prompt to appear before touching
- If a touch fails, wait 1-2 seconds before the next touch
- Single-hop scenarios (the common case) do not exhibit this behavior
