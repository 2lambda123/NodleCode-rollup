#!/bin/bash

sudo apt update
sudo apt install --yes pkg-config build-essential cmake clang libssl-dev libclang-dev docker-compose software-properties-common jq
#sudo apt install --yes lldb lld postgresql axel

sudo add-apt-repository --yes ppa:ethereum/ethereum
sudo apt-get update
sudo apt-get install solc

# rustup toolchain install nightly

# cargo install cargo-nextest
# cargo install sqlx-cli

yarn global add zksync-cli
yarn global add @graphprotocol/graph-cli

if [ -z "$SKIP_FOUNDRY" ]; then
    curl -L https://foundry.paradigm.xyz | sh
    ~/.foundry/bin/foundryup
fi

# install and build zk tool
export ZKSYNC_HOME=/home/$USER/zksync-era
export PATH=$ZKSYNC_HOME/bin:$PATH
export VERSION=`./.devcontainer/version.sh matter-labs zksync-era`git clone https://github.com/matter-labs/zksync-era $ZKSYNC_HOME
cd $ZKSYNC_HOME
git checkout $VERSION
mkdir -p $ZKSYNC_HOME/volumes || true
sudo chown -R $USER:$USER $ZKSYNC_HOME/volumes
zk
# zk init || echo "zk init failed - ignored | you may want to run cd $ZKSYNC_HOME && git reset --hard && zk init"
# zk down