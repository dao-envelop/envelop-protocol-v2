// SPDX-License-Identifier: MIT
// Envelop V2, Wallet
pragma solidity ^0.8.20;

abstract contract WNFTWallet {
	 /**
     * @dev Use this method for interact any dApps onchain
     * @param _target address of dApp smart contract
     * @param _value amount of native token in tx(msg.value)
     * @param _data ABI encoded transaction payload
     */
    // function executeEncodedTx(
    //     address _target,
    //     uint256 _value,
    //     bytes memory _data
    // ) 
    //     external 
    //     // ifUnlocked()
    //     // onlyWnftOwner()
    //     // fixEtherBalance
    //     returns (bytes memory r) 
    // {
    //     if (keccak256(_data) == keccak256(bytes(""))) {
    //         Address.sendValue(payable(_target), _value);
    //     } else {
    //         r = Address.functionCallWithValue(_target, _data, _value);
    //     }
    //     //_checkInAssetSafety();
    // }

    // /**
    //  * @dev Use this method for interact any dApps onchain, executing as one batch
    //  * @param _targetArray addressed of dApp smart contract
    //  * @param _valueArray amount of native token in every tx(msg.value)
    //  * @param _dataArray ABI encoded transaction payloads
    //  */
    // function executeEncodedTxBatch(
    //     address[] calldata _targetArray,
    //     uint256[] calldata _valueArray,
    //     bytes[] memory _dataArray
    // ) 
    //     external 
    //     // ifUnlocked()
    //     // onlyWnftOwner() 
    //     // fixEtherBalance
    //     returns (bytes[] memory r) 
    // {
    
    //     r = new bytes[](_dataArray.length);
    //     for (uint256 i = 0; i < _dataArray.length; ++ i){
    //         if (keccak256( _dataArray[i]) == keccak256(bytes(""))) {
    //             Address.sendValue(payable(_targetArray[i]), _valueArray[i]);
    //         } else {
    //             r[i] = Address.functionCallWithValue(_targetArray[i], _dataArray[i], _valueArray[i]);
    //         }
    //     }
    //     //_checkInAssetSafety();
    // }

}