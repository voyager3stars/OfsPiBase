#!/bin/bash
# =================================================================
# Project:      OFSPiBase (OrionFieldStack Pi Base)
# Component:    PHD2 Installation
# Author:       voyager3.stars
# Web:          https://voyager3.stars.ne.jp
# License:      MIT
# Description:  Builds and installs PHD2 from source.
#               Reference: https://github.com/OpenPHDGuiding/phd2
# =================================================================

# このスクリプトは setup.sh から source されることを前提としています。
# 必要な変数: TARGET_USER, SCRIPT_DIR
# 必要な関数: ask_yes_no, print_section, info, warn

PHD2_REPO="https://github.com/OpenPHDGuiding/phd2.git"

setup_phd2() {
  print_section "5" "PHD2 (オートガイド) インストール"

  if ! ask_yes_no "PHD2 のソースビルドとインストールを行いますか？"; then
    info "PHD2 のインストールをスキップしました。"
    return 1
  fi

  # PHD2 の配置先: ofspibase の親ディレクトリ (~/src/)
  local parent_dir
  parent_dir="$(dirname "$SCRIPT_DIR")"
  local build_dir="${parent_dir}/phd2"

  # システムパッケージの更新と依存関係のインストール
  info "システムパッケージを更新しています (apt upgrade) ..."
  apt-get update -y
  apt-get upgrade -y

  info "PHD2 の依存パッケージをインストールしています..."
  apt-get install -y build-essential git cmake pkg-config \
      libwxgtk3.2-dev wx-common libindi-dev libnova-dev \
      gettext zlib1g-dev libx11-dev libcurl4-gnutls-dev libusb-1.0-0-dev

  # ソースコードの取得
  if [ -d "$build_dir" ]; then
    info "PHD2 のソースディレクトリは既に存在します。最新版に更新しています..."
    cd "$build_dir"
    sudo -u "$TARGET_USER" git pull || warn "git pull に失敗しました。既存のバージョンで続行します。"
  else
    info "PHD2 をクローンしています..."
    info "  リポジトリ: $PHD2_REPO"
    info "  配置先:     $build_dir"
    sudo -u "$TARGET_USER" git clone --recursive "$PHD2_REPO" "$build_dir"
  fi

  cd "$build_dir"

  # ビルド
  info "PHD2 のビルド環境を構成しています (cmake) ..."
  sudo -u "$TARGET_USER" mkdir -p build
  cd build
  sudo -u "$TARGET_USER" cmake ..

  info "PHD2 をビルドしています (make) ..."
  # nproc でCPUコア数を取得し、並列コンパイル
  sudo -u "$TARGET_USER" make -j"$(nproc)"

  # インストール (root権限)
  info "PHD2 をシステムにインストールしています (make install) ..."
  make install
  ldconfig

  info "PHD2 のインストールが完了しました。"
  PHD2_CONFIGURED=true
  return 0
}
