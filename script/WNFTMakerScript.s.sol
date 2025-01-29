// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "./Objects.s.sol";
import {Script, console2} from "forge-std/Script.sol";
import "../lib/forge-std/src/StdJson.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";



// Deploy and init acions
contract WNFTMakerScript is Script, Objects {
    using stdJson for string;
    function run() public {

        address owner = 0x5992Fe461F81C8E0aFFA95b831E50e9b3854BA0E;
        address router = 0x89b8AA89FDd0507a99d334CBe3C808fAFC7d850E;
        address payable zero = payable(0x0000000000000000000000000000000000000000);
        address usdt_address = 0x55d398326f99059fF775485246999027B3197955;
        address usdc_address = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;

        uint256 amount_to_swap = 11e17;

         // for sepolia chain
        /*string memory params_json_file = vm.readFile(string.concat(vm.projectRoot(), "/script/chain_params.json"));

        string memory key;

        key = string.concat(".", vm.toString(block.chainid),".impl_index");
        address payable impl_index_address = payable(params_json_file.readAddress(key));

        key = string.concat(".", vm.toString(block.chainid),".factory");
        address factory_address = params_json_file.readAddress(key);*/

        // for bsc
        address payable impl_index_address = payable(0x28466e3e92CB6FB292618D0faEbB49624f4d6f0C);
        address factory_address = 0xBDb5201565925AE934A5622F0E7091aFFceed5EB;


        WNFTV2Index impl_index = WNFTV2Index(impl_index_address);
        EnvelopWNFTFactory factory = EnvelopWNFTFactory(factory_address);


        WNFTV2Envelop721.InitParams memory initData = WNFTV2Envelop721.InitParams(
            owner,
            'Envelop V2 Smart Index',
            'ENVELOPV2',
            'https://api.envelop.is/wallet',
            new address[](0),
            new bytes32[](0),
            new uint256[](2),
            ""
            );   

       

        //////////   Deploy master wallet  //////////////
        /*vm.startBroadcast();
        address payable _wnftIndex = payable(impl_index.createWNFTonFactory(initData));
        console2.log('_wnftIndex = ', _wnftIndex);
        vm.stopBroadcast();*/

        // define master wallet
        address payable master_address;
        console2.log('chain_id=', block.chainid);
        if (block.chainid == 56) {
            master_address = payable(0x8d1454F9ac6363e20664C1AE29bF47C38a354f25);
        } else if  (block.chainid == 11155111) {
            master_address = payable(0x952aa40B73CceCf866c25D4f42fBBDbc35164002);
        } else {
            master_address = zero;
        }

        WNFTV2Index master = WNFTV2Index(master_address); // sepolia master wallet address

        // prepare batch of transactions

        // 0. make approve for router
        address target = usdt_address;
        bytes memory _data = abi.encodeWithSignature(
            "approve(address,uint256)",
            router,amount_to_swap
        );
        uint256 value = 0;

        // 1. create child wallets (indexes)

        address[] memory targets = new address[](3);
        bytes[] memory dataArray = new bytes[](3);
        uint256[] memory values = new uint256[](3);

        targets[0] = address(impl_index);
        targets[1] = address(impl_index);
        targets[2] = router;

        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        

        bytes memory _dataIndex = abi.encodeWithSignature(
            "createWNFTonFactory2((address,string,string,string,address[],bytes32[],uint256[],bytes))",
            initData
        );

        dataArray[0] = _dataIndex;
        dataArray[1] = _dataIndex;
        dataArray[2] = hex"84a7f3dd01020001C46785891bc0dc3A1b88a6ba39A78aB7f58508460b097854efd41c1580000000000155d398326f99059ff775485246999027b3197955072386f26fc10000000000018ac76a51cc950d9822d68b83fe1ad97b32cd580d043b98a0c900018d1454F9ac6363e20664C1AE29bF47C38a354f250000059ddceea5c400018d1454F9ac6363e20664C1AE29bF47C38a354f2500000000060203060187d79f49030102010203001e000e0200040301040600000203020100010501140001ff000000000000000000000000000000000000000000000000006190e79064213e6a2997355153f57904fb4910c3764aecc7c8136f4501f75b3187ef6f8246c976ed55d398326f99059ff775485246999027b319795547a90a2d92a8367a91efa1906bfc8c1e05bf10c4431e0cd023a32532bf3969cddfc002c00e98429d00000000000000000000000000000000000000000000000000000000";
    

        // calc child wallet addresses
        bytes32 salt = keccak256(abi.encode(address(impl_index), impl_index.nonce() + 1));
        address calcW1 = factory.predictDeterministicAddress(address(impl_index), salt);
        salt = keccak256(abi.encode(address(impl_index), impl_index.nonce() + 2));
        address calcW2 = factory.predictDeterministicAddress(address(impl_index), salt);

        /*vm.startBroadcast();
        // 0. make approve 
        //bytes memory result = master.executeEncodedTx(target, value, _data);

        // 1. call transaction batch - with swap
        // from 599 address
        bytes[] memory result = master.executeEncodedTxBatch(targets, values, dataArray);
        vm.stopBroadcast();*/

        // get child wallet adresses from output
        address payable w1 =  payable(abi.decode(result[0],
             (address)
        ));

        address payable w2 =  payable(abi.decode(result[1],
             (address)
        ));

        console2.log('child wallet 1 = ', w1);
        console2.log('child wallet 2 = ', w2);

        // 2. transfer assets from master to indexes
        address payable index_address1 = payable(0x61d9aFFa2f76fa83Fd8cA890Cc00Ee6c286bD502);
        address payable index_address2 = payable(0x153A2c68FB748Ca01b99E5146e81443aa1dEE295);
        address[] memory targets1 = new address[](4);
        bytes[] memory dataArray1 = new bytes[](4);
        uint256[] memory values1 = new uint256[](4);
        targets1[0] = usdc_address;
        targets1[1] = usdc_address;
        targets1[2] = index_address1;
        targets1[3] = index_address2;

        dataArray1[0] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            index_address1,IERC20(usdc_address).balanceOf(master_address)/2
        );
        dataArray1[1] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            index_address2,IERC20(usdc_address).balanceOf(master_address)/2
        );
        dataArray1[2] = "";
        dataArray1[3] = "";

        values1[0] = 0;
        values1[1] = 0;
        values1[2] = address(master).balance / 2;
        values1[3] = address(master).balance / 2;

        /*vm.startBroadcast();
        // 2. call transaction batch - transfer assets
        // from 599 address
        bytes[] memory result = master.executeEncodedTxBatch(targets1, values1, dataArray1);
        vm.stopBroadcast();*/




    }
}
