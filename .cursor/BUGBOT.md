# Bugbot review rules — OpenUsage (Tauri edition)

## Review context

No Westline project vault is committed. Read `AGENTS.md`, relevant architecture/provider/plugin documentation, `SECURITY.md`, manifests, and tests. This is a public fork with upstream history; distinguish Westline-specific changes from upstream behavior and do not add private organization context.

## Project and severity

OpenUsage is a Tauri desktop application with a React UI, Rust backend, provider plugins, local credential/log/config readers, proxy support, a loopback HTTP API, auto-update/release workflows, and broad access to sensitive AI-account usage data. Credential boundaries, local file access, plugins, networking, IPC, and signed releases are high risk.

## Always flag

- Provider credentials, cookies, session tokens, CLI auth, local log contents, home paths, or account identifiers sent to unapproved hosts, rendered in errors, logged, persisted insecurely, or exposed through the local API.
- A provider/plugin reading files outside its documented scope, following unsafe symlinks, executing shell/code, loading remote code, or accepting unvalidated plugin manifests/outputs.
- Tauri commands or IPC exposed without allowlisted arguments, path validation, size limits, safe error redaction, and minimum capabilities. Reject shell execution assembled from user/plugin input.
- Local HTTP API binding beyond loopback, unsafe CORS, unauthenticated state-changing methods, data leakage across profiles/accounts, or endpoints that expose secrets rather than aggregate usage.
- Proxy/HTTP changes that leak authentication to the wrong host, permit SSRF to local/private resources, disable TLS verification, omit timeouts, or retry unsafe operations.
- Provider parsing that confuses units/windows/accounts, silently reports stale success, or lets one account overwrite another. Preserve cancellation, backoff, cache identity, and explicit unavailable/error states.
- CI/release/update changes that weaken signing, notarization, provenance, branch/tag protections, artifact checksums, or permissions.

## Lower-priority / avoid noise

- Provider websites are unstable; selector/API drift is a correctness issue only when the changed code mishandles it.
- Avoid broad architectural rewrites and subjective UI nitpicks. Public documentation and backward compatibility matter.

## Verification expectations

Require provider fixtures/tests, redaction tests, account-isolation cases, local API boundary tests, Tauri command validation, and release workflow review. Network additions must identify every destination and which credentials, if any, are attached.
