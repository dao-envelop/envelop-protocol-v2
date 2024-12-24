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

    constructor(
        address _defaultFactory
    )
        WNFTV2Envelop721(_defaultFactory)
    {}

     function createWNFTonFactory(InitParams memory _init) 
        public 
        override
        notDelegated 
        returns(address wnft) 
    {
        // To be sure about safe gas during proxy initializing. See Singleton721
        _init.nftName = "";
        _init.nftSymbol = "";
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
         return super.createWNFTonFactory2(_init);
    }

    function name() public pure override returns (string memory) {
        return nftName;
    } 

    function symbol() public pure override returns (string memory) {
        return nftSymbol;
    }
}