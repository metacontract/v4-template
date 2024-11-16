// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolIdLibrary} from "v4-core/src/types/PoolId.sol";

import {Storage} from "bundle/counter/storage/Storage.sol";

contract AfterSwap {

    function afterSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata)
        external
        returns (bytes4, int128)
    {
        Storage.CounterState().afterSwapCount++;
        return (this.afterSwap.selector, 0);
    }
}
