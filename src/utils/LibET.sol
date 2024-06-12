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
}