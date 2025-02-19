// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "./Objects.s.sol";

// Address:     0x7EC0BF0a4D535Ea220c6bD961e352B752906D568
// Private key: 0x1bbde125e133d7b485f332b8125b891ea2fbb6a957e758db72e6539d46e2cd71

// Address:     0x4b664eD07D19d0b192A037Cfb331644cA536029d
// Private key: 0x3480b19b170c5e63c0bdb18d08c4a99628194c7dceaf79e0e17431f4a5c7b1f2

// Address:     0xd7DE4B1214bFfd5C3E9Fb8A501D1a7bF18569882
// Private key: 0x8ba574046f1e9e372e805aa6c5dcf5598830df5a78605b7713bf00f2f3329148

// Address:     0x6F9aaAaD96180b3D6c71Fbbae2C1c5d5193A64EC
// Private key: 0xae8fe3985898986377b19cc6bdbb76723470552e95e4d028d2dae2691ab9c65d

/// Deploy and init actions
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
            
        vm.stopBroadcast();
        console2.log("Initialisation finished");
    }
}

// Test tx acions
contract TestTxScript is Script, Objects {
    using stdJson for string;

    //string params_json_file = vm.readFile(string.concat(vm.projectRoot(), "/script/explorers.json"));
    
    
    function run() public {
        console2.log("Chain id: %s", vm.toString(block.chainid));
        console2.log(
            "Deployer address: %s, "
            "\n native balance %s",
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
        bytes32 salt = keccak256(abi.encode(address(impl_index), impl_index.nonce(msg.sender) + 1));
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
            new uint256[](2),
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