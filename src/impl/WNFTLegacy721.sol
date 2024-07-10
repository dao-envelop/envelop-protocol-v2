// SPDX-License-Identifier: MIT
// Envelop V2, wNFT implementation
// Powered by OpenZeppelin Contracts 

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./Singleton721.sol";
import "../utils/LibET.sol";
//import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
// import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
// import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
// import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
// import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
// import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";


/**
 * @dev Implementation of WNFT that compatible with Envelop V1
 */
contract WNFTLegacy721 is Singleton721 {
    //using Strings for uint256;
    //using Strings for uint160;
    
   
    /// @custom:storage-location erc7201:openzeppelin.storage.ERC721
    struct WNFTLegacy721Storage {
        // Token name
        ET.WNFT wnftData;

        // Token symbol

    }

    
    // keccak256(abi.encode(uint256(keccak256("envelop.storage.WNFTLegacy721")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant WNFTLegacy721StorageLocation = 0xb25b7d902932741f4867febf64c52dbc3980210eefc4a36bf4280ce48f34a100;

    function initialize(
        address _creator,
        string memory name_,
        string memory symbol_,
        string memory _tokenUrl,
        ET.WNFT calldata _wnftData
    ) public initializer
    {
        
        __WNFTLegacy721_init(name_, symbol_, _creator, _tokenUrl, _wnftData);
    }
        
    ////////////////////////////////////////////////////////////////////////
    // OZ init functions layout                                           //
    ////////////////////////////////////////////////////////////////////////    

    function _getWNFTLegacy721Storage() private pure returns (WNFTLegacy721Storage storage $) {
        assembly {
            $.slot := WNFTLegacy721StorageLocation
        }
    }

    
    
    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    function __WNFTLegacy721_init(
        string memory name_, 
        string memory symbol_,
        address _creator,
        string memory _tokenUrl,
        ET.WNFT memory _wnftData
    ) internal onlyInitializing {
        __ERC721_init(name_, symbol_, _creator, _tokenUrl);
        __WNFTLegacy721_init_unchained(_wnftData);
    }

    function __WNFTLegacy721_init_unchained(
        // string memory name_, 
        // string memory symbol_,
        // address _creator,
        // string memory _tokenUrl,
        ET.WNFT memory _wnftData
    ) internal onlyInitializing {
        WNFTLegacy721Storage storage $ = _getWNFTLegacy721Storage();
        //$.wnftData = _wnftData;
        // $._symbol = symbol_;
        // $._owner = _creator;
        // $._tokenURI = _tokenUri;
        // emit MetadataUpdate(TOKEN_ID);
    }
    ////////////////////////////////////////////////////////////////////////
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual  override returns (bool) {
        // TODO  add current contract interface
        return super.supportsInterface(interfaceId);
    }

    function wnftInfo(uint256 tokenId) external view returns (ET.WNFT memory) {
        //return IWrapper(wrapperMinter).getWrappedToken(address(this), tokenId);
    }

    
}

