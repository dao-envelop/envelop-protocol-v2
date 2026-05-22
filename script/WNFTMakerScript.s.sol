// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "./Objects.s.sol";
import {Script, console2} from "forge-std/Script.sol";
import "../lib/forge-std/src/StdJson.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Deploy and init acions
contract WNFTMakerScript is Script {
    using stdJson for string;

    struct ParamsForMaker {
        address owner;
        address router;
        address payable zero;
        address usdt_address;
        address usdc_address;
        uint256 amount_to_swap;
        address factory_address;
        address payable impl_index_address;
        address payable master_address;
    }

    function getParams() internal view returns (ParamsForMaker memory params) {
        params.owner = 0x5992Fe461F81C8E0aFFA95b831E50e9b3854BA0E;
        params.router = 0xCf5540fFFCdC3d510B18bFcA6d2b9987b0772559;
        params.zero = payable(0x0000000000000000000000000000000000000000);
        params.usdt_address = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        params.amount_to_swap = 1e6;

        // for bsc
        params.impl_index_address = payable(0xe738Cd578E1Adc6C7da7F0796775F4cEfb37D146);

        // define master wallet
        console2.log("chain_id=", block.chainid);
        if (block.chainid == 56) {
            params.master_address = payable(0x8d1454F9ac6363e20664C1AE29bF47C38a354f25);
        } else if (block.chainid == 1) {
            params.master_address = payable(0x85CD3a8306e9Ef836b1FE1Cd29A961fA73729981);
        } else {
            params.master_address = params.zero;
        }
    }

    function run() public {
        ParamsForMaker memory pm = getParams();

        //WNFTV2Index impl_index = WNFTV2Index(pm.impl_index_address);
        //EnvelopWNFTFactory factory = EnvelopWNFTFactory(pm.factory_address);

        WNFTV2Envelop721.InitParams memory initData = WNFTV2Envelop721.InitParams(
            pm.owner,
            "Envelop V2 Smart Index",
            "ENVELOPV2",
            "https://api.envelopm.is/wallet",
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

        WNFTV2Index master = WNFTV2Index(pm.master_address); // sepolia master wallet address

        // prepare batch of transactions

        // 0. make approve for router
        //address target = pm.usdt_address;
        // bytes memory _data = abi.encodeWithSignature(
        //     "approve(address,uint256)",
        //     pm.router,pm.amount_to_swap
        // );
        //uint256 value = 0;

        // 1. create child wallets (indexes)

        address[] memory targets = new address[](8);
        bytes[] memory dataArray = new bytes[](8);
        uint256[] memory values = new uint256[](8);

        targets[0] = pm.impl_index_address; //address(impl_index);
        //targets[1] = pm.usdt_address; //address(impl_index);
        //targets[2] = pm.usdt_address; //address(impl_index);
        targets[1] = pm.router;
        targets[2] = pm.router;
        targets[3] = pm.router;
        targets[4] = pm.router;
        targets[5] = pm.router;
        targets[6] = pm.router;
        targets[7] = pm.router;

        values[0] = 0;
        values[1] = 15e13;
        values[2] = 15e13;
        values[3] = 15e13;
        values[4] = 15e13;
        values[5] = 15e13;
        values[6] = 15e13;
        values[7] = 10e13;
        //values[8] = 0;
        //values[9] = 0;

        // bytes memory _dataIndex = abi.encodeWithSignature(
        //     "createWNFTonFactory2((address,string,string,string,address[],bytes32[],uint256[],bytes))",
        //     initData
        // );

        dataArray[0] = abi.encodeWithSignature(
            "createWNFTonFactory2((address,string,string,string,address[],bytes32[],uint256[],bytes))", initData
        );
        /*dataArray[1] = abi.encodeWithSignature(
            "approve(address,uint256)", pm.router, 0
        );
        dataArray[2] = abi.encodeWithSignature(
            "approve(address,uint256)", pm.router, pm.amount_to_swap
        );*/

        dataArray[1] = hex"83bd37f9000000015a98fcbea516cf06857215779fd812ca3bef1b3206886c98b76000080c7c6c9e51fbdc8000c49b0001365084B05Fa7d5028346bD21D842eD0601bAB5b80000000185CD3a8306e9Ef836b1FE1Cd29A961fA737299810000000003010203005401010201000201a4020202ff00000000000000000000000000000000000000000000000000000000000000000000005a98fcbea516cf06857215779fd812ca3bef1b32000000000000000000000000000000000000000000000000";
        dataArray[2] = hex"83bd37f900000001fe0c30065b384f05761f15d0cc899d4f9f9cc0eb06886c98b76000080baab952a0a5bf0000c49b0001365084B05Fa7d5028346bD21D842eD0601bAB5b80000000185CD3a8306e9Ef836b1FE1Cd29A961fA737299810000000003010203000e010101020100271000006400ff00000000000000000000000000000000000000000000000000000000000000000000fe0c30065b384f05761f15d0cc899d4f9f9cc0eb000000000000000000000000000000000000000000000000";
        dataArray[3] = hex"83bd37f900000001808507121b80c02388fad14726482e061b8da82706886c98b7600008028ba5af7409854000c49b0001365084B05Fa7d5028346bD21D842eD0601bAB5b80000000185CD3a8306e9Ef836b1FE1Cd29A961fA737299810000000003010203000e0101010201000bb800003c00ff00000000000000000000000000000000000000000000000000000000000000000000808507121b80c02388fad14726482e061b8da827000000000000000000000000000000000000000000000000";
        dataArray[4] = hex"83bd37f90000000101791f726b4103694969820be083196cc7c045ff06886c98b76000082992d7d64799500000c49b0001365084B05Fa7d5028346bD21D842eD0601bAB5b80000000185CD3a8306e9Ef836b1FE1Cd29A961fA73729981000000000301020300060101020d0001010200ff00000000000000000000000000000000006f582cf72ea9084a109be3d04eb58477b869a38ec02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000000000";
        dataArray[5] = hex"83bd37f90000000157e114b691db790c35207b2e685d4a43181e606106886c98b76000082a29d121ab21520000c49b0001365084B05Fa7d5028346bD21D842eD0601bAB5b80000000185CD3a8306e9Ef836b1FE1Cd29A961fA737299810000000003010203000e0101010201000bb800003c00ff0000000000000000000000000000000000000000000000000000000000000000000057e114b691db790c35207b2e685d4a43181e6061000000000000000000000000000000000000000000000000";
        dataArray[6] = hex"83bd37f90000000156072c95faa701256059aa122697b133aded927906886c98b76000083feb7c6f654fc60000c49b0001365084B05Fa7d5028346bD21D842eD0601bAB5b80000000185CD3a8306e9Ef836b1FE1Cd29A961fA737299810000000003010203000e0101010201000bb800003c00ff0000000000000000000000000000000000000000000000000000000000000000000056072c95faa701256059aa122697b133aded9279000000000000000000000000000000000000000000000000";
        dataArray[7] = hex"83bd37f9000000016f40d4a6237c257fff2db00fa0510deeecd303eb065af3107a40000801dee7ffedbbc84000c49b0001365084B05Fa7d5028346bD21D842eD0601bAB5b80000000185CD3a8306e9Ef836b1FE1Cd29A961fA7372998100000000050102060041010001020302410001040305ff0000000000000000000000000000b1cd6e4153b2a390cf00a6556b0fc1458c4a553300000000000000000000000000000000000000001f573d6fb3f13d689ff844b4ce37794d79a7ff1cae991deb2350f455ab3d8e4d830ba8cf773550a76f40d4a6237c257fff2db00fa0510deeecd303eb00000000000000000000000000000000000000000000000000000000";

        /*dataArray[2] =
            hex"83bd37f90001dac17f958d2ee523a2206206994597c13d831ec700015a98fcbea516cf06857215779fd812ca3bef1b32030249f00805db08d18bbee48000c49b0001365084B05Fa7d5028346bD21D842eD0601bAB5b80001Ae933d0a8D630e30A2e035284e35F232F4590e33000185CD3a8306e9Ef836b1FE1Cd29A961fA73729981000000000401020500030102000203001e02030001000104001eff00000000000000000000c558f600b34a5f69dd2f0d06cb8a88d829b7420aae933d0a8d630e30a2e035284e35f232f4590e33dac17f958d2ee523a2206206994597c13d831ec7c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000";
        dataArray[3] =
            hex"83bd37f90001dac17f958d2ee523a2206206994597c13d831ec70001fe0c30065b384f05761f15d0cc899d4f9f9cc0eb030249f0080551fdb3f67530c000c49b0001365084B05Fa7d5028346bD21D842eD0601bAB5b80000000185CD3a8306e9Ef836b1FE1Cd29A961fA737299810000000003010203000d0101010201ff00000000000000000000000000000000000000000080fa4c1fd0fbb9a4f071999af69531dee1016644dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000000000000000000000000000";
        dataArray[4] =
            hex"83bd37f90001dac17f958d2ee523a2206206994597c13d831ec70001808507121b80c02388fad14726482e061b8da827030249f008011a4f79d8d54ce000c49b0001365084B05Fa7d5028346bD21D842eD0601bAB5b80001Ae933d0a8D630e30A2e035284e35F232F4590e33000185CD3a8306e9Ef836b1FE1Cd29A961fA73729981000000000401020500030100000102001e020d0001030400ff000000000000000000000000ae933d0a8d630e30a2e035284e35f232f4590e33dac17f958d2ee523a2206206994597c13d831ec757af956d3e2cca3b86f3d8c6772c03ddca3eaacbc02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000";
        dataArray[5] =
            hex"83bd37f90001dac17f958d2ee523a2206206994597c13d831ec7000101791f726b4103694969820be083196cc7c045ff030249f0081332ee2f74c62d0000c49b0001365084B05Fa7d5028346bD21D842eD0601bAB5b80001Ae933d0a8D630e30A2e035284e35F232F4590e33000185CD3a8306e9Ef836b1FE1Cd29A961fA73729981000000000401020500030100000102001e020d0001030400ff000000000000000000000000ae933d0a8d630e30a2e035284e35f232f4590e33dac17f958d2ee523a2206206994597c13d831ec76f582cf72ea9084a109be3d04eb58477b869a38ec02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000";
        dataArray[6] =
            hex"83bd37f90001dac17f958d2ee523a2206206994597c13d831ec7000157e114b691db790c35207b2e685d4a43181e6061030249f008136700e39c30b30000c49b0001365084B05Fa7d5028346bD21D842eD0601bAB5b80001Ae933d0a8D630e30A2e035284e35F232F4590e33000185CD3a8306e9Ef836b1FE1Cd29A961fA73729981000000000401020500030100000102001e020d0001030400ff000000000000000000000000ae933d0a8d630e30a2e035284e35f232f4590e33dac17f958d2ee523a2206206994597c13d831ec7ae4045ffeddf61d570e6d1fe2d71ded1a2e85a88c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000";
        dataArray[7] =
            hex"83bd37f90001dac17f958d2ee523a2206206994597c13d831ec7000156072c95faa701256059aa122697b133aded9279030249f0081d9e2b8c4d59c20000c49b0001365084B05Fa7d5028346bD21D842eD0601bAB5b80001Ae933d0a8D630e30A2e035284e35F232F4590e33000185CD3a8306e9Ef836b1FE1Cd29A961fA73729981000000000401020500030100000102001e020d0001030400ff000000000000000000000000ae933d0a8d630e30a2e035284e35f232f4590e33dac17f958d2ee523a2206206994597c13d831ec7764510ab1d39cf300e7abe8f5b8977d18f290628c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000";
        dataArray[8] =
            hex"83bd37f90001dac17f958d2ee523a2206206994597c13d831ec700016f40d4a6237c257fff2db00fa0510deeecd303eb030186a007dfeae66aae43f800c49b0001365084B05Fa7d5028346bD21D842eD0601bAB5b80000000185CD3a8306e9Ef836b1FE1Cd29A961fA7372998100000000050102060041010001020302410001040305ff00000000000000000000000000005365b5bc56493f08a38e5eb08e36cbbe6fcc8306dac17f958d2ee523a2206206994597c13d831ec71f573d6fb3f13d689ff844b4ce37794d79a7ff1cae991deb2350f455ab3d8e4d830ba8cf773550a76f40d4a6237c257fff2db00fa0510deeecd303eb00000000000000000000000000000000000000000000000000000000";*/

        // calc child wallet addresses
        /*bytes32 salt = keccak256(abi.encode(address(impl_index), pm.master_address, impl_index.nonce(pm.master_address) + 1));
        address calcW1 = factory.predictDeterministicAddress(address(impl_index), salt);
        salt = keccak256(abi.encode(address(impl_index), pm.master_address, impl_index.nonce(pm.master_address) + 2));
        address calcW2 = factory.predictDeterministicAddress(address(impl_index), salt);*/

        //vm.startBroadcast();
        // 0. make approve
        //bytes memory result = master.executeEncodedTx(target, value, _data);

        // 1. call transaction batch - with swap
        // from 599 address
        //bytes[] memory result = master.executeEncodedTxBatch(targets, values, dataArray);
        //vm.stopBroadcast();

        // get child wallet adresses from output
        /*address payable w1 =  payable(abi.decode(result[0],
             (address)
        ));

        address payable w2 =  payable(abi.decode(result[1],
             (address)
        ));*/

        //console2.log('child wallet 1 = ', w1);
        //console2.log('child wallet 2 = ', w2);

        // use this code for next action
        // 2. transfer assets from master to indexes
        //address payable index_address1 = payable(0x61d9aFFa2f76fa83Fd8cA890Cc00Ee6c286bD502);
        //address payable index_address2 = payable(0x153A2c68FB748Ca01b99E5146e81443aa1dEE295);
        /*address[] memory targets1 = new address[](4);
        bytes[] memory dataArray1 = new bytes[](4);
        uint256[] memory values1 = new uint256[](4);
        targets1[0] = pm.usdc_address;
        targets1[1] = pm.usdc_address;
        targets1[2] = payable(0x61d9aFFa2f76fa83Fd8cA890Cc00Ee6c286bD502);
        targets1[3] = payable(0x153A2c68FB748Ca01b99E5146e81443aa1dEE295);

        dataArray1[0] = abi.encodeWithSignature(
            "transfer(address,uint256)", targets1[2], IERC20(pm.usdc_address).balanceOf(pm.master_address) / 2
        );
        dataArray1[1] = abi.encodeWithSignature(
            "transfer(address,uint256)", targets1[3], IERC20(pm.usdc_address).balanceOf(pm.master_address) / 2
        );
        dataArray1[2] = "";
        dataArray1[3] = "";

        values1[0] = 0;
        values1[1] = 0;
        values1[2] = address(master).balance / 2;
        values1[3] = address(master).balance / 2;*/

        vm.startBroadcast();
        // 2. call transaction batch
        // from 599 address
        bytes[] memory result = master.executeEncodedTxBatch(targets, values, dataArray);
        vm.stopBroadcast();
    }
}
