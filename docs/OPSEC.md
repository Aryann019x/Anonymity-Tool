# Developer OPSEC

Releases are built to survive a compromised laptop, not just a typo.

- Signing keys live on a Yubikey (subkeys only). Master key is air-gapped,
  paper-backed, never touches a networked box.
- Two-person rule: no tag is pushed until a second maintainer reproduces the
  build with `script/rebuild.sh` and confirms identical hashes.
- Ephemeral builders: GitHub Actions images or fresh containers only.
  No long-lived release workstation.
- `cargo vendor` tree is committed per release so builds work offline.
- If a signing key is suspected compromised: rotate per docs/keys.md,
  publish `--revoke` via lib/update.sh, and cut a new release within 72h.

User side: verify provenance + transparency before `dpkg -i`
(see release notes template).
