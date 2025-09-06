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
        params.router = 0x89b8AA89FDd0507a99d334CBe3C808fAFC7d850E;
        params.zero = payable(0x0000000000000000000000000000000000000000);
        params.usdt_address = 0x55d398326f99059fF775485246999027B3197955;
        params.usdc_address = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
        params.amount_to_swap = 11e17;

        // for bsc
        params.impl_index_address = payable(0x28466e3e92CB6FB292618D0faEbB49624f4d6f0C);
        params.factory_address = 0xBDb5201565925AE934A5622F0E7091aFFceed5EB;

        // define master wallet
        console2.log("chain_id=", block.chainid);
        if (block.chainid == 56) {
            params.master_address = payable(0x8d1454F9ac6363e20664C1AE29bF47C38a354f25);
        } else if (block.chainid == 11155111) {
            params.master_address = payable(0x952aa40B73CceCf866c25D4f42fBBDbc35164002);
        } else {
            params.master_address = params.zero;
        }
    }

    function run() public view {
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

        address[] memory targets = new address[](3);
        bytes[] memory dataArray = new bytes[](3);
        uint256[] memory values = new uint256[](3);

        targets[0] = pm.impl_index_address; //address(impl_index);
        targets[1] = pm.impl_index_address; //address(impl_index);
        targets[2] = pm.router;

        values[0] = 0;
        values[1] = 0;
        values[2] = 0;

        // bytes memory _dataIndex = abi.encodeWithSignature(
        //     "createWNFTonFactory2((address,string,string,string,address[],bytes32[],uint256[],bytes))",
        //     initData
        // );

        dataArray[0] = abi.encodeWithSignature(
            "createWNFTonFactory2((address,string,string,string,address[],bytes32[],uint256[],bytes))", initData
        );
        dataArray[1] = abi.encodeWithSignature(
            "createWNFTonFactory2((address,string,string,string,address[],bytes32[],uint256[],bytes))", initData
        );
        dataArray[2] =
            hex"83bd37f9000155d398326f99059ff775485246999027b319795500018ac76a51cc950d9822d68b83fe1ad97b32cd580d08016345785d8a000008016340d27492d77000c49b0001C46785891bc0dc3A1b88a6ba39A78aB7f5850846000126eDaedAEB73365de1b6A9305E95dCC9b4635A5D00018d1454F9ac6363e20664C1AE29bF47C38a354f2500000000030102030022010100010200ff000000000000000000000000000000000000000026edaedaeb73365de1b6a9305e95dcc9b4635a5d55d398326f99059ff775485246999027b3197955000000000000000000000000000000000000000000000000";

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
        address[] memory targets1 = new address[](4);
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
        values1[3] = address(master).balance / 2;

        /*vm.startBroadcast();
        // 2. call transaction batch - transfer assets
        // from 599 address
        bytes[] memory result = master.executeEncodedTxBatch(targets1, values1, dataArray1);
        vm.stopBroadcast();*/
    }
}
