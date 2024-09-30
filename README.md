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
https://docs.envelop.is/tech/smart-contracts/deployment-addresses  

### Sepolia
```shell
$ forge script script/Deploy.s.sol:DeployScript --rpc-url sepolia  --account ttwo --sender 0xDDA2F2E159d2Ce413Bd0e1dF5988Ee7A803432E3 --broadcast --verify  --etherscan-api-key $ETHERSCAN_TOKEN
```

## Audit  
Coming soon

## Dev 
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