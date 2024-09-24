// SPDX-License-Identifier: MIT
// NIFTSY protocol for NFT
pragma solidity 0.8.21;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MaliciousTokenMock1 is ERC20 {

    address public failSender;
    constructor(string memory name_,
        string memory symbol_) ERC20(name_, symbol_)  {
        _mint(msg.sender, 1000000000000000000000000000);

    }

    function setFailSender(address _failSender) external {
        failSender = _failSender;
    }

    function _update(address from, address to, uint256 value) internal virtual override {
        if (from == failSender) {
            super._update(from, to, value / 2);
        } else {
            super._update(from, to, value);
        }

        
    }
}
