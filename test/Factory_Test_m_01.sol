// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/console.sol";

import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import {MockERC721} from "../src/mock/MockERC721.sol";
//import "../src/impl/Singleton721.sol";
//import {ET} from "../src/utils/LibET.sol";


contract Factory_Test_m_01 is Test {
    uint256 public sendEtherAmount = 1e18;
    MockERC721 public erc721;
    EnvelopWNFTFactory public factory;

    receive() external payable virtual {}
    function setUp() public {
        erc721 = new MockERC721('Mock ERC721', 'ERC');
        factory = new EnvelopWNFTFactory();
    }
    
    function test_create() public {
        bytes memory initCallData;
        address created = factory.creatWNFT(address(erc721), initCallData);
        MockERC721  erc721_clone = MockERC721(created);
        assertEq(erc721.CHECKED_NAME(), erc721_clone.CHECKED_NAME());
        assertNotEq(address(erc721), address(erc721_clone));
    }
}