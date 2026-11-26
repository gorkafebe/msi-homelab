# 0002 — No full-disk encryption

**Status:** in force. **Source:** D-22.

**Context.** Full-disk encryption asks for a passphrase at every boot. The
server must come back by itself after a power cut, with nobody at the keyboard.

**Decision.** No disk encryption.

**Alternatives.** LUKS with a typed passphrase (blocks unattended boot);
LUKS unlocked by the TPM or over the network (Clevis/Tang): possible later,
more moving parts.

**Consequences.** Whoever takes the laptop can read the disk. Secrets live in
mode-600 files, health data is the most sensitive data on it, and backups that
leave the machine must be encrypted ([0025](0025-backups-before-real-data.md)).
