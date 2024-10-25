```shell
$ # Script for geting hash for staroge addresses
$ forge script script/GetStorageSlot.s.sol:GetStorageSlot
```
Deployments
#### Sepolia
```shell
$ #MyShch deploy
$ forge script script/DeployMyshchSet.s.sol:DeployMyshchSetScript --rpc-url sepolia  --account ttwo --sender 0xDDA2F2E159d2Ce413Bd0e1dF5988Ee7A803432E3 --broadcast --verify  --etherscan-api-key $ETHERSCAN_TOKEN

$ #MyShch test tx
$ forge script script/DeployMyshchSet.s.sol:TestTxScript --rpc-url sepolia  --account ttwo --sender 0xDDA2F2E159d2Ce413Bd0e1dF5988Ee7A803432E3 --broadcast --verify  --etherscan-api-key $ETHERSCAN_TOKEN
```