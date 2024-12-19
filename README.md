# Envelop Protocol V2
![GitHub last commit](https://img.shields.io/github/last-commit/dao-envelop/envelop-protocol-v2)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/dao-envelop/envelop-protocol-v2)  
Protocol for providing true value and utilities to your NFT  

## Envelop Protocol V2 smart contracts  
This version of the protocol is currently being systematically developed. 

## License
All code provided with  `SPDX-License-Identifier: MIT`

## Deployment info 
This version has many deployments in different chains. Please follow the docs:  
https://docs.envelop.is/tech/smart-contracts/deployment-addresses-v2  

## Audit  
Coming soon

## Development  
For use cli from [scripts](./script/README.md) don't forget set appropriate variables in `.env` (see 
`.env.example`). Before call any scripts please init environment variables from .env :
```shell
$ # On linux
$ source .env
``` 

```shell
$ # Script for geting hash for staroge addresses
$ forge script script/GetStorageSlot.s.sol:GetStorageSlot
```


**Foundry**  is main framework for Envelop Protocol V2 

### First build
```shell
git clone  git@github.com:dao-envelop/envelop-protocol-v2.git 
git submodule update --init --recursive
```