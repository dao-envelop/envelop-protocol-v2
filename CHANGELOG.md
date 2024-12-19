# CHANGELOG

All notable changes to this project are documented in this file.

This changelog format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
## [Unreleased]
- Transient storage for several lock logic
- Deployment script for full set of contracts 
- Documentation (doc strings)

## [2.1.0](https://github.com/dao-envelop/envelop-protocol-v2/tree/2.1.0) - 2024-12-24
### Added
- `WNFTLegacy721  -implementation of WNFT that partial compatible with Envelop V1;
- Implementations: `WNFTV2Envelop721`, `WNFTMyshchWallet`;
- Wrapper contracr for WNFTLegacy721
- `EnvelopWNFTFactory` as main factory for Envelop V2 wNFTs (EIP 1167)
- `MyShchFactory` with smart wallet oriented features 
### Fixed
- New method in TokenService

## [2.0.0](https://github.com/dao-envelop/envelop-protocol-v2/tree/2.0.0) - 2024-06-12
### Added
- Type's lib
- Token Transfer service with ERC20, ERC721, ERC1155 support
### Fixed
- New method in TokenService

