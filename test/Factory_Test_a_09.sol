// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/console.sol";

import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import {MockERC721} from "../src/mock/MockERC721.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import "../src/impl/WNFTLegacy721.sol";
//import "../src/impl/Singleton721.sol";
//import {ET} from "../src/utils/LibET.sol";

// time lock, call removeCollateral and unwrap
contract Factory_Test_a_09 is Test {
    
    event Log(string message);

    uint256 public sendEtherAmount = 1e18;
    uint256 public sendERC20Amount = 3e18;
    uint256 timelock = 10000;
    MockERC721 public erc721;
    MockERC20 public erc20;
    EnvelopWNFTFactory public factory;
    WNFTLegacy721 public impl_legacy;

    receive() external payable virtual {}
    function setUp() public {
        erc721 = new MockERC721('Mock ERC721', 'ERC721');
        erc20 = new MockERC20('Mock ERC20', 'ERC20');
        factory = new EnvelopWNFTFactory();
        impl_legacy = new WNFTLegacy721();
        factory.setWrapperStatus(address(this), true); // set wrapper
    }
    
    function test_create_legacy() public {
        ET.Lock[] memory locks = new ET.Lock[](1);
        locks[0] = ET.Lock(0x00, block.timestamp + timelock);
        bytes memory initCallData = abi.encodeWithSignature(
            impl_legacy.INITIAL_SIGN_STR(),
            address(this), // creator and owner 
            "LegacyWNFTNAME", 
            "LWNFT", 
            "https://api.envelop.is" ,
            //new ET.WNFT[](1)[0]
            ET.WNFT(
                ET.AssetItem(ET.Asset(ET.AssetType.EMPTY, address(0)),0,0), // inAsset
                new ET.AssetItem[](0),   // collateral
                address(0), //unWrapDestination 
                new ET.Fee[](0), // fees
                locks, // locks
                new ET.Royalty[](0), // royalties
                0x0000   //bytes2
            ) 
        );  

        address payable _wnftWallet = payable(factory.creatWNFT(address(impl_legacy), initCallData));
        
        // send collateral to wnft wallet
        erc20.transfer(_wnftWallet, sendERC20Amount);
        (bool sent, bytes memory data) = _wnftWallet.call{value: sendEtherAmount}("");
        // suppress solc warnings 
        sent;
        data;
        
        WNFTLegacy721 wnft = WNFTLegacy721(_wnftWallet);

        // try to withdraw erc20 in time lock period
        ET.AssetItem memory collateral = ET.AssetItem(ET.Asset(ET.AssetType.ERC20, address(erc20)),0,sendERC20Amount / 2);
        vm.expectRevert('TimeLock error');
        wnft.removeCollateral(collateral, address(2));

        // try to withdraw collateral batch in time lock period
        ET.AssetItem[] memory collaterals = new ET.AssetItem[](2);
        collaterals[0] = collateral;
        collateral = ET.AssetItem(ET.Asset(ET.AssetType.NATIVE, address(0)),0,sendEtherAmount / 2);
        collaterals[1] = collateral;
        vm.expectRevert('TimeLock error');
        wnft.removeCollateralBatch(collaterals, address(2));

        // try to unwrap in time lock period
        vm.expectRevert('TimeLock error');
        wnft.unWrap(collaterals);

        vm.warp(timelock + 1);
        collateral = ET.AssetItem(ET.Asset(ET.AssetType.ERC20, address(erc20)),0,sendERC20Amount / 2);
        wnft.removeCollateral(collateral, address(2));
        assertEq(erc20.balanceOf(address(2)),sendERC20Amount / 2 );

        wnft.removeCollateralBatch(collaterals, address(2));
        assertEq(erc20.balanceOf(address(2)),sendERC20Amount);
        assertEq(address(2).balance, sendEtherAmount / 2);

        ET.AssetItem[] memory collaterals1 = new ET.AssetItem[](1);
        collateral = ET.AssetItem(ET.Asset(ET.AssetType.NATIVE, address(0)),0,sendEtherAmount / 2);
        collaterals1[0] = collateral;
        uint256 balanceBefore = address(this).balance;
        vm.expectEmit();
        emit WNFTLegacy721.UnWrappedV1(
            _wnftWallet,                            // wrappedAddress,
            address(0), // originalAddress,
            impl_legacy.TOKEN_ID(),                                 // wrappedId, 
            0,               // originalTokenId, 
            address(this),                               // beneficiary, 
            0,                                        // NOT SUPPORTED IN THIS IMPLEMENTATION, use  
            bytes2("")                          // rules 
        );
        wnft.unWrap(collaterals1);

        assertEq(address(this).balance, balanceBefore + sendEtherAmount / 2);
        assertEq(_wnftWallet.balance, 0);
        assertEq(erc20.balanceOf(_wnftWallet), 0);
    }
}