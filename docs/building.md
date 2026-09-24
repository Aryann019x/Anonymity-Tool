# Building from source (Debian 12, rust 1.63+)

Bash appliance works without Rust (feature-gated fallback always stays).

```bash
sudo apt install tor curl nftables iptables iproute2 proxychains4 \
  clang llvm libbpf-dev bpftool shellcheck bats
# optional: paranoid extras
sudo apt install obfs4proxy snowflake-client macchanger tpm2-tools
# rust (optional, for the memory-safe dispatcher)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
cargo build --release
cargo test
cargo geiger  # hot path must show zero unsafe
```

Debian packages:

```bash
dpkg-buildpackage -us -uc
sudo dpkg -i ../anonyx_3.0.0-1_all.deb
# paranoid early-boot (optional):
sudo dpkg -i ../anonyx-initramfs_3.0.0-1_all.deb
sudo update-initramfs -u
```

Reproducible: `SOURCE_DATE_EPOCH` respected, `cargo vendor` for offline builds,
`cargo auditable` embeds SBOM. Initrd addition stays under 500KB (nft + 1 ruleset).
