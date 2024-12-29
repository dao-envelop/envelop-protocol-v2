## Deployments
!!! For use cli below don't forget set appropriate variables in `.env` (see Development section) 
### Sepolia
```shell
$ forge script script/Deploy.s.sol:DeployScript --rpc-url sepolia  --account three --sender 0x97ba7778dD9CE27bD4953c136F3B3b7b087E14c1 --broadcast --verify  --etherscan-api-key $ETHERSCAN_TOKEN 
$ # Test Tx Script
$ forge script script/Deploy.s.sol:TestTxScript --rpc-url sepolia  --account three --sender 0x97ba7778dD9CE27bD4953c136F3B3b7b087E14c1 --broadcast --verify  --etherscan-api-key $ETHERSCAN_TOKEN 

$ forge script script/DeployMyshchSet.s.sol:DeployMyshchSetScript --rpc-url sepolia  --account three --sender 0x97ba7778dD9CE27bD4953c136F3B3b7b087E14c1 --broadcast --verify  --etherscan-api-key $ETHERSCAN_TOKEN --priority-gas-price 30000

$ forge script script/DeployMyshchSet.s.sol:TestTxScript --rpc-url sepolia  --account three --sender 0x97ba7778dD9CE27bD4953c136F3B3b7b087E14c1 --broadcast --verify  --etherscan-api-key $ETHERSCAN_TOKEN --priority-gas-price 30000

$ #######  Deploy ERC20 custom
$ cast send 0x7F3f876463e3f70634823be78F6f55E01720A068 "createCustomERC20(address,string,string,uint256,(address,uint256)[])" "0x97ba7778dD9CE27bD4953c136F3B3b7b087E14c1" "Test NIFTSY TOKEN 2025" "NIFTSY" "1000000000000000000000000000" "[]" --rpc-url sepolia  --account three 

$ cast send 0x7F3f876463e3f70634823be78F6f55E01720A068 "createCustomERC20(address,string,string,uint256,(address,uint256)[])" "0x97ba7778dD9CE27bD4953c136F3B3b7b087E14c1" "Test DAI Token" "NIFTSY" "2000000000000000000000000000" "[]" --rpc-url sepolia  --account three 

```


### Bsc
```shell
$ forge script script/Deploy.s.sol:DeployScript --rpc-url bnb_smart_chain  --account envdeployer --sender 0xE1a8F0a249A87FDB9D8B912E11B198a2709D6d9B --broadcast --verify  --etherscan-api-key $BSCSCAN_TOKEN
```
