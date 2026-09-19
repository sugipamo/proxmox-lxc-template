# 実機受け入れ試験

同一のRelease assetから2台のunprivileged CTを作り、結果とイメージのSHA-256を記録します。

| 項目 | 合格条件 |
|---|---|
| 作成・起動・再起動 | 2台とも成功する |
| 個体識別子 | hostname、MAC、`/etc/machine-id` が2台で異なる |
| ネットワーク | `vmbr1`上でDHCPアドレスを取得する |
| DNS / Internet | `getent hosts example.com` と `curl -I https://example.com` が成功する |
| 管理LAN隔離 | Proxmox管理IPへの接続が失敗し、必要に応じOPNsenseログでも拒否を確認する |
| Tailscale初期状態 | 既存端末のidentityを持たず、未登録である |
| TUN | `/dev/net/tun` が存在し、`tailscaled` が起動する |
| Tailscale登録 | 2台が別端末として表示され、`tag:agent` を持つ |
| 管理アクセス | 管理PCからTailscale SSHで両方へ接続できる |
| Tailnet隔離 | Agentから許可していない他端末へ接続できない |
| Codex CLI | `codex --version`が成功し、初期状態で未認証である |

`10.77.x.1`（OPNsense LAN）へのping成功は合格条件にしません。現在のFirewall方針では
GatewayへのICMPは拒否されるため、Internet疎通は上記のDNS/HTTPSで確認します。
