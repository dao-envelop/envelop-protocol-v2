# CHANGELOG

All notable changes to this project are documented in this file.

This changelog format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
## [Unreleased]
- Deployment script for full set of contracts 
- Documentation (doc strings)

## [2.2.1](https://github.com/dao-envelop/envelop-protocol-v2/tree/2.2.1) - 2026-05-17
### Added
 - `IIndexAssets` and `IAMMPriceAdapter` interfaces for upcoming smart-index pricing
 - `EnvelopOracle` index-asset pricing support (basket pricing via Chainlink + AMM adapter)
 - Spec and implementation plan for `WNFTV2SmartIndex` and `AbstractOnChainMetadata`
### Changed
 - `forge build` is now warning-free: silence OZ-lib solc noise, scope `forge-lint` to `src/` only
### Fixed
 - Replace truncating casts (`uint96`, `uint256`, `bytes`→`uint256`) with `SafeCast` / `abi.decode` in `Predicter`, `EnvelopOracle`, and `EnvelopLegacyWrapperBaseV2`
### Security
 - **Singleton721** — `setApprovalForAll` no longer grants wallet-execution rights. Per-token `approve(operator, TOKEN_ID)` is kept as the intentional "ownership = wallet" delegation. Closes audit Finding #1.
 - **WNFTMyshchWallet.getRefund** — refund formula anchored to `block.basefee` (was attacker-controlled `tx.gasprice`) and requires `MIN_REFUND_WORK_GAS` of real work between `setGasCheckPoint` and `getRefund`. Closes audit Finding #2.

## [2.2.0](https://github.com/dao-envelop/envelop-protocol-v2/tree/2.1.0) - 2026-01-18
### Added
 - WNFTV2Index implementation 
 - Predicot base contract for implement users voting for index pric
 - Simple onchain Oracle contract
 - Upgrade OZ dependencies to 5.5.0
### Fixed
 - Minimize potential reentrancy
 - Separate url for myshch wallets
 - Transient storage added for several lock logic (EIP-1153)


## [2.1.0](https://github.com/dao-envelop/envelop-protocol-v2/tree/2.1.0) - 2024-12-19
### Added
- `WNFTLegacy721  -implementation of WNFT that partial compatible with Envelop V1;
- Implementations: `WNFTV2Envelop721`, `WNFTMyshchWallet`;
- Wrapper contracr for WNFTLegacy721
- `EnvelopWNFTFactory` as main factory for Envelop V2 wNFTs (EIP 1167)
- `MyShchFactory` with smart wallet oriented features 


## [2.0.0](https://github.com/dao-envelop/envelop-protocol-v2/tree/2.0.0) - 2024-06-12
### Added
- Type's lib
- Token Transfer service with ERC20, ERC721, ERC1155 support
### Fixed
- New method in TokenService

