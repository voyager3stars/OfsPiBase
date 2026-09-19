#!/bin/bash
# =================================================================
# Project:      OFSPiBase (OrionFieldStack Pi Base)
# Component:    KStars / EKOS / INDI Installation
# Author:       voyager3.stars
# Web:          https://voyager3.stars.ne.jp
# License:      MIT
# Description:  Installs KStars/EKOS/INDI from source using
#               nou/astro-soft-build.
#               Reference: https://gitea.nouspiro.space/nou/astro-soft-build
# =================================================================

# このスクリプトは setup.sh から source されることを前提としています。
# 必要な変数: TARGET_USER, USER_HOME, SCRIPT_DIR
# 必要な関数: ask_yes_no, print_section, info, warn

# astro-soft-build の clone 先（ofspibase の兄弟ディレクトリ）
ASTRO_BUILD_REPO="https://gitea.nouspiro.space/nou/astro-soft-build.git"

setup_kstars() {
  print_section "4" "KStars / EKOS / INDI インストール"

  if ! ask_yes_no "KStars / EKOS / INDI のインストールを行いますか？"; then
    info "KStars / EKOS / INDI のインストールをスキップしました。"
    return 1
  fi

  # astro-soft-build の配置先: ofspibase の親ディレクトリ (~/src/)
  local parent_dir
  parent_dir="$(dirname "$SCRIPT_DIR")"
  local build_dir="${parent_dir}/astro-soft-build"

  # git のインストール確認
  if ! command -v git &>/dev/null; then
    info "git をインストールしています..."
    apt-get update -y
    apt-get install -y git
  fi

  # astro-soft-build のクローンまたは更新
  if [ -d "$build_dir" ]; then
    info "astro-soft-build は既に存在します。最新版に更新しています..."
    cd "$build_dir"
    sudo -u "$TARGET_USER" git pull || warn "git pull に失敗しました。既存のバージョンで続行します。"
  else
    info "astro-soft-build をクローンしています..."
    info "  リポジトリ: $ASTRO_BUILD_REPO"
    info "  配置先:     $build_dir"
    sudo -u "$TARGET_USER" git clone "$ASTRO_BUILD_REPO" "$build_dir"
  fi

  cd "$build_dir"

  # 依存パッケージのインストール
  info "依存パッケージをインストールしています..."
  info "  実行: ./install-dependencies.sh"
  chmod +x install-dependencies.sh
  ./install-dependencies.sh

  # KStars/INDI の安定版ビルド
  echo ""
  echo "=========================================="
  echo "  KStars / INDI の安定版ビルドを開始します"
  echo "  ※ ビルドには約1時間かかります"
  echo "=========================================="
  echo ""

  chmod +x build-soft-stable.sh
  ./build-soft-stable.sh

  info "KStars / EKOS / INDI のインストールが完了しました。"
  KSTARS_CONFIGURED=true
  return 0
}
