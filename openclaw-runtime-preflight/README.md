# OpenClaw Runtime Preflight

Read-only Bash validation for a systemd-managed, containerized OpenClaw runtime.

The module verifies the service, container, persistent storage, HTTP health endpoints, and - when explicitly requested - authenticated OpenClaw API operations.

## Structure

```text
openclaw-runtime-preflight/
├── README.md
├── config/
│   └── example.env
└── scripts/
    └── openclaw_container_runtime_preflight.sh
```

## What the Script Checks

### Basic mode

- Required command availability
- systemd service active and enabled state
- Exactly one expected OpenClaw container is running
- Container image reference and image ID
- Persistent state mount
- State and workspace directory ownership and permissions
- Health endpoint
- Readiness endpoint

### Deep mode

Deep mode includes all basic checks plus:

- Protected gateway token file availability
- Authenticated model discovery
- Real chat completion validation
- Admin RPC response validation
- Pending and paired device counts
- Presence of a paired Control UI device

> Deep mode sends a real chat completion request and can consume model quota or tokens. It is never enabled by default.

## Safety Characteristics

The script is intentionally read-only. It does not:

- restart or reload services;
- start, stop, or modify containers;
- write to OpenClaw state directories;
- change device pairing state;
- print the gateway token.

The config file contains paths and runtime settings only. Keep the actual token in a protected runtime secret file and reference that file through `TOKEN_FILE`.

## Prerequisites

Basic mode requires:

- Bash 4+
- `systemctl`
- Docker CLI
- `curl`
- `findmnt`
- `stat`
- `grep`

Deep mode additionally requires:

- `jq`
- Read access to the gateway token file
- Access to the configured authenticated API endpoints

Run the script as a user with sufficient permissions to inspect systemd, Docker, storage metadata, and the protected token file. Depending on the host configuration, this may require `sudo`.

## Usage

Make the script executable:

```bash
chmod +x scripts/openclaw_container_runtime_preflight.sh
```

Run the safe default validation:

```bash
./scripts/openclaw_container_runtime_preflight.sh
```

Run deep validation:

```bash
sudo ./scripts/openclaw_container_runtime_preflight.sh --mode deep
```

Use a config file:

```bash
cp config/example.env config/local.env
# Edit config/local.env for the target runtime.

sudo ./scripts/openclaw_container_runtime_preflight.sh \
  --config config/local.env \
  --mode deep
```

The explicit `--mode` argument takes precedence over `MODE` from the config file.

## Configuration

Supported keys:

| Key | Default | Purpose |
| --- | --- | --- |
| `MODE` | `basic` | Validation depth: `basic` or `deep` |
| `SERVICE_NAME` | `openclaw.service` | systemd service name |
| `CONTAINER_NAME` | `openclaw-gateway` | Expected running container name |
| `BASE_URL` | `http://127.0.0.1:8080` | Runtime API base URL |
| `STATE_MOUNT` | `/var/lib/openclaw` | Expected persistent mount target |
| `STATE_DIR` | `/var/lib/openclaw/state` | OpenClaw state directory |
| `WORKSPACE_DIR` | `/var/lib/openclaw/workspace` | OpenClaw workspace directory |
| `TOKEN_FILE` | `/run/openclaw/secrets/OPENCLAW_GATEWAY_TOKEN` | Protected token file |
| `MODEL_NAME` | `openclaw` | Model used by the deep chat probe |
| `CONTROL_UI_PATTERN` | `openclaw-control-ui` | Pattern used to identify the paired UI device |
| `CURL_CONNECT_TIMEOUT` | `3` | Connection timeout in seconds |
| `CURL_MAX_TIME` | `15` | Standard request timeout in seconds |
| `CHAT_MAX_TIME` | `120` | Chat completion timeout in seconds |

Configuration files use a restricted `KEY=VALUE` format. Unknown keys and malformed lines are ignored with a warning. Shell commands in the file are not executed.

Environment variables can also be used directly:

```bash
SERVICE_NAME=openclaw.service \
BASE_URL=http://127.0.0.1:8080 \
./scripts/openclaw_container_runtime_preflight.sh
```

## Exit Codes

- `0` — all required checks passed; warnings may still be present
- `1` — one or more validation checks failed
- `2` — invalid arguments, mode, or config access

The final lines are automation-friendly:

```text
PASS=<count> WARN=<count> FAIL=<count>
RESULT=PASS|FAIL
```

## Intended Use

- Post-deployment validation
- VM reboot or service restart verification
- Operational readiness checks
- Regression testing after runtime changes
- Evidence collection for runbooks and change records
