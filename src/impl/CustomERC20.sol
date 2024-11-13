// SPDX-License-Identifier: MIT
// Envelop V2, Custom ERC20 token for Myshch

import "@Uopenzeppelin/contracts/token/ERC20/ERC20Upgradeable.sol";

pragma solidity ^0.8.20;

contract CustomERC20 is ERC20Upgradeable {

	struct InitDistributtion {
		address receiver;
		uint256 amount;
	}

	string public constant INITIAL_SIGN_STR = 
        "initialize(address,string,string,uint256,(address,uint256)[])";

	constructor() {
      _disableInitializers();
    }

	function initialize(
		address _creator,
        string memory name_,
        string memory symbol_,
        uint256 _totalSupply,
        InitDistributtion[] memory _initialHolders
    ) public initializer {
    	__ERC20_init(name_, symbol_);
    	_mint(_creator, _totalSupply);
    	if (_initialHolders.length > 0) {
    		for (uint256 i = 0; i < _initialHolders.length; ++ i) {
    			_transfer(_creator, _initialHolders[i].receiver, _initialHolders[i].amount);
    		}
    	}

    }
}