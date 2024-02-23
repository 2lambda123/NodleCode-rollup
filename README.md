# Nodle's Eth L2 rollup powered by zkSync stack
![Banner](https://github.com/NodleCode/rollup/assets/10683430/b50803ff-41d1-4faa-99eb-72c9eeaf3194)

This mono repo will contain all the required smart-contracts and the services that we would need to develop aroung them. This is a proof of concept targeting the needs of our Click dApp as its initial goal.

Each sub-package should feature a `README.md` file explaining how to test and use it.

# Development setup
> We recommend you run within the provided [devcontainer](https://code.visualstudio.com/remote/advancedcontainers/overview) to ensure you have all the necessary tooling installed.

## Local network
Most packages in this repo depend on various services which can easily be deployed locally by running `docker compose up`.

If using a mac with Apple Silicon chip, you may need to run `export DOCKER_DEFAULT_PLATFORM=linux/amd64` first.

If any issues, you may reset your local setup via `docker compose rm -fsv` before restarting it.

### Getting contract addresses
The docker compose should auto deploy the contracts for you. You should be able to see their addresses via `docker compose logs -f deploy-contracts`.

### Useful links
- Block Explorer: [`http://127.0.0.1:3010/`](http://127.0.0.1:3010/)
- DAPP Portal / ZkSync Wallet: [`http://127.0.0.1:3000`](http://127.0.0.1:3000)
- ContentSign NFT SubGraph: [`http://127.0.0.1:8000/subgraphs/name/content-sign`](http://127.0.0.1:8000/subgraphs/name/content-sign)
- Local Rollup RPC: `127.0.0.1:3050`

## Dependencies
If developing on this repo, you will need a number of dependencies, you may install them yourself by running `./.devcontainer/install-tools.sh`. This is not necessary if you simply want to use docker compose to start a local testnet.


### Handle ZK CLI 

## Running own rollup testnet

1 - Run `zk-setup.sh` to prepare zksync enviroment in the dev container
2 - Once this finished make sure you have the `<your_chain_name_slug>.env` file with the required information
3 - Run `zk-custom-start.sh`

## How to create <your_chain_name_slug>.env? [IN DEVELOPMENT]

1 - Create a file (or Edit if exist) in `envs/<your_chain_name_slug>.env`, fill it with the required information
2 - Run `zk-setup.sh`, if first time
3 - Run `zk-start.sh` this will initialize the process

