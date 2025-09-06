// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Script, console2} from "forge-std/Script.sol";
import "../lib/forge-std/src/StdJson.sol";

import "../src/MyShchFactory.sol";
import "../src/impl/WNFTMyshchWallet.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
//import "../src/impl/WNFTV2Envelop721.sol";
import "../src/impl/WNFTMyshchWallet.sol";
import "../src/impl/CustomERC20.sol";

// Address:     0x7EC0BF0a4D535Ea220c6bD961e352B752906D568
// Private key: 0x1bbde125e133d7b485f332b8125b891ea2fbb6a957e758db72e6539d46e2cd71

// Address:     0x4b664eD07D19d0b192A037Cfb331644cA536029d
// Private key: 0x3480b19b170c5e63c0bdb18d08c4a99628194c7dceaf79e0e17431f4a5c7b1f2

// Address:     0xd7DE4B1214bFfd5C3E9Fb8A501D1a7bF18569882
// Private key: 0x8ba574046f1e9e372e805aa6c5dcf5598830df5a78605b7713bf00f2f3329148

// Address:     0x6F9aaAaD96180b3D6c71Fbbae2C1c5d5193A64EC
// Private key: 0xae8fe3985898986377b19cc6bdbb76723470552e95e4d028d2dae2691ab9c65d

/// DERRICATED ///
contract DeployMyshchSetScript is Script {
    using stdJson for string;

    struct Params {
        address factory;
        address impl_myshch;
        address impl_erc20;
        bool need_test_tx;
        address[] trusted_signers_list;
    }

    Params p;

    function run() public {
        console2.log("Chain id: %s", vm.toString(block.chainid));
        console2.log("Deployer address: %s, " "\n native balnce %s", msg.sender, msg.sender.balance);

        // Load json with chain params
        string memory params_json_file = vm.readFile(string.concat(vm.projectRoot(), "/script/chain_params.json"));
        string memory key;

        // Define constructor params
        key = string.concat(".", vm.toString(block.chainid), ".factory");
        if (vm.keyExists(params_json_file, key)) {
            p.factory = params_json_file.readAddress(key);
        } else {
            p.factory = address(0);
        }

        key = string.concat(".", vm.toString(block.chainid), ".trusted_signers_list");
        if (vm.keyExists(params_json_file, key)) {
            address[] memory aa = params_json_file.readAddressArray(key);
            for (uint256 i = 0; i < aa.length; ++i) {
                p.trusted_signers_list.push(aa[i]);
                console2.log("Trusted signer: %s", aa[i]);
            }

            // } else {
            //     p.impl_myshch = address(0);
        }

        key = string.concat(".", vm.toString(block.chainid), ".impl_myshch");
        if (vm.keyExists(params_json_file, key)) {
            p.impl_myshch = params_json_file.readAddress(key);
        } else {
            p.impl_myshch = address(0);
        }

        key = string.concat(".", vm.toString(block.chainid), ".impl_erc20");
        if (vm.keyExists(params_json_file, key)) {
            p.impl_erc20 = params_json_file.readAddress(key);
        } else {
            p.impl_erc20 = address(0);
        }

        key = string.concat(".", vm.toString(block.chainid), ".need_test_tx");
        if (vm.keyExists(params_json_file, key)) {
            p.need_test_tx = params_json_file.readBool(key);
        } else {
            p.need_test_tx = false;
        }

        // key = string.concat(".", vm.toString(block.chainid),".neededERC20Amount");
        // if (vm.keyExists(params_json_file, key))
        // {
        //     p.neededERC20Amount = params_json_file.readUint(key);
        // } else {
        //     p.neededERC20Amount = 0;
        // }
        // console2.log("neededERC20Amount: %s", p.neededERC20Amount);

        //////////   Deploy   //////////////
        vm.startBroadcast();
        MyShchFactory factory;
        WNFTMyshchWallet impl_myshch;
        CustomERC20 impl_erc20;

        if (p.impl_myshch == address(0)) {
            impl_myshch = new WNFTMyshchWallet(address(0));
            console2.log("Deploying implementation: %s", vm.toString(address(impl_myshch)));
        } else {
            impl_myshch = WNFTMyshchWallet(payable(p.impl_myshch));
        }

        if (p.impl_erc20 == address(0)) {
            impl_erc20 = new CustomERC20();
            console2.log("Deploying implementation: %s", vm.toString(address(impl_erc20)));
        } else {
            impl_erc20 = CustomERC20(p.impl_erc20);
        }

        if (p.factory == address(0)) {
            factory = new MyShchFactory(address(impl_myshch));
            console2.log("Deploying factory: %s", vm.toString(address(factory)));
        } else {
            factory = MyShchFactory(p.factory);
        }

        factory.newImplementation(MyShchFactory.AssetType.ERC20, address(impl_erc20));

        vm.stopBroadcast();

        ///////// Pretty printing ////////////////

        //string memory path = string.concat(vm.projectRoot(), "/script/explorers.json");
        //string memory json = vm.readFile(path);
        //params_path = string.concat(vm.projectRoot(), "/script/explorers.json");
        params_json_file = vm.readFile(string.concat(vm.projectRoot(), "/script/explorers.json"));

        console2.log("Chain id: %s", vm.toString(block.chainid));
        string memory explorer_url = params_json_file.readString(string.concat(".", vm.toString(block.chainid)));

        console2.log("\n**MyShchFactory**  ");
        console2.log("https://%s/address/%s#code\n", explorer_url, address(factory));

        console2.log("\n**WNFTMyshchWallet** ");
        console2.log("https://%s/address/%s#code\n", explorer_url, address(impl_myshch));

        console2.log("\n**CustomERC20** ");
        console2.log("https://%s/address/%s#code\n", explorer_url, address(impl_erc20));

        console2.log("```python");
        console2.log("factory = MyShchFactory.at('%s')", address(factory));
        console2.log("impl_myshch = WNFTMyshchWallet.at('%s')", address(impl_myshch));
        console2.log("impl_erc20 = CustomERC20.at('%s')", address(impl_erc20));
        console2.log("```");

        // ///////// End of pretty printing ////////////////

        // ///  Init ///
        console2.log("Init transactions....");
        vm.startBroadcast();
        for (uint256 i = 0; i < p.trusted_signers_list.length; ++i) {
            factory.setSignerStatus(p.trusted_signers_list[i], true);
            console2.log("Trusted signer added: %s", p.trusted_signers_list[i]);
        }

        vm.stopBroadcast();
        console2.log("Initialisation finished");
    }
}

contract TestTxScript is Script {
    using stdJson for string;

    struct Params {
        address factory;
        address impl_myshch;
        address impl_erc20;
        bool need_test_tx;
        address[] trusted_signers_list;
    }

    address public constant botEOA = 0x4b664eD07D19d0b192A037Cfb331644cA536029d;
    uint256 public constant botEOA_PRIVKEY = 0x3480b19b170c5e63c0bdb18d08c4a99628194c7dceaf79e0e17431f4a5c7b1f2;

    Params p;

    function run() public {
        console2.log("Chain id: %s", vm.toString(block.chainid));
        console2.log("Deployer address: %s, " "\n native balnce %s", msg.sender, msg.sender.balance);

        // Load json with chain params
        string memory params_json_file = vm.readFile(string.concat(vm.projectRoot(), "/script/chain_params.json"));
        string memory key;

        // Define constructor params
        key = string.concat(".", vm.toString(block.chainid), ".factory");
        if (vm.keyExists(params_json_file, key)) {
            p.factory = params_json_file.readAddress(key);
        } else {
            p.factory = address(0);
        }

        key = string.concat(".", vm.toString(block.chainid), ".trusted_signers_list");
        if (vm.keyExists(params_json_file, key)) {
            address[] memory aa = params_json_file.readAddressArray(key);
            for (uint256 i = 0; i < aa.length; ++i) {
                p.trusted_signers_list.push(aa[i]);
                console2.log("Trusted signer: %s", aa[i]);
            }

            // } else {
            //     p.impl_myshch = address(0);
        }

        key = string.concat(".", vm.toString(block.chainid), ".impl_myshch");
        if (vm.keyExists(params_json_file, key)) {
            p.impl_myshch = params_json_file.readAddress(key);
        } else {
            p.impl_myshch = address(0);
        }

        key = string.concat(".", vm.toString(block.chainid), ".impl_erc20");
        if (vm.keyExists(params_json_file, key)) {
            p.impl_erc20 = params_json_file.readAddress(key);
        } else {
            p.impl_erc20 = address(0);
        }

        key = string.concat(".", vm.toString(block.chainid), ".need_test_tx");
        if (vm.keyExists(params_json_file, key)) {
            p.need_test_tx = params_json_file.readBool(key);
        } else {
            p.need_test_tx = false;
        }

        if (p.need_test_tx) {
            console2.log("Test tx start...");
            vm.startBroadcast();

            MyShchFactory factory;
            WNFTMyshchWallet impl_myshch;
            CustomERC20 impl_erc20;
            if (p.impl_myshch != address(0)) {
                impl_myshch = WNFTMyshchWallet(payable(p.impl_myshch));
            }
            if (p.impl_erc20 != address(0)) {
                impl_erc20 = CustomERC20(payable(p.impl_erc20));
            }

            if (p.factory != address(0)) {
                factory = MyShchFactory(p.factory);
            }
            // Bot wnft wallet
            // need change  sender acc
            //botWNFT = payable(factory.mintPersonalMSW(BOT_TG_ID, ""));

            // Users wnft wallet
            bytes memory botSignature;
            bytes32 digest = MessageHashUtils.toEthSignedMessageHash(
                factory.getDigestForSign(22222, factory.currentNonce(22222) + 1)
            );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(botEOA_PRIVKEY, digest);
            botSignature = abi.encodePacked(r, s, v);
            factory.mintPersonalMSW{value: 7000}(22222, botSignature);

            // Custom ERC20
            factory.newImplementation(MyShchFactory.AssetType.ERC20, address(impl_erc20));
            MyShchFactory.InitDistributtion[] memory initDisrtrib = new MyShchFactory.InitDistributtion[](2);
            initDisrtrib[0] = MyShchFactory.InitDistributtion(address(1), 100);
            initDisrtrib[1] = MyShchFactory.InitDistributtion(address(2), 200);
            address custom_20address = factory.createCustomERC20(
                address(this), // _creator,
                "Custom ERC20 Name", // name_,
                "CUSTSYM", // symbol_,
                1_000_000e18, // _totalSupply,
                initDisrtrib // _initialHolders
            );

            vm.stopBroadcast();
            console2.log("Custom ERC20 token created: %s", custom_20address);
            console2.log("Test tx finished");
        }
    }
}
