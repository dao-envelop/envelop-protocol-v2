## Deployments
!!! For use cli below don't forget set appropriate variables in `.env` (see Development section) 
### Sepolia
```shell
# Use for check chain_paarms  config
$ forge script script/CheckChainParam.s.sol:CheckChainParam --rpc-url sepolia

$ forge script script/Deploy.s.sol:DeployScript --rpc-url sepolia  --account three --sender 0x97ba7778dD9CE27bD4953c136F3B3b7b087E14c1 --broadcast --verify  --etherscan-api-key $ETHERSCAN_TOKEN 
$ # Test Tx Script
$ forge script script/Deploy.s.sol:TestTxScript --rpc-url sepolia  --account three --sender 0x97ba7778dD9CE27bD4953c136F3B3b7b087E14c1 --broadcast --verify  --etherscan-api-key $ETHERSCAN_TOKEN 

$ forge script script/DeployMyshchSet.s.sol:DeployMyshchSetScript --rpc-url sepolia  --account three --sender 0x97ba7778dD9CE27bD4953c136F3B3b7b087E14c1 --broadcast --verify  --etherscan-api-key $ETHERSCAN_TOKEN --priority-gas-price 30000

$ forge script script/DeployMyshchSet.s.sol:TestTxScript --rpc-url sepolia  --account three --sender 0x97ba7778dD9CE27bD4953c136F3B3b7b087E14c1 --broadcast --verify  --etherscan-api-key $ETHERSCAN_TOKEN --priority-gas-price 30000

$ forge verify-contract 0xa9A9B9d76c5449dCB4fF1B74E023bF3f6F8a30cf  ./src/EnvelopWNFTFactory.sol:EnvelopWNFTFactory  --verifier-api-key $ETHERSCAN_TOKEN --num-of-optimizations 200 --compiler-version 0.8.28

$ #######  Deploy ERC20 custom
$ cast send 0x7F3f876463e3f70634823be78F6f55E01720A068 "createCustomERC20(address,string,string,uint256,(address,uint256)[])" "0x97ba7778dD9CE27bD4953c136F3B3b7b087E14c1" "Test NIFTSY TOKEN 2025" "NIFTSY" "1000000000000000000000000000" "[]" --rpc-url sepolia  --account three 

$ cast send 0x7F3f876463e3f70634823be78F6f55E01720A068 "createCustomERC20(address,string,string,uint256,(address,uint256)[])" "0x97ba7778dD9CE27bD4953c136F3B3b7b087E14c1" "Test DAI Token" "NIFTSY" "2000000000000000000000000000" "[]" --rpc-url sepolia  --account three 

```


### Bsc
```shell
$ forge script script/CheckChainParam.s.sol:CheckChainParam --rpc-url bnb_smart_chain

$ #Deploy
$ forge script script/Deploy.s.sol:DeployScript --rpc-url bnb_smart_chain  --account env_deploy_2025 --sender 0x13B9cBcB46aD79878af8c9faa835Bee19B977D3D --broadcast --verify  --etherscan-api-key $BSCSCAN_TOKEN 

$ # Test Tx Script
$ forge script script/Deploy.s.sol:TestTxScript --rpc-url bnb_smart_chain  --account env_deploy_2025 --broadcast --verify  --etherscan-api-key $BSCSCAN_TOKEN 

```
