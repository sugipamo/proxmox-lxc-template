# Proxmox VEへのデプロイ

## 1. テンプレートを配置

GitHub Releaseから `.tar.zst` と `SHA256SUMS` を取得し、チェックサムを確認します。

```bash
sha256sum -c SHA256SUMS --ignore-missing
```

ProxmoxのGUIからCT Templatesへアップロードするか、対象ストレージの
`template/cache/` に配置します。GitHubが自動生成するSource codeアーカイブではなく、
Release assetの `agent-*.tar.zst` を使ってください。

## 2. CTを作成

GUIでは次を指定します。

- Unprivileged container: ON
- Bridge: `vmbr1`
- IPv4: DHCP
- DNS: 配置先OPNsenseのLAN IP（PVE-01なら `10.77.1.1`）
- hostname: CTごとに一意
- Device passthrough: `/dev/net/tun`
- Features: `keyctl=1,nesting=1`

CLIでは、PVEホスト上で次のように作成できます。

```bash
sudo ./deploy/create-ct.sh \
  --ctid 120 \
  --hostname agent-pve01-120 \
  --template local:vztmpl/agent-debian13-amd64-v0.1.0.tar.zst \
  --nameserver 10.77.1.1 \
  --start
```

## 3. Tailscaleへ登録

CT内で `/dev/net/tun` とdaemonを確認します。

```bash
ls -l /dev/net/tun
systemctl status tailscaled --no-pager
```

auth keyをコマンド履歴やログに残さないよう、安全な秘密情報の受け渡し手段を使って
次を実行します。キーは再利用可能なイメージやリポジトリに保存しないでください。

```bash
tailscale up --auth-key="$TS_AUTH_KEY" --advertise-tags=tag:agent --ssh
unset TS_AUTH_KEY
```

## 4. 受け入れ試験

同じイメージから2台を作り、[`tests/acceptance.md`](../tests/acceptance.md)を実施します。
