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
$ forge script script/Deploy.s.sol:DeployScript --rpc-url sepolia  --account three --sender 0x97ba7778dD9CE27bD4953c136F3B3b7b087E14c1 --broadcast --verify  --etherscan-api-key $ETHERSCAN_TOKEN --priority-gas-price 30000

$ forge script script/DeployMyshchSet.s.sol:DeployMyshchSetScript --rpc-url sepolia  --account three --sender 0x97ba7778dD9CE27bD4953c136F3B3b7b087E14c1 --broadcast --verify  --etherscan-api-key $ETHERSCAN_TOKEN --priority-gas-price 30000

$ forge script script/DeployMyshchSet.s.sol:TestTxScript --rpc-url sepolia  --account three --sender 0x97ba7778dD9CE27bD4953c136F3B3b7b087E14c1 --broadcast --verify  --etherscan-api-key $ETHERSCAN_TOKEN --priority-gas-price 30000
```

### Bsc
```shell
$ forge script script/Deploy.s.sol:DeployScript --rpc-url bnb_smart_chain  --account envdeployer --sender 0xE1a8F0a249A87FDB9D8B912E11B198a2709D6d9B --broadcast --verify  --etherscan-api-key $BSCSCAN_TOKEN
```
2040072488354782710
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