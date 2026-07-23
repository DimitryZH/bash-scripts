# DevClaw Operations Toolkit

Reusable, read-only Bash utilities for inspecting and troubleshooting DevClaw
installations running with OpenClaw.

## What DevClaw Is

[OpenClaw](https://github.com/openclaw/openclaw) provides the agent runtime,
sessions, tools, channels, gateway RPC, authentication, and model access.

[DevClaw](https://github.com/laurentenhoor/devclaw) is an OpenClaw plugin that
adds autonomous software-development orchestration. It organizes project and
task state and dispatches role-based agents so that development work can move
through implementation, review, testing, and other controlled stages.

This module focuses on operational inspection of that DevClaw layer.

## Related OpenClaw Module

For container runtime health, persistence, API, and control-plane validation,
see [OpenClaw Runtime Preflight](../openclaw-runtime-preflight/README.md).

## Included Script

### `scripts/devclaw_circuit_breaker_diagnostics.sh`

A parameterized diagnostic utility for investigating DevClaw circuit-breaker
failures, including:

- the exact circuit-breaker error across the installed package and state;
- resilience-related implementation references in `dist/index.js`;
- `CircuitBreaker`, `cockatiel`, retry, and `withResilience` usage;
- circuit-breaker references in JSON, YAML, and log files;
- a bounded inventory of DevClaw state files;
- an optional `tasks_status` runtime probe for a selected project.

The default path is read-only and does not invoke an AI agent. The optional
`tasks_status` probe must be enabled explicitly because it may invoke a model
and consume tokens.

## Repository Structure

```text
devclaw-operations-toolkit/
├── README.md
├── config/
│   └── example.env
└── scripts/
    └── devclaw_circuit_breaker_diagnostics.sh
```

## Safety Characteristics

The script is designed for diagnostic use:

- no files are created, changed, or deleted;
- no service or container is restarted;
- no DevClaw task state is modified;
- the gateway token is read only for the optional runtime probe;
- the token value is never printed;
- the configuration file is parsed from an approved key list and is not
  executed as shell code.

Diagnostic output can contain local paths, project identifiers, state metadata,
or selected log lines. Review captured output before publishing it.

## Prerequisites

For source and state inspection:

- Bash 4 or later;
- `grep`, `find`, `sort`, `head`, `id`, and `awk`;
- read access to the DevClaw package and state directories.

For the optional runtime task probe:

- an installed OpenClaw CLI;
- access to the trusted gateway environment file;
- execution as the DevClaw service account, or as root with `runuser`;
- a valid DevClaw project slug.

## Configuration

Copy the example configuration to a local file:

```bash
cp config/example.env config/local.env
```

Adjust paths and runtime identity for the target host. Do not add secrets to
this file. The gateway token remains in the trusted OpenClaw gateway
environment file.

Configuration precedence is:

1. command-line arguments;
2. values from `--config`;
3. existing environment variables;
4. built-in defaults.

## Usage

Make the script executable:

```bash
chmod +x scripts/devclaw_circuit_breaker_diagnostics.sh
```

Run source and state inspection with package auto-discovery:

```bash
./scripts/devclaw_circuit_breaker_diagnostics.sh \
  --config config/local.env
```

Select a package explicitly:

```bash
./scripts/devclaw_circuit_breaker_diagnostics.sh \
  --package-dir /path/to/node_modules/@laurentenhoor/devclaw \
  --state-dir /path/to/devclaw/state
```

Inspect only the installed DevClaw implementation:

```bash
./scripts/devclaw_circuit_breaker_diagnostics.sh \
  --config config/local.env \
  --mode source
```

Inspect only state and logs:

```bash
./scripts/devclaw_circuit_breaker_diagnostics.sh \
  --config config/local.env \
  --mode state
```

Enable the optional runtime task probe:

```bash
./scripts/devclaw_circuit_breaker_diagnostics.sh \
  --config config/local.env \
  --include-task-status \
  --project-slug my-project
```

The runtime probe sends the following DevClaw tool request through the OpenClaw
agent:

```text
tasks_status({projectSlug="my-project"})
```

## Package Discovery

When `DEVCLAW_PACKAGE_DIR` is empty, the script searches
`DEVCLAW_PACKAGE_SEARCH_ROOT` for:

```text
*/node_modules/@laurentenhoor/devclaw
```

A single match is selected automatically. When multiple installations are
found, the script stops that inspection path and asks for an explicit
`--package-dir`, avoiding an ambiguous or nondeterministic selection.

## Exit Codes

| Code | Meaning |
| ---: | --- |
| `0` | Inspection completed; warnings may be present. |
| `1` | One or more requested diagnostic operations failed. |
| `2` | Invalid arguments, configuration, or missing local dependencies. |

## Scope

This module is intended for operational diagnostics and incident investigation.
It does not reset the circuit breaker, edit DevClaw state, restart the gateway,
or make recovery decisions automatically.
