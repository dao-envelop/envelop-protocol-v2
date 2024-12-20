// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract MockERC721 is ERC721URIStorage {
    string constant public CHECKED_NAME = "Mock ERC721 !!!";
    uint256 public constant ORACLE_TYPE = 2001;
	
    constructor(string memory name_,
        string memory symbol_) ERC721(name_, symbol_)  {
    	_mint(msg.sender, 0);
        _setTokenURI(0, 'yeee');
    }

    function mintWithURI(
        address to, 
        uint256 tokenId, 
        string memory _tokenURI 
    ) external {
        
        _mint(to, tokenId);
        _setTokenURI(tokenId, _tokenURI);
    }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
    
    //TODO Remove if not usefull
    function setURI(uint256 tokenId, string memory _tokenURI) external {
        require(ownerOf(tokenId) == msg.sender, 'Only owner can change URI.');
        _setTokenURI(tokenId, _tokenURI);

    }

    function _baseURI() internal pure  override returns (string memory) {
        return 'https://bugsbunny.com/';
    }
}