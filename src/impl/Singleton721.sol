// SPDX-License-Identifier: MIT
// Envelop V2, Singleton NFT implementation
// Powered by OpenZeppelin Contracts 

pragma solidity ^0.8.20;

import "@Uopenzeppelin/contracts/token/ERC721/ERC721Upgradeable.sol";

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
    using Strings for uint256;
    using Strings for uint160;
    
    // Interface ID as defined in ERC-4906. This does not correspond 
    // to a traditional interface ID as ERC-4906 only
    // defines events and does not include any external function.
    bytes4 private constant ERC4906_INTERFACE_ID = bytes4(0x49064906);
    uint256 public constant TOKEN_ID = 1;
    string public constant DEFAULT_BASE_URI = "https://api.envelop.is/v2meta/";
    
      //string public constant INITIAL_SIGN_STR = "initialize(address,string,string,string)";
    
   
    struct Singleton721Storage {
        string customBaseURL;
    }

    // keccak256(abi.encode(uint256(keccak256("envelop.storage.Singleton721")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant Singleton721StorageLocation = 0xbdcdd84fd67773ac64bbe05336a88ca03e25175d9b4a6f280761928862a7ed00;

    modifier onlyWnftOwner() {
        _wnftOwnerOrApproved(msg.sender);
        _;
    }

    function _getSingleton721Storage() private pure returns (Singleton721Storage storage $) {
        assembly {
            $.slot := Singleton721StorageLocation
        }
    }

    
    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    function __Singleton721_init(
        string memory name_, 
        string memory symbol_,
        address _creator,
        string memory _tokenUrl
    ) internal onlyInitializing {
        
        // In case of miss name_  there is no reason to init `ERC721Upgradeable`
        // because default values can be used
        if (bytes(name_).length != 0){
            __ERC721_init_unchained(name_, symbol_);    
        } 
        
        __Singleton721_init_unchained( _creator, _tokenUrl);
    }

    function __Singleton721_init_unchained(
        address _creator,
        string memory _tokenUrl
    ) internal onlyInitializing {
        _mint(_creator,TOKEN_ID);
        if (bytes(_tokenUrl).length != 0) {
             Singleton721Storage storage $ = _getSingleton721Storage();
            $.customBaseURL = _tokenUrl;
        }
        emit MetadataUpdate(TOKEN_ID);
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view override virtual returns (string memory) {
        Singleton721Storage storage $ = _getSingleton721Storage();
        if (bytes($.customBaseURL).length == 0) {
            return string(
                abi.encodePacked(
                    DEFAULT_BASE_URI,
                    block.chainid.toString(),
                    "/",
                    uint160(address(this)).toHexString(),
                    "/"
                )
            );
        } else {
            return string(
                abi.encodePacked(
                    $.customBaseURL,
                    block.chainid.toString(),
                    "/",
                    uint160(address(this)).toHexString(),
                    "/"
                )
            );
        }


    }


    function  _wnftOwnerOrApproved(address _sender) internal view virtual {
        address currOwner = ownerOf(TOKEN_ID);
        require(
            currOwner == _sender ||
            isApprovedForAll(currOwner, _sender) ||
            getApproved(TOKEN_ID) == _sender,
            "Only for wNFT owner"
        );
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

