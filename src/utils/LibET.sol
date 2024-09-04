// SPDX-License-Identifier: MIT
// ENVELOP(NIFTSY) protocol NFT. 
pragma solidity ^0.8.20;

/// @title Library for asset eoperation encoding from Envelop/
/// @author Envelop Team
/// @notice This lib implement asset's data types
library ET {

    enum AssetType {EMPTY, NATIVE, ERC20, ERC721, ERC1155, FUTURE1, FUTURE2, FUTURE3}
    enum OrderType {SELL, BUY, FUTURE1, FUTURE2, FUTURE3, FUTURE4, FUTURE5, FUTURE6}

    struct Asset {
        AssetType assetType;
        address contractAddress;
    }

    struct AssetItem {
        Asset asset;
        uint256 tokenId;
        uint256 amount;
    }

    struct NFTItem {
        address contractAddress;
        uint256 tokenId;   
    }

    struct Price {
        address payToken;
        uint256 payAmount;
    }

    struct Order {
        bytes32 orderId;
        OrderType orderType;
        address orderBook;
        address orderMaker;
        uint256 amount;
        Price price;
        bool assetApproveExist;
    }
    // ////////////////////////
    //  For legacy wNFT support
    // ////////////////////////
    struct Fee {
        bytes1 feeType;
        uint256 param;
        address token; 
    }

    struct Lock {
        bytes1 lockType;
        uint256 param; 
    }

    struct Royalty {
        address beneficiary;
        uint16 percent;
    }

    struct WNFT {
        AssetItem inAsset;
        AssetItem[] collateral;
        address unWrapDestination;
        Fee[] fees;
        Lock[] locks;
        Royalty[] royalties;
        bytes2 rules;

    }

}