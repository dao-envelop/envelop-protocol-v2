// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/console.sol";

import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import {MockERC721} from "../src/mock/MockERC721.sol";
import {MockERC1155} from "../src/mock/MockERC1155.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import "../src/impl/WNFTLegacy721.sol";
//import "../src/impl/Singleton721.sol";
//import {ET} from "../src/utils/LibET.sol";

// make approve
contract Factory_Test_a_08 is Test {
    
    event Log(string message);

    uint256 public sendEtherAmount = 1e18;
    uint256 public sendERC20Amount = 3e18;
    MockERC721 public erc721;
    MockERC1155 public erc1155;
    MockERC20 public erc20;
    EnvelopWNFTFactory public factory;
    WNFTLegacy721 public impl_legacy;

    receive() external payable virtual {}
    function setUp() public {
        erc721 = new MockERC721('Mock ERC721', 'ERC721');
        erc1155 = new MockERC1155('api.envelop.is');
        erc20 = new MockERC20('Mock ERC20', 'ERC20');
        factory = new EnvelopWNFTFactory();
        impl_legacy = new WNFTLegacy721();
        factory.setWrapperStatus(address(this), true); // set wrapper
    }
    
    function test_create_legacy() public {
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
                new ET.Lock[](0), // locks
                new ET.Royalty[](0), // royalties
                0x0105   //bytes2
            ) 
        );    

        address payable _wnftWallet = payable(factory.creatWNFT(address(impl_legacy), initCallData));
        assertNotEq(_wnftWallet, address(impl_legacy));

        WNFTLegacy721 wnft = WNFTLegacy721(_wnftWallet);
        
        // by owner
        wnft.approveHiden(address(10), impl_legacy.TOKEN_ID());
        // проверить тут тоже апрув - он кому дан по итогу

        // add collateral
        erc20.transfer(address(wnft), sendERC20Amount);
        uint256 tokenId = 2;
        erc721.mint(address(wnft), tokenId);
        uint256 amount = 10;
        erc1155.mint(address(1), tokenId, amount);
        vm.prank(address(1));
        erc1155.safeTransferFrom(address(1), _wnftWallet, tokenId, amount, '');
        /*(bool sent, bytes memory data) = _wnftWallet.call{value: sendEtherAmount}("");
        // suppress solc warnings 
        sent;
        data;


        // check remove collateral by spender
        vm.prank(address(10));
        ET.AssetItem memory collateral = ET.AssetItem(ET.Asset(ET.AssetType.NATIVE, address(0)),0,sendEtherAmount);
        wnft.removeCollateral(collateral, address(2));
        assertEq(address(2).balance, sendEtherAmount);
        assertEq(address(_wnftWallet).balance, 0);

        vm.prank(address(10));
        collateral = ET.AssetItem(ET.Asset(ET.AssetType.ERC20, address(erc20)),0,sendERC20Amount / 4);
        wnft.removeCollateral(collateral, address(2));
        assertEq(erc20.balanceOf(address(2)), sendERC20Amount / 4);
        assertEq(erc20.balanceOf(_wnftWallet), sendERC20Amount * 3 / 4);

        vm.prank(address(10));
        collateral = ET.AssetItem(ET.Asset(ET.AssetType.ERC721, address(erc721)),tokenId,0);
        wnft.removeCollateral(collateral, address(2));
        assertEq(erc721.ownerOf(tokenId), address(2));

        /*vm.prank(address(10));
        collateral = ET.AssetItem(ET.Asset(ET.AssetType.ERC1155, address(erc1155)),tokenId, amount / 2);
        wnft.removeCollateral(collateral, address(this));
        assertEq(erc1155.balanceOf(address(this), tokenId), amount / 2);
        assertEq(erc1155.balanceOf( _wnftWallet, tokenId), amount / 2);*/
    }
}