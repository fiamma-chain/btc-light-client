# Bitcoin Mirror

**[bitcoinmirror.org](https://bitcoinmirror.org)**

```
                                        #
                                       # #
                                      # # #
                                     # # # #
                                    # # # # #
                                   # # # # # #
                                  # # # # # # #
                                 # # # # # # # #
                                # # # # # # # # #
                               # # # # # # # # # #
                              # # # # # # # # # # #
                                   # # # # # #
                               +        #        +
                                ++++         ++++
                                  ++++++ ++++++
                                    +++++++++
                                      +++++
                                        +
```

## Bitcoin Mirror tracks Bitcoin on Ethereum

This lets you prove a Bitcoin payment. In other words, it's a Bitcoin light client that runs on the EVM.

## Quick Start

### Compile and test the contract

Install [Forge](https://getfoundry.sh/). Then:

```
cd packages/contracts
forge test -vv
```

### Run the submitter

Point Cloudflare Functions to your fork of the repo using `wrangler`.

The submitter will run automatically and reliably, on a schedule. See `wrangler.toml`.

You'll need to configure a few secrets, including `ETH_SUBMITTER_PRIVATE_KEY` and `ETH_RPC_URL`. You'll also need a free API key for [getblock.io](https://getblock.io). Set `GETBLOCK_API_KEY`.

```shell
npx wrangler dev --local -e mainnet
```

### Run the website

```
cd packages/website
npm ci
npm start
```

### Deploy the contract

Ensure `ETHERSCAN_API_KEY` is set. Then, run the following to deploy and verify.

```
cd packages/contracts
forge script DeployBtcMirror --rpc-url 127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 -s 'run(bool)' --broadcast --force true
```

Run with `false` for a deployment tracking the Bitcoin testnet rather than mainnet.
