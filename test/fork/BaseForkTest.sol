// BaseForkTest.sol
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

abstract contract BaseForkTest is Test {

	modifier onlyOnFork() {
        if (block.chainid == 31337) {
            console2.log("Skipping test: no --rpc-url - local test run");
            return; // пропускаем тест
        }
        _;
    }
}
