// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

contract RisePool {
    uint256 private assetIdCounter = 1; // temporary

    mapping(uint256 => uint256) public tokenPoolAmounts; // assetId => tokenCount
    mapping(uint256 => uint256) public tokenReserveAmounts; // assetId => tokenCount

    // related to listing new assets (temporary)
    function setAssetIdCounter(uint256 _count) external {
        // onlyAdmin
        assetIdCounter = _count;
    }

    function isAssetIdValid(uint256 _assetId) external view returns (bool) {
        // TODO: deal with delisting assets
        return _assetId < assetIdCounter;
    }

    // function getTokenPoolAmounts(
    //     uint256 _assetId
    // ) external view returns (uint256) {
    //     return tokenPoolAmounts[_assetId];
    // }

    // TODO: onlyManager
    function increasePoolAmounts(uint256 _assetId, uint256 _amount) public {
        tokenPoolAmounts[_assetId] += _amount;
    }

    // TODO: onlyManager
    function decreasePoolAmounts(uint256 _assetId, uint256 _amount) public {
        require(
            tokenPoolAmounts[_assetId] >= _amount,
            "L3Vault: Not enough token pool _amount"
        );
        tokenPoolAmounts[_assetId] -= _amount;
    }

    function increaseReserveAmounts(
        uint256 _assetId,
        uint256 _amount
    ) external {
        require(
            tokenPoolAmounts[_assetId] >=
                tokenReserveAmounts[_assetId] + _amount,
            "L3Vault: Not enough token pool amount"
        );
        tokenReserveAmounts[_assetId] += _amount;
    }

    function decreaseReserveAmounts(
        uint256 _assetId,
        uint256 _amount
    ) external {
        require(
            tokenReserveAmounts[_assetId] >= _amount,
            "L3Vault: Not enough token reserve amount"
        );
        tokenReserveAmounts[_assetId] -= _amount;
    }

    /**
     * @notice to be deprecated
     */
    function addLiquidityWithTokensTransfer(
        uint256 assetId,
        uint256 amount
    ) external payable {
        require(msg.value >= amount, "L3Vault: insufficient amount");
        // TODO: check - how to mint the LP token?
        tokenPoolAmounts[assetId] += amount;
        if (msg.value > amount) {
            payable(msg.sender).transfer(msg.value - amount);
        } // refund
    }

    /**
     * @notice to be deprecated
     */
    function removeLiquidityWithTokensTransfer(
        uint256 _assetId,
        uint256 _amount
    ) external {
        tokenPoolAmounts[_assetId] -= _amount;
        payable(msg.sender).transfer(_amount);
    }

    // TODO: check how to determine the Liquidity Provider
    function addLiquidity(uint256 _assetId, uint256 _amount) external {
        increasePoolAmounts(_assetId, _amount);
    }

    function removeLiquidity(uint256 _assetId, uint256 _amount) external {
        decreasePoolAmounts(_assetId, _amount);
    }
}
