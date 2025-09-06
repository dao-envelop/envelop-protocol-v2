// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Script, console2} from "forge-std/Script.sol";
import "../lib/forge-std/src/StdJson.sol";
import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import {MyShchFactory} from "../src/MyShchFactory.sol";
import "../src/impl/WNFTMyshchWallet.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import "../src/impl/WNFTLegacy721.sol";
import "../src/impl/WNFTV2Envelop721.sol";
import "../src/impl/WNFTMyshchWallet.sol";
import "../src/impl/WNFTV2Index.sol";
import "../src/impl/CustomERC20.sol";
import {EnvelopLegacyWrapperBaseV2} from "../src/EnvelopLegacyWrapperBaseV2.sol";


// Address:     0x7EC0BF0a4D535Ea220c6bD961e352B752906D568
// Private key: 0x1bbde125e133d7b485f332b8125b891ea2fbb6a957e758db72e6539d46e2cd71

// Address:     0x4b664eD07D19d0b192A037Cfb331644cA536029d
// Private key: 0x3480b19b170c5e63c0bdb18d08c4a99628194c7dceaf79e0e17431f4a5c7b1f2

// Address:     0xd7DE4B1214bFfd5C3E9Fb8A501D1a7bF18569882
// Private key: 0x8ba574046f1e9e372e805aa6c5dcf5598830df5a78605b7713bf00f2f3329148

// Address:     0x6F9aaAaD96180b3D6c71Fbbae2C1c5d5193A64EC
// Private key: 0xae8fe3985898986377b19cc6bdbb76723470552e95e4d028d2dae2691ab9c65d

// This abstarct contract describe deploy and instantionate rules in project
// Base logic is following
// if address exists in  `chain_params.json` then no deployments will occure but only instance
// All deploy actions  are always in inheritors
abstract contract Objects is Script {
    using stdJson for string;

    struct Params {
        address factory;
        address myshch_factory;
        address legacy_wrapper;
        address impl_legacy;
        address impl_native;
        address impl_myshch;
        address impl_index;
        address impl_erc20;
        bool need_test_tx;
        address[] erc20mock;
    }

    Params p;
    address[] implementations;

    string public params_json_file = vm.readFile(string.concat(vm.projectRoot(), "/script/chain_params.json"));

    string public params_json_file2 = vm.readFile(string.concat(vm.projectRoot(), "/script/explorers.json"));
    string public explorer_url = params_json_file2.readString(string.concat(".", vm.toString(block.chainid)));

    EnvelopWNFTFactory factory;
    MyShchFactory myshch_factory;
    EnvelopLegacyWrapperBaseV2 wrapper;
    WNFTLegacy721 impl_legacy;
    WNFTV2Envelop721 impl_native;
    WNFTMyshchWallet impl_myshch;
    WNFTV2Index impl_index;
    CustomERC20 impl_erc20;

    function getChainParams() internal {
        // Load json with chain params

        string memory key;

        console2.log("\n     **Network settings from file**  ");
        // Define constructor params
        key = string.concat(".", vm.toString(block.chainid), ".factory");
        if (vm.keyExists(params_json_file, key)) {
            p.factory = params_json_file.readAddress(key);
        } else {
            p.factory = address(0);
        }
        console2.log("key: %s, value:%s", key, p.factory);

        key = string.concat(".", vm.toString(block.chainid), ".myshch_factory");
        if (vm.keyExists(params_json_file, key)) {
            p.myshch_factory = params_json_file.readAddress(key);
        } else {
            p.myshch_factory = address(0);
        }
        console2.log("key: %s, value:%s", key, p.myshch_factory);

        key = string.concat(".", vm.toString(block.chainid), ".legacy_wrapper");
        if (vm.keyExists(params_json_file, key)) {
            p.legacy_wrapper = params_json_file.readAddress(key);
        } else {
            p.legacy_wrapper = address(0);
        }
        console2.log("key: %s, value:%s", key, p.legacy_wrapper);

        key = string.concat(".", vm.toString(block.chainid), ".impl_legacy");
        if (vm.keyExists(params_json_file, key)) {
            p.impl_legacy = params_json_file.readAddress(key);
        } else {
            p.impl_legacy = address(0);
        }
        console2.log("key: %s, value:%s", key, p.impl_legacy);

        key = string.concat(".", vm.toString(block.chainid), ".impl_native");
        if (vm.keyExists(params_json_file, key)) {
            p.impl_native = params_json_file.readAddress(key);
        } else {
            p.impl_native = address(0);
        }
        console2.log("key: %s, value:%s", key, p.impl_native);

        key = string.concat(".", vm.toString(block.chainid), ".impl_myshch");
        if (vm.keyExists(params_json_file, key)) {
            p.impl_myshch = params_json_file.readAddress(key);
        } else {
            p.impl_myshch = address(0);
        }
        console2.log("key: %s, value:%s", key, p.impl_myshch);

        key = string.concat(".", vm.toString(block.chainid), ".impl_index");
        if (vm.keyExists(params_json_file, key)) {
            p.impl_index = params_json_file.readAddress(key);
        } else {
            p.impl_index = address(0);
        }
        console2.log("key: %s, value:%s", key, p.impl_index);

        key = string.concat(".", vm.toString(block.chainid), ".erc20");
        if (vm.keyExists(params_json_file, key)) {
            address[] memory aa = params_json_file.readAddressArray(key);
            for (uint256 i = 0; i < aa.length; ++i) {
                p.erc20mock.push(aa[i]);
                console2.log("erc20 mock: %s", aa[i]);
            }
        }
        console2.log("key: %s, length:%s", key, p.erc20mock.length);

        key = string.concat(".", vm.toString(block.chainid), ".impl_erc20");
        if (vm.keyExists(params_json_file, key)) {
            p.impl_erc20 = params_json_file.readAddress(key);
        } else {
            p.impl_erc20 = address(0);
        }
        console2.log("key: %s, value:%s", key, p.impl_erc20);

        key = string.concat(".", vm.toString(block.chainid), ".need_test_tx");
        if (vm.keyExists(params_json_file, key)) {
            p.need_test_tx = params_json_file.readBool(key);
        } else {
            p.need_test_tx = false;
        }
        console2.log("key: %s, value:%s", key, p.need_test_tx);
    }

    function deployOrInstances(bool onlyInstance) internal {
        //factory = EnvelopWNFTFactory(0x431Db5c6ce5D85A0BAa2198Aa7Aa0E65d37a25c8);
        if (p.factory == address(0)) {
            if (!onlyInstance) {
                factory = new EnvelopWNFTFactory();
            }
        } else {
            factory = EnvelopWNFTFactory(p.factory);
        }

        if (p.legacy_wrapper == address(0)) {
            if (!onlyInstance) {
                wrapper = new EnvelopLegacyWrapperBaseV2(address(factory));
                factory.setWrapperStatus(address(wrapper), true); // set wrapper
            }
        } else {
            wrapper = EnvelopLegacyWrapperBaseV2(p.legacy_wrapper);
        }
        // push to this array for register on factory later
        implementations.push(address(wrapper));

        if (p.impl_legacy == address(0)) {
            if (!onlyInstance) {
                impl_legacy = new WNFTLegacy721();
                wrapper.setWNFTId(ET.AssetType.ERC721, address(impl_legacy), impl_legacy.TOKEN_ID());
            }
        } else {
            impl_legacy = WNFTLegacy721(payable(p.impl_legacy));
        }

        if (p.impl_native == address(0)) {
            if (!onlyInstance) {
                impl_native = new WNFTV2Envelop721(address(factory));
                // if (!factory.trustedWrappers(address(impl_native))) {
                factory.setWrapperStatus(address(impl_native), true); // set wrapper
                    // }
            }
        } else {
            impl_native = WNFTV2Envelop721(payable(p.impl_native));
        }
        implementations.push(address(impl_native));

        if (p.impl_myshch == address(0)) {
            if (!onlyInstance) {
                impl_myshch = new WNFTMyshchWallet(address(factory));
                //factory.setWrapperStatus(address(impl_myshch), true); // set wrapper
            }
        } else {
            impl_myshch = WNFTMyshchWallet(payable(p.impl_myshch));
        }
        // comment bellow because MyShch factory has different init workflow
        //implementations.push(address(impl_myshch));

        if (p.impl_index == address(0)) {
            if (!onlyInstance) {
                impl_index = new WNFTV2Index(address(factory));
                //factory.setWrapperStatus(address(impl_myshch), true); // set wrapper
            }
        } else {
            impl_index = WNFTV2Index(payable(p.impl_index));
        }
        implementations.push(address(impl_index));

        // ERC20 moock and template
        if (p.impl_erc20 == address(0)) {
            if (!onlyInstance) {
                impl_erc20 = new CustomERC20();
            }
        } else {
            impl_erc20 = CustomERC20(p.impl_erc20);
        }

        if (p.myshch_factory == address(0)) {
            if (!onlyInstance) {
                myshch_factory = new MyShchFactory(address(impl_myshch));
                myshch_factory.newImplementation(MyShchFactory.AssetType.ERC20, address(impl_erc20));
            }
        } else {
            myshch_factory = MyShchFactory(p.myshch_factory);
        }
        //vm.stopBroadcast();
        console2.log("Instances ready....");
    }

    function prettyPrint() internal view {
        ///////// Pretty printing ////////////////

        //string memory path = string.concat(vm.projectRoot(), "/script/explorers.json");
        //string memory json = vm.readFile(path);
        //params_path = string.concat(vm.projectRoot(), "/script/explorers.json");
        // params_json_file = vm.readFile(string.concat(vm.projectRoot(), "/script/explorers.json"));

        // console2.log("Chain id: %s", vm.toString(block.chainid));
        // string memory explorer_url = params_json_file.readString(
        //     string.concat(".", vm.toString(block.chainid))
        // );

        console2.log("\n**EnvelopWNFTFactory**  ");
        console2.log("https://%s/address/%s#code\n", explorer_url, address(factory));
        console2.log("\n**MyShchFactory** ");
        console2.log("https://%s/address/%s#code\n", explorer_url, address(myshch_factory));
        console2.log("\n**EnvelopLegacyWrapperBaseV2** ");
        console2.log("https://%s/address/%s#code\n", explorer_url, address(wrapper));
        console2.log("\n**WNFTLegacy721** ");
        console2.log("https://%s/address/%s#code\n", explorer_url, address(impl_legacy));
        console2.log("\n**WNFTV2Envelop721** ");
        console2.log("https://%s/address/%s#code\n", explorer_url, address(impl_native));
        console2.log("\n**WNFTMyshchWallet** ");
        console2.log("https://%s/address/%s#code\n", explorer_url, address(impl_myshch));
        console2.log("\n**WNFTV2Index** ");
        console2.log("https://%s/address/%s#code\n", explorer_url, address(impl_index));
        console2.log("\n**CustomERC20** ");
        console2.log("https://%s/address/%s#code\n", explorer_url, address(impl_erc20));

        console2.log("```python");
        console2.log("factory = EnvelopWNFTFactory.at('%s')", address(factory));
        console2.log("myshch_factory = MyShchFactory.at('%s')", address(myshch_factory));
        console2.log("wrapper = EnvelopLegacyWrapperBaseV2.at('%s')", address(wrapper));
        console2.log("impl_legacy = WNFTLegacy721.at('%s')", address(impl_legacy));
        console2.log("impl_native = WNFTV2Envelop721.at('%s')", address(impl_native));
        console2.log("impl_myshch = WNFTMyshchWallet.at('%s')", address(impl_myshch));
        console2.log("impl_index = WNFTV2Index.at('%s')", address(impl_index));
        console2.log("impl_erc20 = CustomERC20.at('%s')", address(impl_erc20));
        console2.log("```");

        console2.log("********* Use strings below for update chain_params.json\n");
        console2.log("```json");
        console2.log("\"factory\": \"%s\",", address(factory));
        console2.log("\"myshch_factory\": \"%s\",", address(myshch_factory));
        console2.log("\"legacy_wrapper\": \"%s\",", address(wrapper));
        console2.log("\"impl_legacy\": \"%s\",", address(impl_legacy));
        console2.log("\"impl_native\": \"%s\",", address(impl_native));
        console2.log("\"impl_myshch\": \"%s\",", address(impl_myshch));
        console2.log("\"impl_index\": \"%s\",", address(impl_index));
        console2.log("\"impl_erc20\": \"%s\"", address(impl_erc20));
        console2.log("```");
    }
}
