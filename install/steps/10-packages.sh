#!/usr/bin/env bash
set -euo pipefail
. "$TAKUMI_PATH/lib/install.sh"
sudo pacman ${pkg_conf[@]+"${pkg_conf[@]}"} -Syu --noconfirm   # a full upgrade first: -Sy followed by -S would be a partial upgrade
pkg_install_list "$TAKUMI_PATH/install/packages/base.txt"
pkg_install_list "$TAKUMI_PATH/install/packages/desktop.txt"
