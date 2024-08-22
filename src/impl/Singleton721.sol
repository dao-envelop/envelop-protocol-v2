// SPDX-License-Identifier: MIT
// Envelop V2, Singleton NFT implementation
// Powered by OpenZeppelin Contracts 

pragma solidity ^0.8.20;

import {ERC721Upgradeable} from "@Uopenzeppelin/contracts/token/ERC721/ERC721Upgradeable.sol";

/// @title EIP-721 Metadata Update Extension
interface IERC4906 {
    /// @dev This event emits when the metadata of a token is changed.
    /// So that the third-party platforms such as NFT market could
    /// timely update the images and related attributes of the NFT.
    event MetadataUpdate(uint256 _tokenId);

    /// @dev This event emits when the metadata of a range of tokens is changed.
    /// So that the third-party platforms such as NFT market could
    /// timely update the images and related attributes of the NFTs.
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
}


/**
 * @dev Implementation of Envelop V2 Singleton NFT
 */
abstract contract Singleton721 is ERC721Upgradeable, IERC4906 {
    //using Strings for uint256;
    //using Strings for uint160;
    
    // Interface ID as defined in ERC-4906. This does not correspond 
    // to a traditional interface ID as ERC-4906 only
    // defines events and does not include any external function.
    bytes4 private constant ERC4906_INTERFACE_ID = bytes4(0x49064906);
    uint256 public constant TOKEN_ID = 1;
    string private constant DEFAULT_BASE_URI = "https://api.envelop.is/metadata/";
    
    
    
    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    function __Singleton721_init(
        string memory name_, 
        string memory symbol_,
        address _creator,
        string memory _tokenUrl
    ) internal onlyInitializing {
        // if (bytes(_tokenUrl).length == 0) {
        //     _tokenUrl = string(
        //     abi.encodePacked(
        //         DEFAULT_BASE_URI,
        //         block.chainid.toString(),
        //         "/",
        //         uint160(address(this)).toHexString(),
        //             "/"
        //         )
        //     );
        // }
        __ERC721_init_unchained(name_, symbol_);
        __Singleton721_init_unchained( _creator, _tokenUrl);
    }

    function __Singleton721_init_unchained(
        address _creator,
        string memory _tokenUrl
    ) internal onlyInitializing {
        _mint(_creator,TOKEN_ID);
        emit MetadataUpdate(TOKEN_ID);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    // function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165) returns (bool) {
    //     return
    //         interfaceId == type(IERC721).interfaceId ||
    //         interfaceId == type(IERC721Metadata).interfaceId ||
    //         interfaceId == type(IERC165).interfaceId ||
    //         interfaceId == ERC4906_INTERFACE_ID ;
    // }

 
}

