// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Storage} from "bundle/counter/storage/Storage.sol";

contract Reader {
    function beforeSwapCount() external view returns (uint256) {
        return Storage.CounterState().beforeSwapCount;
    }

    function afterSwapCount() external view returns (uint256) {
        return Storage.CounterState().afterSwapCount;
    }

    function beforeAddLiquidityCount() external view returns (uint256) {
        return Storage.CounterState().beforeAddLiquidityCount;
    }

    function beforeRemoveLiquidityCount() external view returns (uint256) {
        return Storage.CounterState().beforeRemoveLiquidityCount;
    }
}