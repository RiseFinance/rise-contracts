// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

contract RisePool {
    mapping(uint256 => uint256) private longPoolAmounts; // marketId => tokenCount
    mapping(uint256 => uint256) private shortPoolAmounts; // marketId => tokenCount

    mapping(uint256 => uint256) private longReserveAmounts; // marketId => tokenCount
    mapping(uint256 => uint256) private shortReserveAmounts; // marketId => tokenCount

    // function getPoolAmount(
    //     uint256 _marketId,
    //     bool _isLong
    // ) external view returns (uint256) {
    //     return
    //         _isLong ? longPoolAmounts[_marketId] : shortPoolAmounts[_marketId];
    // }

    /// getters

    function getLongPoolAmount(
        uint256 _marketId
    ) external view returns (uint256) {
        return longPoolAmounts[_marketId];
    }

    function getShortPoolAmount(
        uint256 _marketId
    ) external view returns (uint256) {
        return shortPoolAmounts[_marketId];
    }

    function getLongReserveAmount(
        uint256 _marketId
    ) external view returns (uint256) {
        return longReserveAmounts[_marketId];
    }

    function getShortReserveAmount(
        uint256 _marketId
    ) external view returns (uint256) {
        return shortReserveAmounts[_marketId];
    }

    /// @dev for liquidity removal & OI capacity check
    function getLongPoolCapacity(
        uint256 _marketId
    ) external view returns (uint256) {
        return longPoolAmounts[_marketId] - longReserveAmounts[_marketId];
    }

    /// @dev for liquidity removal & OI capacity check
    function getShortPoolCapacity(
        uint256 _marketId
    ) external view returns (uint256) {
        return shortPoolAmounts[_marketId] - shortReserveAmounts[_marketId];
    }

    /// setters
    // TODO: onlyManager for the following functions
    function increaseLongPoolAmount(uint256 _marketId, uint256 _amount) public {
        longPoolAmounts[_marketId] += _amount;
    }

    function increaseShortPoolAmount(
        uint256 _marketId,
        uint256 _amount
    ) public {
        shortPoolAmounts[_marketId] += _amount;
    }

    function decreaseLongPoolAmount(uint256 _marketId, uint256 _amount) public {
        require(
            longPoolAmounts[_marketId] >= _amount,
            "RisePool: Not enough token pool _amount"
        );
        longPoolAmounts[_marketId] -= _amount;
    }

    function decreaseShortPoolAmount(
        uint256 _marketId,
        uint256 _amount
    ) public {
        require(
            shortPoolAmounts[_marketId] >= _amount,
            "RisePool: Not enough token pool _amount"
        );
        shortPoolAmounts[_marketId] -= _amount;
    }

    function increaseLongReserveAmount(
        uint256 _marketId,
        uint256 _amount
    ) public {
        require(
            longPoolAmounts[_marketId] >=
                longReserveAmounts[_marketId] + _amount,
            "RisePool: Not enough token pool amount"
        );
        longReserveAmounts[_marketId] += _amount;
    }

    function increaseShortReserveAmount(
        uint256 _marketId,
        uint256 _amount
    ) public {
        require(
            shortPoolAmounts[_marketId] >=
                shortReserveAmounts[_marketId] + _amount,
            "RisePool: Not enough token pool amount"
        );
        shortReserveAmounts[_marketId] += _amount;
    }

    function decreaseLongReserveAmount(
        uint256 _marketId,
        uint256 _amount
    ) public {
        require(
            longReserveAmounts[_marketId] >= _amount,
            "RisePool: Not enough token reserve amount"
        );
        longReserveAmounts[_marketId] -= _amount;
    }

    function decreaseShortReserveAmount(
        uint256 _marketId,
        uint256 _amount
    ) public {
        require(
            shortReserveAmounts[_marketId] >= _amount,
            "RisePool: Not enough token reserve amount"
        );
        shortReserveAmounts[_marketId] -= _amount;
    }

    // TODO: check how to determine the Liquidity Provider
    function addLiquidity(
        uint256 _marketId,
        bool _isLongReserve,
        uint256 _amount
    ) external {
        _isLongReserve
            ? increaseLongPoolAmount(_marketId, _amount)
            : increaseShortPoolAmount(_marketId, _amount);
    }

    function removeLiquidity(
        uint256 _marketId,
        bool _isLongReserve,
        uint256 _amount
    ) external {
        _isLongReserve
            ? decreaseLongPoolAmount(_marketId, _amount)
            : decreaseShortPoolAmount(_marketId, _amount);
    }
}
