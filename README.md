# OFSPiBase

**OrionFieldStack Pi Base** — Raspberry Pi を天体観測用フィールドシステムとして構成するための統合セットアップツール

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## 概要

OFSPiBase は、Raspberry Pi を天体観測フィールド環境で使用するために必要な初期設定をワンコマンドで行うセットアップスクリプトです。

Wi-Fi アクセスポイント化、Samba ファイル共有、GPS による高精度時刻同期、KStars/EKOS/INDI、および PHD2 オートガイドのインストールをそれぞれモジュール化しており、必要な機能だけを選択してセットアップできます。

> **関連記事**: [Raspberry Pi INDI System: Part 1—System Setup – voyager3](https://voyager3.stars.ne.jp)

## 対応環境

| 項目 | 要件 |
|---|---|
| ハードウェア | Raspberry Pi 5 |
| OS | Raspberry Pi OS Bookworm (64-bit 推奨) |
| GPS モジュール | UART 接続の GPS モジュール（`/dev/ttyAMA0`）|

## 機能一覧

| モジュール | 概要 |
|---|---|
| **初期環境設定** | Raspberry Pi 5 の Wayland から X11 への切り替えと VNC の有効化 |
| **Wi-Fi AP** | Raspberry Pi を Wi-Fi アクセスポイントとして構成（NetworkManager / nmcli 使用） |
| **Samba** | Windows PC からファイル共有でアクセスできるよう Samba を構成 |
| **GPS / 時刻同期** | UART 接続の GPS モジュールと Chrony を使った高精度時刻同期 + INDI-GPSD ドライバを構成 |
| **KStars / EKOS** | KStars/EKOS/INDI をソースからビルド・インストール（[astro-soft-build](https://gitea.nouspiro.space/nou/astro-soft-build) 使用） |
| **PHD2** | PHD2 (オートガイド) をソースからビルド・インストール |

各機能は実行時に個別に有効/スキップを選択できます。

## ディレクトリ構成

### リポジトリ構成

```
ofspibase/
├── setup.sh                ← メインスクリプト（エントリーポイント）
├── lib/
│   └── common.sh           ← 共通ユーティリティ関数
├── modules/
│   ├── 00_init_rpi.sh      ← 初期環境設定 (X11 / VNC) モジュール
│   ├── 01_wifi_ap.sh       ← Wi-Fi AP 設定モジュール
│   ├── 02_samba.sh         ← Samba 設定モジュール
│   ├── 03_gps.sh           ← GPS / Chrony / INDI-GPSD 設定モジュール
│   ├── 04_kstars.sh        ← KStars / EKOS / INDI インストールモジュール
│   └── 05_phd2.sh          ← PHD2 インストールモジュール
└── README.md
```

### ユーザー環境での配置（`~/src`）

`setup.sh` を実行すると、KStars および PHD2 のビルド用リポジトリが自動的に clone されます。

```
~/src/
├── ofspibase/              ← 本リポジトリ
├── astro-soft-build/       ← KStars用ビルドスクリプト (自動 clone)
└── phd2/                   ← PHD2 ソースコード (自動 clone)
```

## 使い方

### 1. リポジトリのクローン

```bash
mkdir -p ~/src && cd ~/src
git clone https://github.com/voyager3stars/OfsPiBase.git
cd OfsPiBase
```

### 2. セットアップの実行

```bash
sudo ./setup.sh
```

> **注意**: 初回実行時、ウィンドウシステムが Wayland の場合は X11 に自動で変更され、**設定を反映させるためにスクリプトが強制終了して再起動を促します**。再起動後、もう一度 `sudo ./setup.sh` を実行すると、VNC の有効化など後続のセットアップが再開されます。

対話形式で各機能の設定を行うか尋ねられます。

```
================================================================
  OFSPiBase  –  Raspberry Pi フィールドシステム セットアップ
================================================================

==========================================
 1. Wi-Fi アクセスポイント 設定
==========================================
Wi-Fi アクセスポイントの設定を行いますか？ (Y/n):
```

### 3. セットアップ後の確認

#### Wi-Fi AP

Windows PC の Wi-Fi 一覧に設定した SSID が表示されるので、接続してください。

#### Samba (ファイル共有)

Windows PC で `Win + R` → 以下を入力:

```
\\<IPアドレス>\<ユーザー名>
```

#### GPS / 時刻同期

GPS モジュールの設定後は **再起動が必要** です。

```bash
sudo reboot
```

再起動後、以下のコマンドで動作確認できます:

```bash
# GPS 受信状態の確認
cgps -s

# 時刻同期ステータスの確認
chronyc sources
```

#### KStars / EKOS / PHD2

KStars や PHD2 のインストール後は **再起動が必要** です。
再起動後、デスクトップまたは VNC から KStars や PHD2 を起動できます。

## 各モジュールの詳細

### 初期環境設定 (`modules/00_init_rpi.sh`)

- `raspi-config nonint` を使用し、非対話形式で設定
- Wayland から X11 への切り替え（再起動のためスクリプトを一時停止）
- X11 環境確認後に VNC を有効化

### Wi-Fi AP (`modules/01_wifi_ap.sh`)

- NetworkManager (`nmcli`) を使用して Wi-Fi AP を構成
- 既存の Wi-Fi プロファイルの検出と再利用に対応
- SSID、パスワード（8文字以上）、IP アドレスをカスタマイズ可能
- デフォルト: SSID=`FieldAP`, IP=`192.168.50.1/24`

### Samba (`modules/02_samba.sh`)

- Samba 未インストールの場合は自動インストール
- `smb.conf` の `[homes]` セクションを安全に無効化
- 共有フォルダパスをカスタマイズ可能（デフォルト: ユーザーのホームディレクトリ）
- Samba ユーザーパスワードの設定

### GPS / 時刻同期 (`modules/03_gps.sh`)

- UART の有効化と `/boot/firmware/config.txt` の設定
- シリアルコンソールの無効化（GPS との競合を回避）
- `gpsd` のインストールと設定（`/dev/ttyAMA0`, 9600bps）
- `gpsd.socket` のマスク（直接デーモン管理）
- `chrony` の設定（GPS SHM 2 による時刻同期）
- 初回同期用の高速ステッピング (`makestep 1.0 3`)
- INDI-GPSD ドライバのインストール（KStars/EKOS から GPS データを利用可能に）

### KStars / EKOS / INDI (`modules/04_kstars.sh`)

- [nou/astro-soft-build](https://gitea.nouspiro.space/nou/astro-soft-build) を使用してソースからビルド
- `astro-soft-build` リポジトリを `~/src/` に自動 clone（既存の場合は `git pull` で更新）
- 依存パッケージの自動インストール (`install-dependencies.sh`)
- 安定版のビルドとインストール (`build-soft-stable.sh`)
- ※ ビルドには約1時間かかります

### PHD2 (`modules/05_phd2.sh`)

- [OpenPHDGuiding/phd2](https://github.com/OpenPHDGuiding/phd2) を使用してソースからビルド
- `phd2` リポジトリを `~/src/` に自動 clone
- 必要な依存ライブラリ（`libwxgtk3.2-dev`, `libindi-dev`, `libnova-dev` 等）の自動インストール
- CMake によるビルド構成と `make -j$(nproc)` による並列ビルド
- システム全体へのインストール (`make install` & `ldconfig`)

## ライセンス

MIT License

## 著者

- **voyager3.stars** — [https://voyager3.stars.ne.jp](https://voyager3.stars.ne.jp)

---

## 更新履歴

### v1.3.0 (2025-09-20)

**PHD2 インストール機能の追加**

- `modules/05_phd2.sh` を新規追加
  - ソースからのビルドとインストールを自動化
- `setup.sh` に PHD2 のサマリーを追加

### v1.2.0 (2025-09-19)

**Raspberry Pi 5 初期環境設定 (X11 / VNC) モジュールの追加**

- `modules/00_init_rpi.sh` を新規追加
  - Wayland から X11 への切り替えと、再起動を挟んだ確実な VNC 有効化フローを実装
- `setup.sh` に `00_init_rpi.sh` の呼び出しを追加し、Wayland 変更時に処理を中断して再起動を促す制御を追加

### v1.1.0 (2025-09-19)

**KStars / EKOS / INDI インストール機能の追加**

- `modules/04_kstars.sh` を新規追加
  - [nou/astro-soft-build](https://gitea.nouspiro.space/nou/astro-soft-build) によるソースビルド方式
  - 依存パッケージの自動インストールと安定版ビルド
- `modules/03_gps.sh` に INDI-GPSD ドライバのインストールを追加
- `setup.sh` に KStars モジュールの呼び出しとサマリー表示を追加
- README にユーザー環境での `~/src` 配置構成を追記

### v1.0.0 (2025-09-19)

**初回リリース — スクリプト統合 & モジュール化**

- `setup_ofspibase.sh` と `gpssetup/gpssetup.sh` を統合
- 機能別にモジュール分割した新アーキテクチャに移行:
  - `lib/common.sh` — 共通ユーティリティ関数
  - `modules/01_wifi_ap.sh` — Wi-Fi AP 設定
  - `modules/02_samba.sh` — Samba ファイル共有設定
  - `modules/03_gps.sh` — GPS / Chrony 時刻同期設定
- `setup.sh` をメインエントリーポイントとして新規作成
- 各モジュールの実行を対話式で選択可能に
- GPS モジュール内の冗長な `sudo` 呼び出しを整理
- セットアップ完了後の接続情報サマリーを統合表示
