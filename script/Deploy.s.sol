// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Script, console2} from "forge-std/Script.sol";
import "../lib/forge-std/src/StdJson.sol";
import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import "../src/impl/WNFTMyshchWallet.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import "../src/impl/WNFTLegacy721.sol";
import "../src/impl/WNFTV2Envelop721.sol";
import "../src/impl/WNFTMyshchWallet.sol";
import {EnvelopLegacyWrapperBaseV2} from "../src/EnvelopLegacyWrapperBaseV2.sol";


// Address:     0x7EC0BF0a4D535Ea220c6bD961e352B752906D568
// Private key: 0x1bbde125e133d7b485f332b8125b891ea2fbb6a957e758db72e6539d46e2cd71

// Address:     0x4b664eD07D19d0b192A037Cfb331644cA536029d
// Private key: 0x3480b19b170c5e63c0bdb18d08c4a99628194c7dceaf79e0e17431f4a5c7b1f2

// Address:     0xd7DE4B1214bFfd5C3E9Fb8A501D1a7bF18569882
// Private key: 0x8ba574046f1e9e372e805aa6c5dcf5598830df5a78605b7713bf00f2f3329148

// Address:     0x6F9aaAaD96180b3D6c71Fbbae2C1c5d5193A64EC
// Private key: 0xae8fe3985898986377b19cc6bdbb76723470552e95e4d028d2dae2691ab9c65d


contract DeployScript is Script {
    using stdJson for string;

    struct Params {
        address factory;   
        address legacy_wrapper;
        address impl_legacy;
        address impl_native;
        address impl_myshch;
        bool need_test_tx;
    }

    Params p; 

    function run() public {
        console2.log("Chain id: %s", vm.toString(block.chainid));
        console2.log(
            "Deployer address: %s, "
            "\n native balnce %s",
            msg.sender, msg.sender.balance
        );
         
        // Load json with chain params
        string memory params_json_file = vm.readFile(string.concat(vm.projectRoot(), "/script/chain_params.json"));
        string memory key;
        
        // Define constructor params
        key = string.concat(".", vm.toString(block.chainid),".factory");
        if (vm.keyExists(params_json_file, key)) 
        {
            p.factory = params_json_file.readAddress(key);
        } else {
            p.factory = address(0);
        }
        
        key = string.concat(".", vm.toString(block.chainid),".legacy_wrapper");
        if (vm.keyExists(params_json_file, key)) 
        {
            p.legacy_wrapper = params_json_file.readAddress(key);
        } else {
            p.legacy_wrapper = address(0);
        }
        
        key = string.concat(".", vm.toString(block.chainid),".impl_legacy");
        if (vm.keyExists(params_json_file, key)) 
        {
            p.impl_legacy = params_json_file.readAddress(key);
        } else {
            p.impl_legacy = address(0);
        }

        key = string.concat(".", vm.toString(block.chainid),".impl_native");
        if (vm.keyExists(params_json_file, key)) 
        {
            p.impl_native = params_json_file.readAddress(key);
        } else {
            p.impl_native = address(0);
        }

        key = string.concat(".", vm.toString(block.chainid),".impl_myshch");
        if (vm.keyExists(params_json_file, key)) 
        {
            p.impl_myshch = params_json_file.readAddress(key);
        } else {
            p.impl_myshch = address(0);
        }

        key = string.concat(".", vm.toString(block.chainid),".need_test_tx");
        if (vm.keyExists(params_json_file, key)) 
        {
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
        EnvelopWNFTFactory factory;
        //EnvelopLegacyWrapperBaseV2 wrapper;
        //WNFTLegacy721 impl_legacy;
        //WNFTV2Envelop721 impl_native;
        WNFTMyshchWallet impl_myshch;

        factory = EnvelopWNFTFactory(0x431Db5c6ce5D85A0BAa2198Aa7Aa0E65d37a25c8);
        /*if (p.factory == address(0)) {
            factory = new EnvelopWNFTFactory();    
        } else {
            factory = EnvelopWNFTFactory(p.factory);
        }

        if (p.legacy_wrapper == address(0)){
            wrapper = new EnvelopLegacyWrapperBaseV2(address(factory));    
            factory.setWrapperStatus(address(wrapper), true); // set wrapper
        } else {
            wrapper = EnvelopLegacyWrapperBaseV2(p.legacy_wrapper);    
        }
        
        if (p.impl_legacy == address(0)) {
            impl_legacy = new WNFTLegacy721();
            wrapper.setWNFTId(
                ET.AssetType.ERC721, 
                address(impl_legacy), 
                impl_legacy.TOKEN_ID()
            );
        } else {
            impl_legacy = WNFTLegacy721(payable(p.impl_legacy));
        }
        
        if (p.impl_native == address(0)) {
            impl_native = new WNFTV2Envelop721(address(factory));    
            factory.setWrapperStatus(address(impl_native), true); // set wrapper
        } else {
            impl_native = WNFTV2Envelop721(payable(p.impl_native));
        }*/

        if (p.impl_myshch == address(0)) {
            impl_myshch = new WNFTMyshchWallet(address(factory),0);    
            factory.setWrapperStatus(address(impl_myshch), true); // set wrapper
        } else {
            impl_myshch = WNFTMyshchWallet(payable(p.impl_myshch));
        }

                
        vm.stopBroadcast();
        
        ///////// Pretty printing ////////////////
        
        //string memory path = string.concat(vm.projectRoot(), "/script/explorers.json");
        //string memory json = vm.readFile(path);
        //params_path = string.concat(vm.projectRoot(), "/script/explorers.json");
        params_json_file = vm.readFile(string.concat(vm.projectRoot(), "/script/explorers.json"));
        
        console2.log("Chain id: %s", vm.toString(block.chainid));
        string memory explorer_url = params_json_file.readString(
            string.concat(".", vm.toString(block.chainid))
        );
        
        /*console2.log("\n**EnvelopWNFTFactory**  ");
        console2.log("https://%s/address/%s#code\n", explorer_url, address(factory));
        console2.log("\n**EnvelopLegacyWrapperBaseV2** ");
        console2.log("https://%s/address/%s#code\n", explorer_url, address(wrapper));
        console2.log("\n**WNFTLegacy721** ");
        console2.log("https://%s/address/%s#code\n", explorer_url, address(impl_legacy));
        console2.log("\n**WNFTV2Envelop721** ");
        console2.log("https://%s/address/%s#code\n", explorer_url, address(impl_native));*/
        console2.log("\n**WNFTMyshchWallet** ");
        console2.log("https://%s/address/%s#code\n", explorer_url, address(impl_myshch));



        console2.log("```python");
        /*console2.log("factory = EnvelopWNFTFactory.at('%s')", address(factory));
        console2.log("wrapper = EnvelopLegacyWrapperBaseV2.at('%s')", address(wrapper));
        console2.log("impl_legacy = WNFTLegacy721.at('%s')", address(impl_legacy));
        console2.log("impl_native = WNFTV2Envelop721.at('%s')", address(impl_native));*/
        console2.log("impl_myshch = WNFTMyshchWallet.at('%s')", address(impl_myshch));
        console2.log("```");
   
        // ///////// End of pretty printing ////////////////
        
        // ///  Init ///
        /*console2.log("Init transactions....");
        vm.startBroadcast();

        // test transactions
        if (p.need_test_tx){
            EnvelopLegacyWrapperBaseV2.INData memory ind = EnvelopLegacyWrapperBaseV2.INData(
                ET.AssetItem(ET.Asset(ET.AssetType.EMPTY, address(0)),0,0), // inAsset
                address(this), //unWrapDestination (unused)
                new ET.Fee[](0), // fees
                new ET.Lock[](0), // locks
                new ET.Royalty[](0), // royalties
                ET.AssetType.ERC721,
                0, // outbalance
                0x0105   //bytes2
            ); 
            ET.AssetItem[] memory _coll = new ET.AssetItem[](0); 
        
            //ET.NFTItem memory nonce2  = wrapper.saltBase(ET.AssetType.ERC721);
            // address wnftPredictedAddress = factory.predictDeterministicAddress(
            //     address(impl_legacy), // implementation address
            //     keccak256(abi.encode(nonce2))
            // );
            ET.AssetItem  memory created = wrapper.wrap(ind, _coll, msg.sender);
            console2.log("\n**Tets legacy wnft WNFTLegacy721** ");
            console2.log("https://%s/address/%s#code\n", explorer_url, created.asset.contractAddress);

        }
            
        vm.stopBroadcast();
        console2.log("Initialisation finished");*/
    }
}
