# Security Model

## Default Posture

- no credentials or private keys are stored in the module;
- configuration files contain non-secret parameters only;
- config files are parsed from an approved key list and are not executed;
- OS Login is enabled by default;
- the VM has no external IP by default;
- SSH uses Identity-Aware Proxy by default;
- Shielded VM protections are enabled;
- no service account is attached by default;
- existing infrastructure is never replaced automatically.

## Network Access

For IAP SSH, the target VM normally needs a network tag covered by a firewall
rule that allows TCP port 22 from the IAP TCP forwarding range:

```text
35.235.240.0/20
```

The toolkit validates a named IAP rule but does not create it.

A VM without an external IP needs another outbound path for internet access,
such as Cloud NAT or a controlled proxy. Private Google Access alone does not
provide general internet egress.

When an external IP is explicitly enabled, direct public SSH should remain
blocked. The toolkit can require a pre-existing deny rule before creation.

## Identity

Use the narrowest practical Google Cloud roles. Typical permissions include:

- viewing the project and enabled services;
- describing networks, subnets, firewall rules, and instances;
- creating Compute Engine instances;
- connecting through IAP;
- using OS Login.

Avoid broad project ownership for routine DevBox operation.

## Service Accounts and Workload Credentials

The default VM is created without a service account or OAuth scopes. Workloads
that need Google Cloud APIs should use an explicitly reviewed identity model,
such as:

- a dedicated least-privilege service account;
- short-lived user credentials;
- workload-specific federation;
- Secret Manager for application secrets.

Do not embed tokens, JSON keys, or private repository credentials in tracked
configuration.

## Evidence Handling

Evidence reports may contain:

- hostname and user information;
- local paths;
- Git commit and working-tree state;
- Docker container names and images;
- validation log content.

Treat evidence as an operational artifact. Review and redact it before
publishing or attaching it to a public issue.
