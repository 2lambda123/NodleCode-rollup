# Nodle's Eth L2 rollup powered by zkSync stack
![Banner](https://github.com/NodleCode/rollup/assets/10683430/b50803ff-41d1-4faa-99eb-72c9eeaf3194)

# Development setup
> We recommend you run within the provided [devcontainer](https://code.visualstudio.com/remote/advancedcontainers/overview) to ensure you have all the necessary tooling installed such `graph`, `zksync-cli`, and `forge`.

## Repo organization
- `./` contains foundry contracts for Nodle and Click on ZkSync:
  - `./lib` contains libraries we depend on.
  - `./src` contains contract sources.
  - `./scripts` contains deployment scripts.
  - `./test` contains unit tests.
- `./graph` contains a custom SubGraph for this project.
- ...more to come

# Usage

## Build

```shell
$ forge build
```

## Test

```shell
$ forge test
```

## Format

```shell
$ forge fmt
```

## Deployment

> Please see scripts in `./scripts` and refer to the [forge documentation](https://book.getfoundry.sh/reference/forge/forge-script) for additional arguments.

### Deploying ContentSign contracts

Please define the following environment variables:
- `N_SUPER_ADMIN`: address of the super admin on the paymaster whitelist contract.
- `N_WHITELIST_ADMIN`: address of the whitelist admin on the paymaster whitelist contract (typically the onboard or sponsorship API address).
- `N_WITHDRAWER`: address of the account allowed to withdraw ETH from the paymaster contract.

```shell
$ forge script script/DeployContentSign.s.sol
[⠒] Compiling...
[⠆] Compiling 1 files with 0.8.20
[⠰] Solc 0.8.20 finished in 8.47s

Script ran successfully.
Gas used: 1821666

== Logs ==
  Deployed ContentSignNFT at 0x90193C961A926261B756D1E5bb255e67ff9498A1
  Deployed WhitelistPaymaster at 0x34A1D3fff3958843C43aD80F30b94c510645C316
  Please ensure you fund the paymaster contract with enough ETH!

If you wish to simulate on-chain transactions pass a RPC URL.
```

> You will need to specify additional arguments when deploying to mainnet or verifying the contracts on Etherscan. Please look at the forge script help for more details.