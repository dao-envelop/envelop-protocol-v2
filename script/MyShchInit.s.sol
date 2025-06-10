// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "./Objects.s.sol";
import {Vm} from "forge-std/Vm.sol";

// Address:     0x7EC0BF0a4D535Ea220c6bD961e352B752906D568
// Private key: 0x1bbde125e133d7b485f332b8125b891ea2fbb6a957e758db72e6539d46e2cd71

// Address:     0x4b664eD07D19d0b192A037Cfb331644cA536029d
// Private key: 0x3480b19b170c5e63c0bdb18d08c4a99628194c7dceaf79e0e17431f4a5c7b1f2

// Address:     0xd7DE4B1214bFfd5C3E9Fb8A501D1a7bF18569882
// Private key: 0x8ba574046f1e9e372e805aa6c5dcf5598830df5a78605b7713bf00f2f3329148

// Address:     0x6F9aaAaD96180b3D6c71Fbbae2C1c5d5193A64EC
// Private key: 0xae8fe3985898986377b19cc6bdbb76723470552e95e4d028d2dae2691ab9c65d

/// Deploy and init actions
contract MyShchInit is Script, Objects {
    using stdJson for string;
    struct LocalParams {
        bool status_to_set;
        address[] trusted_signers_list;
    }

    LocalParams lp;

    function run() public {
        console2.log("Chain id: %s", vm.toString(block.chainid));
        console2.log(
            "Deployer address: %s, "
            "\n native balnce %s",
            msg.sender, msg.sender.balance
        );

        /////////////////////////////////////////////////////////////////////////
        // INIT LOCKAL TASK PARAMS                                             //
        /////////////////////////////////////////////////////////////////////////
        // Load json with chain params
        string memory params_json_file = vm.readFile(string.concat(vm.projectRoot(), "/script/chain_params.json"));
        string memory key;
        
        key = string.concat(".", vm.toString(block.chainid),".status_to_set");
        if (vm.keyExists(params_json_file, key)) 
        {
            lp.status_to_set = params_json_file.readBool(key);
        } else {
            lp.status_to_set = false;
        }
        console2.log("key: %s, value:%s", key, lp.status_to_set);

        key = string.concat(".", vm.toString(block.chainid),".trusted_signers_list");
        if (vm.keyExists(params_json_file, key)) 
        {
            address[] memory aa = params_json_file.readAddressArray(key);
            for (uint256 i = 0; i < aa.length; ++i ){
                lp.trusted_signers_list.push(aa[i]);   
                console2.log("Trusted signer: %s, set to %s", aa[i], lp.status_to_set); 
            }
        }


        /////////////////////////////////////////////////////////////////////////
         
        getChainParams();

        //////////   Deploy   //////////////
        /// Actually there is no  any deplyments here. Use Deploy.s.sol instead
        /// Just get deployed instances 
        //vm.startBroadcast();
        deployOrInstances(true);
        
        // ///  Init ///
        console2.log("Check & Init transactions....");
        vm.startBroadcast();
        //MyShchFactory.Signer memory signerFromContract;
        for (uint256 i = 0; i <  lp.trusted_signers_list.length; ++i ){
            (bool current, ) = myshch_factory.trustedSigners(lp.trusted_signers_list[i]);
            if  (current !=  lp.status_to_set) {
                myshch_factory.setSignerStatus(lp.trusted_signers_list[i], lp.status_to_set); 
                console2.log("Trusted signer added: %s", lp.trusted_signers_list[i]); 
            }
        }

        // Check current wnft implementation and set new if need
        address[] memory impl721array = myshch_factory.getImplementationHistory(); 
        if (impl721array[impl721array.length - 1] != address(impl_myshch)) {
            myshch_factory.newImplementation(address(impl_myshch));
            console2.log("New 721 implementation added: %s", address(impl_myshch)); 
            console2.log("\n**WNFTMyshchWallet** ");
            console2.log("https://%s/address/%s#code\n", explorer_url, address(impl_myshch));
        } 
        vm.stopBroadcast();
        console2.log("Initialisation finished");
    }
}

// Test tx acions
contract TestTxScript is Script, Objects {
    using stdJson for string;

    struct LocalParams {
        address botWallet;
        address payable customWallet;
        CustomERC20 token20;
        uint64 botId;
        uint64 userTgId;

    }

    //string params_json_file = vm.readFile(string.concat(vm.projectRoot(), "/script/explorers.json"));
    address public constant botEOA   = 0x4b664eD07D19d0b192A037Cfb331644cA536029d;
    uint256 public constant botEOA_PRIVKEY = 0x3480b19b170c5e63c0bdb18d08c4a99628194c7dceaf79e0e17431f4a5c7b1f2;
    
    //address public constant userEOA =  0x6F9aaAaD96180b3D6c71Fbbae2C1c5d5193A64EC;
    //uint256 public constant userEOA_PRIVKEY = 0xae8fe3985898986377b19cc6bdbb76723470552e95e4d028d2dae2691ab9c65d;
    LocalParams lp;
    

    function run() public {
        console2.log("Chain id: %s", vm.toString(block.chainid));
        console2.log(
            "Deployer address: %s, "
            "\n native balance %s",
            msg.sender, msg.sender.balance
        );

        getChainParams();
        deployOrInstances(true);

        // Just check for new cheat code
        // vm.rememberKey(userEOA_PRIVKEY);
        // address[] memory eoaWallets = vm.getWallets();
        // for (uint256 i = 0; i < eoaWallets.length; ++i){
        //     console2.log("eoaWallets[%s]: %s ",i, eoaWallets[i]);     
        // }
        
        
        lp.botId = uint64(0);
        lp.userTgId = uint64(22222);

        Vm.Wallet memory userEOAWallet = vm.createWallet( 
            uint256(keccak256(abi.encode(block.timestamp, vm.prompt("enter salt:"))))
        );

        vm.startBroadcast();
        // Topup user EOA
        payable(userEOAWallet.addr).transfer(2e14);

        // Add trusted signers
        myshch_factory.setSignerStatus(msg.sender, true);
        myshch_factory.setSignerStatus(botEOA, true);
       
        // Bot wnft wallet
        // We dont need signature for mint wnft wallet to trusted address
        // bytes memory botSignature;
        // bytes32 digest =  MessageHashUtils.toEthSignedMessageHash(
        //     myshch_factory.getDigestForSign(11111, myshch_factory.currentNonce(11111) + 1)
        // );
        // (uint8 v, bytes32 r, bytes32 s) = vm.sign(botEOA_PRIVKEY, digest);
        // botSignature = abi.encodePacked(r,s,v);

        (bool current, ) = myshch_factory.trustedSigners(botEOA);
        if (current) {
            lp.botWallet = myshch_factory.mintPersonalMSW(0, "");   
            console2.log("MyShch bot  wallet created: %s ", lp.botWallet); 
        } else {
             console2.log("Signer address: %s is not trusted", botEOA); 
        }
        vm.stopBroadcast();
        
        
        // Users wnft wallet
        vm.startBroadcast(userEOAWallet.privateKey);
        bytes memory botSignature;
        bytes32 digest =  MessageHashUtils.toEthSignedMessageHash(
            myshch_factory.getDigestForSign(22222, myshch_factory.currentNonce(22222) + 1)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(botEOA_PRIVKEY, digest);
        botSignature = abi.encodePacked(r,s,v);
        
        (current, ) = myshch_factory.trustedSigners(botEOA);
        if (current) {
            lp.customWallet = payable(myshch_factory.mintPersonalMSW{value: 1e14}(22222, botSignature));   
            console2.log("MyShch user wallet created: %s ", lp.customWallet); 
        } else {
             console2.log("Signer address: %s is not trusted", botEOA); 
        }

        WNFTMyshchWallet userWallet = WNFTMyshchWallet(lp.customWallet);
        userWallet.setRelayerStatus(lp.botWallet, true);
        vm.stopBroadcast();

             
        vm.startBroadcast();
        // Custom ERC20
        address[] memory erc20Impl = myshch_factory.getImplementationHistory(MyShchFactory.AssetType.ERC20);
        if (erc20Impl[erc20Impl.length -1] != address(impl_erc20)) {
            myshch_factory.newImplementation(MyShchFactory.AssetType.ERC20, address(impl_erc20));    
        }
        
        MyShchFactory.InitDistributtion[] memory initDisrtrib = new MyShchFactory.InitDistributtion[](2);
        initDisrtrib[0] = MyShchFactory.InitDistributtion(lp.botWallet, 10e18);
        initDisrtrib[1] = MyShchFactory.InitDistributtion(address(2), 200);
        lp.token20 = CustomERC20(
            myshch_factory.createCustomERC20(
                msg.sender,           // _creator,
                "Custom ERC20 Name",     // name_,
                "CUSTSYM",               // symbol_,
                1_000_000e18,            // _totalSupply,
                initDisrtrib             // _initialHolders
            )
        );
        console2.log("Custom ERC20 token created: %s", address(lp.token20));
        // Topup bot wallet
        //lp.token20.transfer(lp.botWallet, lp.token20.balanceOf(address(this))/ 10);
        // WNFTMyshchWallet botWallet = WNFTMyshchWallet(payable(lp.botWallet));
        // botWallet.erc20TransferWithRefund(address(lp.token20), lp.customWallet, 1e18);
        vm.stopBroadcast();
        
        console2.log("Test tx finished");
    
    }

}
