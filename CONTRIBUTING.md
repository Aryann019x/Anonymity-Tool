# contributing

Dev on Debian 12+. No pushes without local green.

Setup:
```
sudo apt install shellcheck bats nftables tor
make check
bats test/unit/
```

Rules:
- bash only, `shellcheck -S warning` clean, `bash -n` clean.
- no hardcoded paths: use ETC_DIR/VAR_RUN_DIR/VAR_LOG_DIR env overrides.
- fail-closed: no ACCEPT fallbacks to make tests pass.
- every firewall change needs state.json entry + audit event + restore path.
- unit test nft generation with `nft --check`; integration in container.
- no external downloads outside Debian main/contrib.
