# agent profile

Debian 13 (amd64) based image for an unprivileged Proxmox VE LXC.

Included:

- `ca-certificates`, `curl`, `git`, `jq`, and `openssh-client`
- Tailscale from the official stable repository
- `tailscaled` enabled for first boot
- OpenAI Codex CLI, pinned by `codex.version`

Not included:

- Tailscale identity, auth key, or Tailnet registration
- Git credentials, SSH private keys, or application data
- Codex/ChatGPT/API authentication, user configuration, or session history
- An SSH server, Docker, browser, fixed IP address, or fixed hostname

After creating a CT, pass `/dev/net/tun` from Proxmox and register the CT with
Tailscale. See [`deploy/README.md`](../../deploy/README.md).
