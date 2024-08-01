// SPDX-License-Identifier: MIT
// Envelop V2, wNFT implementation
// Powered by OpenZeppelin Contracts 

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./Singleton721.sol";
import "../utils/LibET.sol";
import "../utils/TokenService.sol";
//import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
// import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
// import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
// import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
// import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
// import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";


/**
 * @dev Implementation of WNFT that partial compatible with Envelop V1
 */
contract WNFTLegacy721 is Singleton721, TokenService {
    //using Strings for uint256;
    //using Strings for uint160;
    string public constant INITIAL_SIGN_STR = "initialize()";
    
   
    /// @custom:storage-location erc7201:openzeppelin.storage.ERC721
    struct WNFTLegacy721Storage {
        // Token name
        ET.WNFT wnftData;

        // Token symbol

    }

    error InsufficientCollateral(ET.AssetItem declare, uint256 fact);
    error WnftRuleViolation(bytes2 rule);

    event EtherTransfer(uint256 value);

     /**
     * @dev The contract should be able to receive Eth.
     */
    receive() external payable virtual {
        emit EtherTransfer(msg.value);
    }

     modifier ifUnlocked() {
        _checkLocks();
        _;
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
        $.wnftData.inAsset = _wnftData.inAsset;
        $.wnftData.unWrapDestination = _wnftData.unWrapDestination;
        $.wnftData.rules = _wnftData.rules;
        if (_wnftData.locks.length > 0) {
            // TODO Check logs and put to storage
            for (uint256 i = 0; i < _wnftData.locks.length; ++ i) {
                _isValidLockRecord(_wnftData.locks[i]);
                $.wnftData.locks.push(_wnftData.locks[i]);
            }
        }
        if (_wnftData.collateral.length > 0) {
            // TODO Check collateral Balance
            // !!!! Dont save collateral info!!!
             for (uint256 i = 0; i < _wnftData.collateral.length; ++ i) {
                _isValidCollateralRecord(_wnftData.collateral[i]);
                $.wnftData.collateral.push(_wnftData.collateral[i]);
            }
        }
        if (_wnftData.inAsset.asset.assetType != ET.AssetType.EMPTY) {
            // asset that user want to wrap must be transfered to wNFT adddress 
            _isValidCollateralRecord(_wnftData.inAsset);
        }
        // emit WnFTCreated....
    }
    ////////////////////////////////////////////////////////////////////////
    function transferFrom(address from, address to, uint256 tokenId) public override {
        WNFTLegacy721Storage storage $ = _getWNFTLegacy721Storage();
        // Check No Transfer rule
        if (!_checkRule(0x0004, $.wnftData.rules)) {
            revert WnftRuleViolation(0x0004);
        }
        super.transferFrom(from, to, tokenId);
    }

    function removeCollateral(ET.AssetItem calldata _collateral, address _to )
        public 
        ifUnlocked() 
    {
        // TODO Check for removing InAsset - ask Alex
        if (ownerOf(TOKEN_ID) == msg.sender) {
            _transferSafe(_collateral, address(this), _to);
        }
        
    }

    function removeCollateralBatch(ET.AssetItem[] calldata _collateral, address _to ) 
        public 
        ifUnlocked()
    {
        // TODO Check for removing InAsset - ask Alex
        if (ownerOf(TOKEN_ID) == msg.sender) {
            for (uint256 i = 0; i < _collateral.length; ++ i) 
            _transferSafe(_collateral[i], address(this), _to);
        }
        
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual  override returns (bool) {
        // TODO  add current contract interface
        return super.supportsInterface(interfaceId);
    }

    function wnftInfo(uint256 tokenId) external view returns (ET.WNFT memory) {
        tokenId; // suppress solc warn
        WNFTLegacy721Storage storage $ = _getWNFTLegacy721Storage();
        return $.wnftData;
    }

    function tokenURI(uint256 tokenId) public view  override returns (string memory uri_) {
        WNFTLegacy721Storage storage $ = _getWNFTLegacy721Storage();
        uri_ = _getURI($.wnftData.inAsset);
        if (bytes(uri_).length == 0) {
            uri_ = super.tokenURI(tokenId);    
        }
    }

    // 0x00 - TimeLock
    // 0x01 - TransferFeeLock   - UNSUPPORTED IN THIS IMPLEMENATION
    // 0x02 - Personal Collateral count Lock check  - UNSUPPORTED IN THIS IMPLEMENATION
    function _checkLocks() internal virtual {
        WNFTLegacy721Storage storage $ = _getWNFTLegacy721Storage();
        ET.Lock[] memory lck = $.wnftData.locks;
        for (uint256 i = 0; i < lck.length; ++ i) {
            if (lck[i].lockType == 0x00) {
                require(
                    lck[i].param <= block.timestamp,
                    "TimeLock error"
                );
            }
        }
    }
    
    // #### Envelop ProtocolV1 Rules !!! NOT All support in this implementation V2
    // 15   14   13   12   11   10   9   8   7   6   5   4   3   2   1   0  <= Bit number(dec)
    // ------------------------------------------------------------------------------------  
    //  1    1    1    1    1    1   1   1   1   1   1   1   1   1   1   1
    //  |    |    |    |    |    |   |   |   |   |   |   |   |   |   |   |
    //  |    |    |    |    |    |   |   |   |   |   |   |   |   |   |   +-No_Unwrap
    //  |    |    |    |    |    |   |   |   |   |   |   |   |   |   +-No_Wrap 
    //  |    |    |    |    |    |   |   |   |   |   |   |   |   +-No_Transfer
    //  |    |    |    |    |    |   |   |   |   |   |   |   +-No_Collateral
    //  |    |    |    |    |    |   |   |   |   |   |   +-reserved_core
    //  |    |    |    |    |    |   |   |   |   |   +-reserved_core
    //  |    |    |    |    |    |   |   |   |   +-reserved_core  
    //  |    |    |    |    |    |   |   |   +-reserved_core
    //  |    |    |    |    |    |   |   |
    //  |    |    |    |    |    |   |   |
    //  +----+----+----+----+----+---+---+
    //      for use in extendings
    /**
     * @dev Use for check rules above.
     */
    function _checkRule(bytes2 _rule, bytes2 _wNFTrules) internal pure virtual returns (bool) {
        return _rule == (_rule & _wNFTrules);
    }

    function _isValidLockRecord(ET.Lock memory _lockRec) internal virtual view {

    }

    function _isValidCollateralRecord(ET.AssetItem memory _collateralRecord) 
        internal 
        virtual
        view 
    {
        uint256 b = _balanceOf(_collateralRecord, address(this));
        if (b < _collateralRecord.amount) {
            revert InsufficientCollateral(_collateralRecord, b);
        }
    }
    
}
