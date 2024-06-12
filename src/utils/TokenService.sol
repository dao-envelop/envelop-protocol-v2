// SPDX-License-Identifier: MIT
// ENVELOP(NIFTSY) protocol for NFT. 
pragma solidity ^0.8.20;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "./LibET.sol";

/// @title Envelop helper service for ERC(20, 721, 1155) transfers
/// @author Envelop Team
/// @notice Full refactored from Enveop V1
abstract contract TokenService {
	using Address for address;
    
    error UnSupportedAsset(ET.AssetItem asset);
    error TokenTransferFailed(address assetAddress);
	

    function _getTransferTxData(
        ET.AssetItem memory _assetItem,
        address _from,
        address _to
    ) internal view returns(bytes memory _calldata) {
        if (_assetItem.asset.assetType == ET.AssetType.NATIVE) {
        } else if (_assetItem.asset.assetType == ET.AssetType.ERC20) {
            if (_from == address(this)){
               _calldata = abi.encodeWithSignature("transfer(address,uint256)", _to, _assetItem.amount);
            } else {
               _calldata = abi.encodeWithSignature("transferFrom(address,address,uint256)", _from, _to, _assetItem.amount); 
            }
        } else if (_assetItem.asset.assetType == ET.AssetType.ERC721) {
            _calldata = abi.encodeWithSignature("transferFrom(address,address,uint256)", _from, _to, _assetItem.tokenId);
        } else if (_assetItem.asset.assetType == ET.AssetType.ERC1155) {
            _calldata = abi.encodeWithSignature("safeTransferFrom(address,address,uint256,uint256,bytes)", 
                _from, _to, _assetItem.tokenId, _assetItem.amount, bytes(''));
        } else {
            revert UnSupportedAsset(_assetItem);
        }

    }

    /**
     * @dev This function must never revert. Use it for Last Chance
     * to transfer suspecial token
     */ 
    function _transferEmergency(
        ET.AssetItem memory _assetItem,
        address _from,
        address _to
    ) internal virtual returns (bytes memory _returndata){
        bytes memory transferCallData;
        if (_assetItem.asset.assetType == ET.AssetType.NATIVE) {
            Address.sendValue(payable(_to), _assetItem.amount);
        } else {
            transferCallData = _getTransferTxData(_assetItem, _from, _to);
            // Low level Call with OZ Address
            _returndata = _assetItem.asset.contractAddress.functionCall(
                transferCallData);
        }
    }

     /**
     * @dev Implement Transfer logic for supporting tokens. If `_assetItem` returns no value,
     * non-reverting calls are assumed to be successful. 
     */
    function _transfer(
        ET.AssetItem memory _assetItem,
        address _from,
        address _to
    ) internal virtual returns (bytes memory returndata) {
        returndata = _transferEmergency(_assetItem, _from, _to);
        // Like OZ  SafeERC20 check
        // We need to perform a low level call here, to bypass Solidity's return 
        // data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, 
        // which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert TokenTransferFailed(_assetItem.asset.contractAddress);
        }
    }

    function _transferSafe(
        ET.AssetItem memory _assetItem,
        address _from,
        address _to
    ) internal virtual returns (uint256 _transferedValue){
        uint256 balanceBefore;
        if (_assetItem.asset.assetType == ET.AssetType.NATIVE) {
            balanceBefore = _to.balance;
            _transfer(_assetItem, _from, _to);
            _transferedValue = _to.balance - balanceBefore;
        
        } else if (_assetItem.asset.assetType == ET.AssetType.ERC20) {
            balanceBefore = _balanceOf(_assetItem, _to);
            _transfer(_assetItem, _from, _to);  
            _transferedValue = _balanceOf(_assetItem, _to) - balanceBefore;
        
        } else if (_assetItem.asset.assetType == ET.AssetType.ERC721 && _ownerOf(_assetItem) == _from){
            balanceBefore = _balanceOf(_assetItem, _to);
             _transfer(_assetItem, _from, _to);
            if (_ownerOf(_assetItem) == _to && _balanceOf(_assetItem, _to) - balanceBefore == 1) {
                _transferedValue = 1;
            }
        
        } else if (_assetItem.asset.assetType == ET.AssetType.ERC1155) {
            balanceBefore = _balanceOf(_assetItem, _to);
            _transfer(_assetItem, _from, _to);  
            _transferedValue = _balanceOf(_assetItem, _to) - balanceBefore;
        
        } else {
            revert UnSupportedAsset(_assetItem);
        }
        return _transferedValue;
    }


    function _balanceOf(
        ET.AssetItem memory _assetItem,
        address _holder
    ) internal view virtual returns (uint256 _balance){
        bytes memory _calldata;
        bytes memory _returnedData;
        if (_assetItem.asset.assetType == ET.AssetType.NATIVE) {
            _balance = _holder.balance;

        } else if (_assetItem.asset.assetType == ET.AssetType.ERC20) {
             _calldata = abi.encodeWithSignature("balanceOf(address)", _holder);

        } else if (_assetItem.asset.assetType == ET.AssetType.ERC721) {
            _calldata = abi.encodeWithSignature("balanceOf(address)", _holder);

        } else if (_assetItem.asset.assetType == ET.AssetType.ERC1155) {
            _calldata = abi.encodeWithSignature("balanceOf(address,uint256)", _holder, _assetItem.tokenId);

        } else {
            revert UnSupportedAsset(_assetItem);
        }

        if (_assetItem.asset.assetType != ET.AssetType.NATIVE) {
            _returnedData = _assetItem.asset.contractAddress.functionStaticCall(_calldata);
            _balance = abi.decode(_returnedData, (uint256));
        }
    }

    function _ownerOf(
        ET.AssetItem memory _assetItem
    ) internal view virtual returns (address _owner){
        if (_assetItem.asset.assetType == ET.AssetType.NATIVE) {
            _owner = address(0);
        
        } else if (_assetItem.asset.assetType == ET.AssetType.ERC20) {
            _owner = address(0);
        } else if (_assetItem.asset.assetType == ET.AssetType.ERC721) {
            bytes memory _calldata = abi.encodeWithSignature("ownerOf(uint256)", _assetItem.tokenId);
            bytes memory _returnedData = _assetItem.asset.contractAddress.functionStaticCall(_calldata);
            _owner = abi.decode(_returnedData, (address));
        } else if (_assetItem.asset.assetType == ET.AssetType.ERC1155) {
            _owner = address(0);
        } else {
            revert UnSupportedAsset(_assetItem);
        }
    }

    function _isApprovedFor(
        ET.AssetItem memory _assetItem,
        address _owner,
        address _spender
    ) internal view virtual returns (uint256 _approvedBalance){
        bytes memory _calldata;
        bytes memory _returnedData;
        if (_assetItem.asset.assetType == ET.AssetType.NATIVE) {
            _approvedBalance = 0;
        } else if (_assetItem.asset.assetType == ET.AssetType.ERC20) {
             _calldata = abi.encodeWithSignature("allowance(address,address)", _owner, _spender);
             _returnedData = _assetItem.asset.contractAddress.functionStaticCall(_calldata);
             _approvedBalance = abi.decode(_returnedData, (uint256));

        } else if (_assetItem.asset.assetType == ET.AssetType.ERC721) {
            // Because there are two ways to approve ERC721
            _calldata = abi.encodeWithSignature("isApprovedForAll(address,address)", _owner, _spender);
            _returnedData = _assetItem.asset.contractAddress.functionStaticCall(_calldata);
            if (abi.decode(_returnedData, (bool))) {
                _approvedBalance = 1;
            } else {
                _calldata = abi.encodeWithSignature("getApproved(uint256)", _assetItem.tokenId);
                 _returnedData = _assetItem.asset.contractAddress.functionStaticCall(_calldata);
                address _spndr = abi.decode(_returnedData, (address));
                if (_spndr == _spender){
                    _approvedBalance = 1;
                }
            }

        } else if (_assetItem.asset.assetType == ET.AssetType.ERC1155) {
            _calldata = abi.encodeWithSignature("isApprovedForAll(address,address)", _owner, _spender);
            _returnedData = _assetItem.asset.contractAddress.functionStaticCall(_calldata);
            if (abi.decode(_returnedData, (bool))) {
                _approvedBalance = 1;
            }
        } else {
            revert UnSupportedAsset(_assetItem);
        }
        
    }
}