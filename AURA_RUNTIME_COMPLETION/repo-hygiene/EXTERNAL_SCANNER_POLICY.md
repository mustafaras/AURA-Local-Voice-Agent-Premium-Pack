# External Scanner Remediation Policy

This policy makes the clean-clone security scans reproducible without exposing
secret-shaped fixture values in logs or ledgers.

## Gitleaks

Run the current-tree and history scans against an independently verified clean
clone while passing the remediation checkout's exact configuration path (the
configuration may be uncommitted in the remediation worktree):

```text
gitleaks git file://<clean-clone> --config <remediation-worktree>/.gitleaks.toml --redact --log-opts="--all"
gitleaks dir --config <remediation-worktree>/.gitleaks.toml --redact <clean-clone>
```

The path allowlist is exact and limited to deterministic control-plane or test
fixture files that contain hashes, fake credentials, or scanner test inputs.
It does not allow arbitrary findings, commits, or directories.

## TruffleHog

Run the history scan with verification enabled and the exact path exclusion
file:

```text
trufflehog git file://<clean-clone> --results=verified,unknown \
  --exclude-paths <remediation-worktree>/AURA_RUNTIME_COMPLETION/repo-hygiene/TRUFFLEHOG_EXCLUDE_PATHS.txt \
  --fail
```

The three excluded paths are known scanner false-positive locations: two test
method names detected by the `Lob` detector and one explicitly marked security
fixture. They are still covered by the repository's fail-closed tracked-content
secret validator.

## Dependency and SBOM scans

```text
osv-scanner scan source -r <clean-clone>
syft dir:<clean-clone> --exclude '**/.venv/**' -o cyclonedx-json=<sbom-path>
grype sbom:<sbom-path>
```

The `.venv` exclusion is limited to generated environments; the authoritative
`pyproject.toml`/`uv.lock` graph is still scanned and validated separately.
The reports are evidence artifacts; a non-zero result is not converted into a
pass by this policy. The 2026-08-11 remediation graph uses an explicit
upstream dependency override plus `torchcodec` for the current torchaudio
save/load backend, and its OSV/Grype scans are zero only with the generated
environment excluded.
