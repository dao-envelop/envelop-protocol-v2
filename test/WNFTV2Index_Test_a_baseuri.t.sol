// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {WNFTV2Index} from "../src/impl/WNFTV2Index.sol";
import {WNFTV2Envelop721} from "../src/impl/WNFTV2Envelop721.sol";

// Harness exposing the internal _baseURI() of the dindex implementation.
contract IndexBaseURIHarness is WNFTV2Index {
    constructor(address _defaultFactory) WNFTV2Index(_defaultFactory) {}

    function exposedBaseURI() external view returns (string memory) {
        return _baseURI();
    }
}

// Harness exposing the internal _baseURI() inherited from Singleton721
// (WNFTV2Envelop721 does not override it -> dwallet DEFAULT_BASE_URI path).
contract WalletBaseURIHarness is WNFTV2Envelop721 {
    constructor(address _defaultFactory) WNFTV2Envelop721(_defaultFactory) {}

    function exposedBaseURI() external view returns (string memory) {
        return _baseURI();
    }
}

// Regression test: addresses with leading zero bytes must NOT be truncated
// in the metadata base URI. See WNFTV2Index.sol / Singleton721.sol _baseURI().
contract WNFTV2Index_Test_a_baseuri is Test {
    using Strings for uint256;

    // Real-world address with a leading zero byte; uint160(addr) drops the top
    // 0x00 byte under the variable-length toHexString, producing a 38-hex string.
    address constant LEADING_ZERO_ADDR = 0x0006592A9C0B8fB97384cb71793c355fb0deDe2c;
    // Full, lowercase, zero-padded 40-hex representation expected in the URL.
    string constant FULL_ADDR_HEX = "0x0006592a9c0b8fb97384cb71793c355fb0dede2c";

    function test_index_baseURI_keeps_leading_zero() public {
        IndexBaseURIHarness ref = new IndexBaseURIHarness(address(0));
        // Place the implementation runtime code at the leading-zero address so
        // that address(this) inside _baseURI() is forced to LEADING_ZERO_ADDR.
        vm.etch(LEADING_ZERO_ADDR, address(ref).code);

        string memory uri = IndexBaseURIHarness(payable(LEADING_ZERO_ADDR)).exposedBaseURI();

        assertEq(
            uri,
            string(
                abi.encodePacked(
                    "https://api.envelop.is/dindex/", block.chainid.toString(), "/", FULL_ADDR_HEX, "/"
                )
            )
        );
    }

    function test_wallet_baseURI_keeps_leading_zero() public {
        WalletBaseURIHarness ref = new WalletBaseURIHarness(address(0));
        vm.etch(LEADING_ZERO_ADDR, address(ref).code);

        string memory uri = WalletBaseURIHarness(payable(LEADING_ZERO_ADDR)).exposedBaseURI();

        assertEq(
            uri,
            string(
                abi.encodePacked(
                    "https://api.envelop.is/dwallet/", block.chainid.toString(), "/", FULL_ADDR_HEX, "/"
                )
            )
        );
    }
}
