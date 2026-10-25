# OmniNexus Agent & CLI Distribution Hub

Official multi-platform software distribution repository for the **OmniNexus Unified Endpoint & Device Management Platform**.

This repository hosts official production binary releases and automated one-line installation scripts for Linux servers, Windows PCs, and macOS workstations.

---

## ⚡ Quick 1-Line Installation

### Linux VPS / Servers (Ubuntu, Debian, RHEL, CentOS, Alpine)
Run as `root` (or with `sudo`):
```bash
curl -sSL https://raw.githubusercontent.com/howtosecu/OmniNexus-Agent/main/scripts/install.sh | sudo bash -s -- --hub-endpoint=YOUR_HUB_HOST:9443
```

### Windows Server & Workstations (Windows 10/11)
Run inside Administrator PowerShell:
```powershell
powershell -ExecutionPolicy Bypass -Command "iwr -useb https://raw.githubusercontent.com/howtosecu/OmniNexus-Agent/main/scripts/install.ps1 | iex"
```

---

## 📦 Supported Architectures & Platforms

All release binaries are static, standalone executables (`CGO_ENABLED=0`, zero external libc or runtime dependencies) and can be downloaded from the [Releases](https://github.com/howtosecu/OmniNexus-Agent/releases) page:

| Operating System | Architecture | Binary Name | Target Form Factors |
| :--- | :--- | :--- | :--- |
| **Linux** | AMD64 (x86_64) | `nexus-agent-linux-amd64` | Intel/AMD Cloud VPS, bare-metal servers |
| **Linux** | ARM64 (aarch64) | `nexus-agent-linux-arm64` | AWS Graviton, Raspberry Pi 4/5, Oracle ARM |
| **Windows** | AMD64 (x86_64) | `nexus-agent-windows-amd64.exe` | Windows Server 2019/2022, Windows 10/11 |
| **macOS** | ARM64 | `nexus-agent-darwin-arm64` | Apple Silicon (M1/M2/M3/M4) |

Each release is accompanied by cryptographic `SHA256SUMS` to verify file integrity.

---

## 🛡️ Security & Privacy Architecture

- **Air-Gapped Build Isolation**: Binaries are compiled in an isolated, multi-stage build environment. Control plane infrastructure, databases, and proprietary authentication services remain 100% private.
- **Outbound-Only Connectivity**: The agent strictly establishes outbound connections to the Control Plane Hub. **Zero open ports** or inbound listening sockets are ever opened on client endpoints.
- **Cryptographic Device Identity**: Every endpoint automatically generates an asymmetric Ed25519 keypair on first launch.
