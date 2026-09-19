# Proxmox LXC Agent Template

隔離されたAgentネットワーク向けに、Proxmox VEの「Create CT」で利用できる
Debian 13 / amd64 root filesystemテンプレートを生成します。

成果物は、unprivileged LXC用の `agent-debian13-amd64-vX.Y.Z.tar.zst` です。
公式Proxmox Debianテンプレートを固定・検証して展開し、共通ツールとTailscaleを追加、
個体情報を除去して再アーカイブします。

## セキュリティ境界

イメージに含むもの:

- Debian 13、CA証明書、curl、git、jq、OpenSSH client
- Tailscaleパッケージと有効化済み`tailscaled` service
- バージョン固定したOpenAI Codex CLI（`/usr/local/bin/codex`）
- profile、version、commit、build日時を示す `/etc/agent-image-release`

イメージに含めないもの:

- Tailscale identity / auth key / API token
- Codex/ChatGPT/APIの認証情報、ユーザー設定、セッション履歴
- SSH秘密鍵、Git認証情報、SSH server
- 固定IP、個体固有hostname、machine-id、DHCP lease
- `/dev/net/tun`の割り当て（Proxmox側で設定）

## ローカルビルド

amd64 Linuxの使い捨てVMなど、rootでchrootとmountが可能な環境を使います。
本番PVEホスト上でのビルドは推奨しません。

```bash
sudo apt-get install -y curl git jq zstd
sudo VERSION=0.1.0 ./scripts/build.sh
```

出力:

```text
dist/
├── agent-debian13-amd64-v0.1.0.tar.zst
├── agent-debian13-amd64-v0.1.0.packages.txt
├── agent-debian13-amd64-v0.1.0.build-info.json
└── SHA256SUMS
```

`work/downloads/`の検証済みベースイメージは次回ビルドで再利用されます。URLや
SHA-256は[`bases/debian13-amd64.lock`](bases/debian13-amd64.lock)で固定しています。

## CI / Release

- push / pull request: shell構文とShellCheckを実行
- `Build template`の手動実行: 完全ビルドしActions artifactとして保存
- `vX.Y.Z`タグ: 完全ビルド後、成果物を添付したDraft Releaseを作成

Draftは[`tests/acceptance.md`](tests/acceptance.md)の実機検証後に手動公開します。
GitHubのSource code tar/zipはLXCテンプレートではありません。

## Proxmoxで使う

手順とCT作成helperは[`deploy/README.md`](deploy/README.md)を参照してください。
想定値はunprivileged、`vmbr1`、DHCP、配置先OPNsenseをDNS、`/dev/net/tun` passthroughです。

## ディレクトリ

```text
bases/       固定したベースイメージ情報
common/      全profile共通パッケージ
profiles/    profile固有パッケージとセットアップ
scripts/     build、cleanup、検証
deploy/      Proxmoxへの作成手順とhelper
tests/       2台で行う実機受け入れ試験
```
