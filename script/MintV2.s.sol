// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "./Objects.s.sol";

// Test tx acions
contract MintV2Script is Script, Objects {
    using stdJson for string;

    uint256 public constant MINT_COUNT = 11;

    //string params_json_file = vm.readFile(string.concat(vm.projectRoot(), "/script/explorers.json"));
    
    
    function run() public {
        console2.log("Chain id: %s", vm.toString(block.chainid));
        console2.log(
            "Deployer address: %s, "
            "\n native balance %s",
            msg.sender, msg.sender.balance
        );

        getChainParams();
        deployOrInstances(true);  // true - instances only
        
        params_json_file = vm.readFile(string.concat(vm.projectRoot(), "/script/explorers.json"));
        string memory explorer_url = params_json_file.readString(
            string.concat(".", vm.toString(block.chainid))
        );

        vm.startBroadcast();
        

        // Create Smart wallet test 
        WNFTV2Envelop721.InitParams memory initData = WNFTV2Envelop721.InitParams(
            msg.sender,
            'Envelop Tokenized Hashrate',
            'vTH',
            '',
            //'https://api.envelop.is/wallet',
            new address[](0),
            new bytes32[](0),
            new uint256[](1),
            ""
        );
        initData.numberParams[0] = block.timestamp + 100 days;
        address[] memory  _wnftAddress = new address[](MINT_COUNT);
        WNFTV2Envelop721 wnftWallet;
        console2.log("Deployed V2 wNFT: \n");
        for (uint256 i = 0; i < MINT_COUNT; ++ i) {
            _wnftAddress[i] = payable(impl_native.createWNFTonFactory(initData));
            console2.log(
                "https://%s/address/%s#code\n",
                explorer_url, _wnftAddress[i]
            );
            
        }

        vm.stopBroadcast();
        for (uint256 i = 0; i < _wnftAddress.length; ++ i) {
            wnftWallet = WNFTV2Envelop721(payable(_wnftAddress[i]));
            console2.log(
                    "WNFT Name: %s"
                    //"\n WNFT Symbol: %s",
                    "\n tokenURI: %s",
                    wnftWallet.name(), 
                    //wnftWallet.symbol(), 
                    wnftWallet.tokenURI(wnftWallet.TOKEN_ID())
                );
        }
    }

}