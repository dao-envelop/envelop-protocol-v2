@AGENTS.md
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Envelop Protocol V2 — a multi-chain Solidity protocol for wrapping NFTs (wNFTs) to add collateral, rules, and utility. Uses Foundry as the primary framework. Deployed on Ethereum, Arbitrum, BSC, Avalanche, Polygon, Optimism, Blast, and Gnosis Chain.

## Commands

```bash
# Build
forge build
forge build --sizes        # includes contract sizes

# Test
forge test                 # run all tests
forge test -vvv            # verbose output

# Run a single test file
forge test --match-path test/Factory_Test_a_01.sol -vvv

# Run a single test function
forge test --match-contract Factory_Test_a_01 --match-function test_create_legacy -vvv

# Fuzz tests
forge test --match-path test/fuzz/ -vvv

# Update dependencies
forge update
git submodule update --init --recursive

# Compute storage slot hashes
forge script script/GetStorageSlot.s.sol:GetStorageSlot
```

## Architecture

### Core Pattern: Factory + EIP-1167 Proxies

`EnvelopWNFTFactory` (and `MyShchFactory`) create lightweight clone proxies of implementation contracts. Implementations are deployed once; each wNFT is a separate proxy initialized with `InitParams`. The factory maintains a trusted wrapper allowlist.

```
Caller → EnvelopWNFTFactory.createWNFT()
           → EIP-1167 proxy clone of an implementation
           → Implementation.initialize(InitParams)
              → TokenService (transfers inbound NFT + collateral)
```

### Implementations (`src/impl/`)

| Contract | Purpose |
|----------|---------|
| `WNFTV2Envelop721` | Primary wNFT with signature-based execution |
| `WNFTLegacy721` | Partial V1 compatibility |
| `WNFTMyshchWallet` | Smart wallet-oriented wNFT |
| `WNFTV2Index` | Price-tracking index wNFT |
| `Singleton721` | Base ERC721 implementation |
| `SmartWallet` | Smart wallet execution logic |

### Rules/Locks System

wNFTs carry a `bytes2` rules bitmask (e.g., No_Transfer, No_Collateral) and optional locks (time, balance, custom). Unwrapping checks all locks before releasing collateral and the underlying NFT. Lock/rule logic is in `LibET.sol`.

### Namespaced Storage (EIP-7201-style)

All contracts use OZ 2.0 namespaced storage slots to prevent inheritance collisions:
```
slot = keccak256(abi.encode(uint256(keccak256("envelop.storage.CONTRACT_NAME")) - 1)) & ~bytes32(uint256(0xff))
```

### Signature-Based Authorization

`WNFTV2Envelop721.executeEncodedTxBySignature()` allows trusted signers to execute operations on behalf of the wNFT. Per-address nonces prevent replay attacks.

### Oracle & Predictor

- `EnvelopOracle` — on-chain oracle integrating Chainlink VRF for randomness (`src/chainlink/`)
- `Predicter` — voting-based price prediction contract
- `WNFTV2Index` — tracks wNFT price index data

### TokenService

`TokenService.sol` abstracts all token movement (ERC20/721/1155), fee collection, and collateral management. Supports Permit2 for gasless approvals.

## Deployment Scripts (`script/`)

All scripts use Solidity with Foundry's `Script` base. `Objects.s.sol` defines base deployment logic: it reads `chain_params.json` by `block.chainid` and skips deployment if an address is already configured.

**Full deployment:**
```bash
source .env
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url <network> \
  --account <keystore-name> \
  --sender <address> \
  --broadcast --verify \
  --etherscan-api-key $ETHERSCAN_TOKEN
```

**Check chain configuration before deploying:**
```bash
forge script script/CheckChainParam.s.sol:CheckChainParam --rpc-url <network>
```

**Other scripts:** `DeployImplementation.s.sol`, `DeployEnvelopOracle.s.sol`, `DeployPredicter.s.sol`, `MyShchInit.s.sol`, `MintV2.s.sol`, `WNFTMakerScript.s.sol`.

Chain-specific addresses live in `script/chain_params.json` (keyed by `chainId`). Block explorer URLs are in `script/explorers.json`.

## Test Structure

- `test/Factory_Test_a_*.sol` — factory unit tests
- `test/WNFTV2Envelop721_Test_a_*.sol` — implementation unit tests
- `test/fork/` — fork tests against live chains
- `test/fuzz/` — fuzz tests (200 runs, configured in `foundry.toml`)
- Test naming: `_a_` = unit, `_m_` = integration/main, `_ai_` = AI-generated
- Helpers in `test/helpers/PredictionBuilder.sol`

## Key Configuration

- **`foundry.toml`** — compiler (0.8.28), optimizer (200 runs), RPC endpoints, Etherscan API keys, fuzz settings
- **`.env.example`** — required env vars: `WEB3_INFURA_PROJECT_ID`, `ETHERSCAN_TOKEN`, `WEB3_QUICKNODE_ID`
- **`remapp.json`** — custom import remappings for upgradeable OZ contracts

## Dependencies (git submodules in `lib/`)

- `forge-std` v1.9.6
- `openzeppelin-contracts` v5.5.0
- `openzeppelin-contracts-upgradeable` v5.5.0
- `openzeppelin-foundry-upgrades` v0.4.0
