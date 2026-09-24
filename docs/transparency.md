# Binary transparency (Sigstore Rekor)

Every tagged release publishes artifact hashes to Rekor so anyone can check
the .deb they installed matches the public log.

Publish (maintainer, on tag):
```
sha256sum ../*.deb > dist/hashes.txt
rekor-cli upload --artifact ../anonyx_3.0.0-1_all.deb --public-key cosign.pub
```

Verify (user):
```
script/verify-transparency.sh anonyx_3.0.0-1_all.deb <rekor-uuid>
script/verify-provenance.sh anonyx_3.0.0-1_all.deb multiple.intoto.jsonl
```

No Rekor entry + no SLSA provenance = do not install.
