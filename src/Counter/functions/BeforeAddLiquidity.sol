// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolIdLibrary} from "v4-core/src/types/PoolId.sol";

import {Storage} from "bundle/counter/storage/Storage.sol";

contract BeforeAddLiquidity {

    function beforeAddLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata, bytes calldata)
        external
        returns (bytes4)
    {
        Storage.CounterState().beforeAddLiquidityCount++;
        return this.beforeAddLiquidity.selector;
    }
}
