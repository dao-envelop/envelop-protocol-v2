// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/console.sol";

import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import "../src/impl/WNFTMyshchWallet.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import "../src/impl/WNFTLegacy721.sol";
import "../src/impl/WNFTV2Envelop721.sol";
//import "../src/impl/Singleton721.sol";
//import {ET} from "../src/utils/LibET.sol";


contract Factory_Test_m_03 is Test {

    struct AmountsBefore {
        uint256 amount0;
        uint256 amount1;
        uint256 amount2;
        uint256 amount3;
        uint256 amount4;
        uint256 amount5;
        uint256 amount6;
        uint256 amount7;
        uint256 amount8;
        uint256 amount9;    
    }

    address public constant addr4 = 0x6F9aaAaD96180b3D6c71Fbbae2C1c5d5193A64EC;
    uint256 public sendEtherAmount = 1e18;
    EnvelopWNFTFactory public factory;
    WNFTMyshchWallet public impl_myshch;
    WNFTMyshchWallet public walletServ;
    WNFTMyshchWallet public walletUser;
    WNFTV2Envelop721 public impl_native;
    MockERC20 public erc20;
    //uint256 public nonce;
    uint256 public sendERC20Amount = 1e14;
    uint256 public constant FEE = 0;
    address constant SERV_OWNER = address(18);

    receive() external payable virtual {}
    function setUp() public {
        vm.txGasPrice(1);
        console2.log("Tx sender: %s, balance: s%, gasleft %s", msg.sender, msg.sender.balance, gasleft());
        erc20 = new MockERC20("Name of Mock", "MMM");
        factory = new EnvelopWNFTFactory();
        impl_myshch = new WNFTMyshchWallet(address(factory));
        impl_native = new WNFTV2Envelop721(address(factory));
        factory.setWrapperStatus(address(this), true); // set wrapper
        factory.setWrapperStatus(address(impl_myshch), true); // set wrapper
        factory.setWrapperStatus(address(impl_native), true); // set wrapper

        // struct InitParams {
        //     address creator;
        //     string nftName;
        //     string nftSymbol;
        //     string tokenUri;
        //     address[] addrParams;    // Semantic of this param will defined in exact implemenation 
        //     bytes32[] hashedParams;  // Semantic of this param will defined in exact implemenation
        //     uint256[] numberParams;  // Semantic of this param will defined in exact implemenation
        //     bytes bytesParam;        // Semantic of this param will defined in exact implemenation
        // }
        
        bytes memory initCallData = abi.encodeWithSignature(
            impl_native.INITIAL_SIGN_STR(),
            WNFTV2Envelop721.InitParams(
                SERV_OWNER, 
                "MyshchWallet", 
                "MSHW", 
                "https://api.envelop.is",
                new address[](0),
                new bytes32[](0),
                new uint256[](0),
                "" 
            )
        );
        address payable  created = payable(factory.createWNFT(address(impl_myshch), initCallData));
        
        // prepare
        walletServ = WNFTMyshchWallet(created);

        address[] memory _addrParams = new address[](1);
        _addrParams[0] = created;
        initCallData = abi.encodeWithSignature(
            impl_native.INITIAL_SIGN_STR(),
            WNFTV2Envelop721.InitParams(
                address(2), 
                "MyshchWallet", 
                "MSHW", 
                "https://api.envelop.is",
                _addrParams,
                new bytes32[](0),
                new uint256[](0),
                "" 
            )
        );
        created = payable(factory.createWNFT(address(impl_myshch), initCallData));
        walletUser = WNFTMyshchWallet(created);
        //Address.sendValue(payable(walletServ), 1e18);
        Address.sendValue(payable(walletUser), 2e18);
        //Address.sendValue(payable(SERV_OWNER), 1e18);
        erc20.transfer(address(walletServ), 100e18);
        assertNotEq(address(walletUser), address(walletServ));
        assertNotEq(erc20.balanceOf(address(walletUser)), erc20.balanceOf(address(walletServ)));
        assertEq(walletUser.ownerOf(1), address(2));
        assertEq(walletServ.ownerOf(1), SERV_OWNER);

    }

    function test_create_exec_with_refund() public {
        vm.txGasPrice(1);
        console2.log("Tx sender: %s, gasleft %s", msg.sender,  gasleft());
        AmountsBefore memory before;
        before.amount0 = SERV_OWNER.balance;
        before.amount1 = address(walletServ).balance;
        before.amount2 = address(walletUser).balance;
        before.amount3 = msg.sender.balance;
        // bytes memory _data = abi.encodeWithSignature(
        //     "transfer(address,uint256)",
        //     address(walletUser), sendERC20Amount
        // );

        // by owner
        //walletUser.approve(address(walletServ), walletUser.TOKEN_ID());
       
        vm.startPrank(SERV_OWNER);
        uint256 refAmount =  walletServ.erc20TransferWithRefund(address(erc20), address(walletUser), sendERC20Amount);
        vm.stopPrank();

        assertEq(erc20.balanceOf(address(walletUser)), sendERC20Amount);
        assertEq(address(walletUser).balance, before.amount2 - refAmount);
        assertEq(before.amount0 + refAmount, SERV_OWNER.balance);
        //console2.log("\nDefault sender: %s", msg.sender);
        //assertEq(msg.sender.balance, before.amount3);
        assertEq(before.amount1, address(walletServ).balance);
        // assertLt(uint256(3),uint256(2)); // this will revert : assertion failed: 3 >= 2

    }

    function test_createPredicted() public {
        address predictedwNFT1 = factory.predictDeterministicAddress(
            address(impl_native),
            keccak256(abi.encode(impl_native, address(walletServ), impl_native.nonce(address(walletServ)) + 1))
        );
        
        address predictedwNFT2 = factory.predictDeterministicAddress(
            address(impl_native),
            keccak256(abi.encode(impl_native, address(walletServ), impl_native.nonce(address(walletServ)) + 2))
        );

        erc20.transfer(predictedwNFT1, sendERC20Amount);
        erc20.transfer(predictedwNFT2, sendERC20Amount * 2);

        address[] memory targets = new address[](2);
        bytes[] memory dataArray = new bytes[](2);
        uint256[] memory values = new uint256[](2);

        targets[0] = address(impl_native);
        targets[1] = address(impl_native);

        // prepare data for child wallets
        WNFTV2Envelop721.InitParams memory initData = WNFTV2Envelop721.InitParams(
            address(1),
            'Envelop',
            'ENV',
            'https://api.envelop.is/',
            new address[](0),
            new bytes32[](0),
            new uint256[](0),
            ""
            );

        bytes memory _data = abi.encodeWithSignature(
            "createWNFTonFactory2((address,string,string,string,address[],bytes32[],uint256[],bytes))",
            initData
        );

        dataArray[0] = _data;
        dataArray[1] = _data;
        values[0] = 0;
        values[1] = 0;
        
        vm.prank(SERV_OWNER);
        bytes[] memory result = walletServ.executeEncodedTxBatch(targets, values, dataArray);
        //wnft.executeEncodedTx(address(impl_legacy), 0, _data);

        address payable w1 =  payable(abi.decode(result[0],
             (address)
        ));

        console2.log(w1);

        address payable w2 =  payable(abi.decode(result[1],
             (address)
        ));
        assertEq(w1, predictedwNFT1);
        assertEq(w2, predictedwNFT2);
        assertEq(erc20.balanceOf(w1), sendERC20Amount);
        assertEq(erc20.balanceOf(w2), sendERC20Amount * 2);

    }
    
}
