// SPDX-License-Identifier: MIT
// Envelop V2, wNFT implementation

pragma solidity ^0.8.28;

import "./WNFTV2Envelop721.sol";

/**
 * @dev Native Envelop V2 mplementation of WNFT for INDEX.
 * This contract initialization is more cheap
 */
contract WNFTV2Index is WNFTV2Envelop721 {
    string constant nftName   = "Envelop wNFT V2 Index";
    string constant nftSymbol = "ENVELOPV2";
    string constant public indexVersion = "2.0.1";

    struct IndexData {
        string version;
        uint256 startPrice;
    }
    constructor(
        address _defaultFactory
    )
        WNFTV2Envelop721(_defaultFactory)
    {}

    function __WNFTV2Envelop721_init_unchained_posthook(
        InitParams calldata _init,
        WNFTV2Envelop721Storage storage _st
    ) internal virtual override {
        require(_init.numberParams.length > 1, "At least two numberParams for valid index");
        //_init.numberParams[0] - timestamp for timelock 
        //_init.numberParams[1] - index start price
        if (_init.numberParams.length  >  1) {
            IndexData memory indexData = IndexData(
                indexVersion,
                _init.numberParams[1]
            );
            // in this implementation we do not store price in contract state/  Only logs
            //_st.wnftData.locks.push(ET.Lock(0xff, _init.numberParams[1]));
            emit EnvelopWrappedV2(
              _init.creator, 
              TOKEN_ID,  
              _st.wnftData.rules, 
              abi.encode(indexData) // index data
            );
        } else {
            emit EnvelopWrappedV2(_init.creator, TOKEN_ID,  _st.wnftData.rules, "");    
        }
        
    } 

    function createWNFTonFactory(InitParams memory _init) 
        public 
        override
        notDelegated 
        returns(address wnft) 
    {
        // To be sure about safe gas during proxy initializing. See Singleton721
        _init.nftName = "";
        _init.nftSymbol = "";
        _init.tokenUri = "";
        return super.createWNFTonFactory(_init);
    }

    function createWNFTonFactory2(InitParams memory _init) 
        public
        override 
        notDelegated 
        returns(address wnft) 
    {
        // To be sure about safe gas during proxy initializing. See Singleton721
         _init.nftName = "";
         _init.nftSymbol = "";
         _init.tokenUri = "";
         return super.createWNFTonFactory2(_init);
    }

    function name() public pure override returns (string memory) {
        return nftName;
    } 

    function symbol() public pure override returns (string memory) {
        return nftSymbol;
    }
}