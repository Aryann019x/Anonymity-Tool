# Signing keys

Release key fingerprint (placeholder - replace with real before first tag):

```
1234 5678 90AB CDEF 1234 5678 90AB CDEF 1234 5678
```

Contact: security@example.com (see SECURITY.md, 90-day disclosure).

Rotation procedure:
1. Generate new subkey on the air-gapped master, export subkey only.
2. Update this file + SECURITY.md fingerprint, commit, tag a rotation release.
3. Revoke old subkey (`gpg --gen-revoke`), publish revocation, keep old
   signatures verifiable for 12 months.
4. Notify via GitHub release notes + transparency log entry.

Verification: `gpg --recv-keys <fingerprint>` then `git verify-tag v3.0.0`.
