## Deployments
`chain_params.json` - contains settings for all scripts.  
`explorers.json` - contains scanner's base URL  
`Objects.s.sol` - abstarct contract in this file implements all param's load logic, deploy & instantionate logic and print. So the base flow  is:
1. Implement all logic in `Objects.s.sol`, set params in `chain_params.json`.
2. Run `Deploy.s.sol`. Take output for fill `chain_params.json`.
3. Then  run test scripts (see examples below) or run script with specific tasks (i.e. `MyShchInit.s.sol`)  

To deploy full contract set please use `Deploy.s.sol`. Before deploy yo can check saved 
configuration with `CheckChainParam.s.sol`.  

!!! For use cli below don't forget set appropriate variables in `.env` from root folder (see Development section)  
### Sepolia
```shell
# Use for check chain_paarms  config
$ forge script script/CheckChainParam.s.sol:CheckChainParam --rpc-url sepolia

$ # Full set deployment
$ forge script script/Deploy.s.sol:DeployScript --rpc-url sepolia  --account three --sender 0x97ba7778dD9CE27bD4953c136F3B3b7b087E14c1 --broadcast --verify  --etherscan-api-key $ETHERSCAN_TOKEN --priority-gas-price 10000

$ # Test Tx Script
$ forge script script/Deploy.s.sol:TestTxScript --rpc-url sepolia  --account three --sender 0x97ba7778dD9CE27bD4953c136F3B3b7b087E14c1 --broadcast --verify  --etherscan-api-key $ETHERSCAN_TOKEN 

$ # MyShch Check & Init Signers Script
$ forge script script/MyShchInit.s.sol:MyShchInit --rpc-url sepolia  --account three --sender 0x97ba7778dD9CE27bD4953c136F3B3b7b087E14c1 --broadcast 

$ # MyShch create wallet with signature
$ forge script script/MyShchInit.s.sol:TestTxScript --rpc-url sepolia  --account three --sender 0x97ba7778dD9CE27bD4953c136F3B3b7b087E14c1 --broadcast 

$ forge verify-contract 0xa9A9B9d76c5449dCB4fF1B74E023bF3f6F8a30cf  ./src/EnvelopWNFTFactory.sol:EnvelopWNFTFactory  --verifier-api-key $ETHERSCAN_TOKEN --num-of-optimizations 200 --compiler-version 0.8.28

$ #######  Deploy ERC20 custom
$ cast send 0x7F3f876463e3f70634823be78F6f55E01720A068 "createCustomERC20(address,string,string,uint256,(address,uint256)[])" "0x97ba7778dD9CE27bD4953c136F3B3b7b087E14c1" "Test NIFTSY TOKEN 2025" "NIFTSY" "1000000000000000000000000000" "[]" --rpc-url sepolia  --account three 

$ cast send 0x7F3f876463e3f70634823be78F6f55E01720A068 "createCustomERC20(address,string,string,uint256,(address,uint256)[])" "0x97ba7778dD9CE27bD4953c136F3B3b7b087E14c1" "Test DAI Token" "NIFTSY" "2000000000000000000000000000" "[]" --rpc-url sepolia  --account three 

```


### Bsc
```shell
$ forge script script/CheckChainParam.s.sol:CheckChainParam --rpc-url bnb_smart_chain

$ #Deploy
$ forge script script/Deploy.s.sol:DeployScript --rpc-url bnb_smart_chain  --account env_deploy_2025 --sender 0x13B9cBcB46aD79878af8c9faa835Bee19B977D3D --broadcast --verify  --etherscan-api-key $ETHERSCAN_TOKEN 

$ # for verify just deployed
$ forge script script/Deploy.s.sol:DeployScript --rpc-url bnb_smart_chain  --account env_deploy_2025 --sender 0x13B9cBcB46aD79878af8c9faa835Bee19B977D3D --resume --verify  --etherscan-api-key $ETHERSCAN_TOKEN 

$ # Test Tx Script
$ forge script script/Deploy.s.sol:TestTxScript --rpc-url bnb_smart_chain  --account env_deploy_2025 --sender 0x13B9cBcB46aD79878af8c9faa835Bee19B977D3D --broadcast --etherscan-api-key $ETHERSCAN_TOKEN 

$ # MyShch Check & Init Signers Script
$ forge script script/MyShchInit.s.sol:MyShchInit --rpc-url bnb_smart_chain  --account env_deploy_2025 --sender 0x13B9cBcB46aD79878af8c9faa835Bee19B977D3D --broadcast 

$ # MyShch create wallet with signature
$ # MyShch create wallet with signature  - !!! Require to spent some native assset amount
$ forge script script/MyShchInit.s.sol:TestTxScript --rpc-url bnb_smart_chain  --account env_deploy_2025 --sender 0x13B9cBcB46aD79878af8c9faa835Bee19B977D3D --broadcast  --etherscan-api-key $ETHERSCAN_TOKEN 
```

### Arbitrum
```shell
$ #Check chain params
$ forge script script/CheckChainParam.s.sol:CheckChainParam --rpc-url arbitrum

$ #Deploy
$ forge script script/Deploy.s.sol:DeployScript --rpc-url arbitrum  --account env_deploy_2025 --sender 0x13B9cBcB46aD79878af8c9faa835Bee19B977D3D --broadcast --verify  --etherscan-api-key $ETHERSCAN_TOKEN 
$ # for verify just deployed
$ forge script script/Deploy.s.sol:DeployScript --rpc-url arbitrum  --account env_deploy_2025 --sender 0x13B9cBcB46aD79878af8c9faa835Bee19B977D3D --resume --verify  --etherscan-api-key $ETHERSCAN_TOKEN 

$ # Test Tx Script
$ forge script script/Deploy.s.sol:TestTxScript --rpc-url arbitrum  --account env_deploy_2025 --sender 0x13B9cBcB46aD79878af8c9faa835Bee19B977D3D --broadcast --verify  --etherscan-api-key $ETHERSCAN_TOKEN 

$ # Mint V2
$ forge script script/MintV2.s.sol:MintV2Script --rpc-url arbitrum  --account env_deploy_2025 --sender 0x13B9cBcB46aD79878af8c9faa835Bee19B977D3D --broadcast --etherscan-api-key $ETHERSCAN_TOKEN 

$ # MyShch Check & Init Signers Script
$ forge script script/MyShchInit.s.sol:MyShchInit --rpc-url arbitrum  --account env_deploy_2025 --sender 0x13B9cBcB46aD79878af8c9faa835Bee19B977D3D --broadcast 

$ # sending NFT
$ cast send 0x7963f799bcD782c61AeE63eACad6c7EB375Ea003 "transferFrom(address,address,uint256)" "0x13B9cBcB46aD79878af8c9faa835Bee19B977D3D" "0xB72993EbB94dc20E4140AFc99A4BC5E42D3d93B2" "1" --rpc-url arbitrum  --account env_deploy_2025 

$ #Deploy Implemenation
$ forge script script/DeployImplementation.s.sol:DeployImplementation --rpc-url arbitrum  --account env_deploy_2025 --sender 0x13B9cBcB46aD79878af8c9faa835Bee19B977D3D --broadcast --verify  --etherscan-api-key $ETHERSCAN_TOKEN 
```
