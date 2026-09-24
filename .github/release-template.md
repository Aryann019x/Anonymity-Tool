## Anonyx v{VERSION}

### Highlights
- Security appliance architecture with network namespaces
- nftables primary, iptables compatibility fallback
- Corridor-style verification with audit logging
- Debian packaging with systemd, AppArmor, seccomp

### Installation
```bash
sudo dpkg -i anonyx_{VERSION}_amd64.deb
sudo anonyx --doctor
sudo anonyx --enable
```

### Verification
```bash
anonyx --status
anonyx --leaktest
script/verify-provenance.sh anonyx_{VERSION}_amd64.deb multiple.intoto.jsonl
script/verify-transparency.sh anonyx_{VERSION}_amd64.deb
bash script/rebuild.sh /tmp/a /tmp/b
```

### SBOM
```bash
bash script/generate-sbom.sh sbom/
```

### Security
See SECURITY.md for vulnerability reporting.
