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
abstract contract Objects is Script{
    using stdJson for string;
    struct Params {
        address factory;   
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

    EnvelopWNFTFactory factory;
    EnvelopLegacyWrapperBaseV2 wrapper;
    WNFTLegacy721 impl_legacy;
    WNFTV2Envelop721 impl_native;
    WNFTMyshchWallet impl_myshch;
    WNFTV2Index impl_index; 
    CustomERC20 impl_erc20;

    function getChainParams() internal {
        // Load json with chain params
        
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

        key = string.concat(".", vm.toString(block.chainid),".impl_index");
        if (vm.keyExists(params_json_file, key)) 
        {
            p.impl_index = params_json_file.readAddress(key);
        } else {
            p.impl_index = address(0);
        }


        key = string.concat(".", vm.toString(block.chainid),".erc20");
        if (vm.keyExists(params_json_file, key)) 
        {
            address[] memory aa = params_json_file.readAddressArray(key);
            for (uint256 i = 0; i < aa.length; ++i ){
                p.erc20mock.push(aa[i]);   
                console2.log("erc20 mock: %s", aa[i]); 
            }
        }

        key = string.concat(".", vm.toString(block.chainid),".impl_erc20");
        if (vm.keyExists(params_json_file, key)) 
        {
            p.impl_erc20 = params_json_file.readAddress(key);
        } else {
            p.impl_erc20 = address(0);
        }

        key = string.concat(".", vm.toString(block.chainid),".need_test_tx");
        if (vm.keyExists(params_json_file, key)) 
        {
            p.need_test_tx = params_json_file.readBool(key);
        } else {
            p.need_test_tx = false;
        }
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

        if (p.legacy_wrapper == address(0)){
            if (!onlyInstance) {
                wrapper = new EnvelopLegacyWrapperBaseV2(address(factory)); 
                factory.setWrapperStatus(address(wrapper), true); // set wrapper
            }
        } else {
            wrapper = EnvelopLegacyWrapperBaseV2(p.legacy_wrapper);    
        }
        implementations.push(address(wrapper));
        
        if (p.impl_legacy == address(0)) {
            if (!onlyInstance) {
                impl_legacy = new WNFTLegacy721();
                wrapper.setWNFTId(
                    ET.AssetType.ERC721, 
                    address(impl_legacy), 
                    impl_legacy.TOKEN_ID()
                );
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
                impl_myshch = new WNFTMyshchWallet(address(factory),0);    
                //factory.setWrapperStatus(address(impl_myshch), true); // set wrapper
            }
        } else {
            impl_myshch = WNFTMyshchWallet(payable(p.impl_myshch));
        }
        implementations.push(address(impl_myshch));

        if (p.impl_index == address(0)) {
            if (!onlyInstance) {
                impl_index = new WNFTV2Index(address(factory));    
                //factory.setWrapperStatus(address(impl_myshch), true); // set wrapper
            }
        } else {
            impl_index = WNFTV2Index(payable(p.impl_index));
        }
        implementations.push(address(impl_index));

        // ERC20 moock
        if (p.impl_erc20 == address(0)) {
            if (!onlyInstance) {
                impl_erc20 = new CustomERC20();    
            }
        } else {
            impl_erc20 = CustomERC20(p.impl_erc20);
        }


        //vm.stopBroadcast();

    }

    function prettyPrint() internal {
        ///////// Pretty printing ////////////////
        
        //string memory path = string.concat(vm.projectRoot(), "/script/explorers.json");
        //string memory json = vm.readFile(path);
        //params_path = string.concat(vm.projectRoot(), "/script/explorers.json");
        params_json_file = vm.readFile(string.concat(vm.projectRoot(), "/script/explorers.json"));
        
        console2.log("Chain id: %s", vm.toString(block.chainid));
        string memory explorer_url = params_json_file.readString(
            string.concat(".", vm.toString(block.chainid))
        );
        
        console2.log("\n**EnvelopWNFTFactory**  ");
        console2.log("https://%s/address/%s#code\n", explorer_url, address(factory));
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
        console2.log("wrapper = EnvelopLegacyWrapperBaseV2.at('%s')", address(wrapper));
        console2.log("impl_legacy = WNFTLegacy721.at('%s')", address(impl_legacy));
        console2.log("impl_native = WNFTV2Envelop721.at('%s')", address(impl_native));
        console2.log("impl_myshch = WNFTMyshchWallet.at('%s')", address(impl_myshch));
        console2.log("impl_index = WNFTV2Index.at('%s')", address(impl_index));
        console2.log("impl_erc20 = CustomERC20.at('%s')", address(impl_erc20));
        console2.log("```");

        console2.log("```json");
        console2.log("\"factory\": \"%s\",", address(factory));
        console2.log("\"wrapper\": \"%s\",", address(wrapper));
        console2.log("\"impl_legacy\": \"%s\",", address(impl_legacy));
        console2.log("\"impl_native\": \"%s\",", address(impl_native));
        console2.log("\"impl_myshch\": \"%s\",", address(impl_myshch));
        console2.log("\"impl_index\": \"%s\",", address(impl_index));
        console2.log("\"impl_erc20\": \"%s\"", address(impl_erc20));
        console2.log("```");
    }

}

contract DeployScript is Script, Objects {
    using stdJson for string;
    function run() public {
        console2.log("Chain id: %s", vm.toString(block.chainid));
        console2.log(
            "Deployer address: %s, "
            "\n native balnce %s",
            msg.sender, msg.sender.balance
        );
         
        getChainParams();

        //////////   Deploy   //////////////
        vm.startBroadcast();
        deployOrInstances(false);
        vm.stopBroadcast();

        prettyPrint(); 
        
   
        // ///////// End of pretty printing ////////////////
        
        // ///  Init ///
        console2.log("Init transactions....");
        vm.startBroadcast();
        for (uint256 i = 0; i < implementations.length; ++ i){
            // Check and set trusted wrappers
            if (!factory.trustedWrappers(implementations[i])) {
                factory.setWrapperStatus(implementations[i], true); // set wrapper    
            }   
        }

        // test transactions
        // if (p.need_test_tx){
        //     EnvelopLegacyWrapperBaseV2.INData memory ind = EnvelopLegacyWrapperBaseV2.INData(
        //         ET.AssetItem(ET.Asset(ET.AssetType.EMPTY, address(0)),0,0), // inAsset
        //         address(this), //unWrapDestination (unused)
        //         new ET.Fee[](0), // fees
        //         new ET.Lock[](0), // locks
        //         new ET.Royalty[](0), // royalties
        //         ET.AssetType.ERC721,
        //         0, // outbalance
        //         0x0105   //bytes2
        //     ); 
        //     ET.AssetItem[] memory _coll = new ET.AssetItem[](0); 
        
        //     //ET.NFTItem memory nonce2  = wrapper.saltBase(ET.AssetType.ERC721);
        //     // address wnftPredictedAddress = factory.predictDeterministicAddress(
        //     //     address(impl_legacy), // implementation address
        //     //     keccak256(abi.encode(nonce2))
        //     // );
        //     ET.AssetItem  memory created = wrapper.wrap(ind, _coll, msg.sender);
        //     console2.log("\n**Tets legacy wnft WNFTLegacy721** ");
        //     console2.log("https://%s/address/%s#code\n", explorer_url, created.asset.contractAddress);

        // }
            
        vm.stopBroadcast();
        console2.log("Initialisation finished");
    }
}

contract TestTxScript is Script, Objects {
    using stdJson for string;

    //string params_json_file = vm.readFile(string.concat(vm.projectRoot(), "/script/explorers.json"));
    
    
    function run() public {
        console2.log("Chain id: %s", vm.toString(block.chainid));
        console2.log(
            "Deployer address: %s, "
            "\n native balnce %s",
            msg.sender, msg.sender.balance
        );

        getChainParams();
        deployOrInstances(true);
        vm.startBroadcast();
        
        // Create Smart wallet test 
        WNFTV2Envelop721.InitParams memory initData = WNFTV2Envelop721.InitParams(
            msg.sender,
            'Envelop V2 Smart Wallet',
            'ENVELOPV2',
            'https://api.envelop.is/wallet',
            new address[](0),
            new bytes32[](0),
            new uint256[](0),
            ""
        );

        address payable _wnftWalletAddress = payable(impl_native.createWNFTonFactory(initData));

        WNFTV2Index wnftWallet = WNFTV2Index(_wnftWalletAddress);
        
        // Topup Smart wallet test
        for (uint256 i = 0; i < p.erc20mock.length; ++ i) {
            IERC20(p.erc20mock[i]).transfer(_wnftWalletAddress, 1e18);
            
        }
        _wnftWalletAddress.call{value: 3e14}("");

        //
        // make new wnftWallet using executeOp
        // transfer erc20 tyokens to new wnftWallet
        // make 1 child wallet
        // transfer erc20 tokens from master wallet to child wallets
        // transfer ether

        // calc index wallet addresses
        bytes32 salt = keccak256(abi.encode(address(impl_index), impl_index.nonce() + 1));
        address calcW1 = factory.predictDeterministicAddress(address(impl_index), salt);

        address[] memory targets = new address[](3);
        bytes[] memory dataArray = new bytes[](3);
        uint256[] memory values = new uint256[](3);

        targets[0] = address(impl_index);
        targets[1] = address(p.erc20mock[0]);
        targets[2] = address(calcW1);

        // prepare data for deploying of child wallets
        initData = WNFTV2Envelop721.InitParams(
            msg.sender,
            '',
            '',
            '',
            new address[](0),
            new bytes32[](0),
            new uint256[](0),
            ""
            );

        // using method with salt
        bytes memory _data = abi.encodeWithSignature(
            "createWNFTonFactory2((address,string,string,string,address[],bytes32[],uint256[],bytes))",
            initData
        );

       
        values[0] = 0;    
        values[1] = 0;    
        values[2] = 16;            
       

        dataArray[0] = _data;
        dataArray[1] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            calcW1, 2e14
        );
       
        dataArray[2] = "";

        bytes[] memory result = wnftWallet.executeEncodedTxBatch(targets, values, dataArray);

        // get child wallet adresses from output
        address payable w1 =  payable(abi.decode(result[0],
             (address)
        ));

        vm.stopBroadcast();

        params_json_file = vm.readFile(string.concat(vm.projectRoot(), "/script/explorers.json"));
        string memory explorer_url = params_json_file.readString(
            string.concat(".", vm.toString(block.chainid))
        );

        console2.log(
            "Deployed index contract:"
            "\n https://%s/address/%s#code\n",
            explorer_url, w1
        );

        console2.log(
            "from Envelop Smart Wallet:"
            "\n https://%s/address/%s#code\n",
            explorer_url, _wnftWalletAddress
        );

    
    }

}