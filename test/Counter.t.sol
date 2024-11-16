// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {Counter} from "../src/Counter.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";

import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {EasyPosm} from "./utils/EasyPosm.sol";
import {Fixtures} from "./utils/Fixtures.sol";

import {MCTest} from "@mc-devkit/MCTest.sol";
import {Proxy as UCSProxy} from "@ucs.mc/proxy/Proxy.sol";

import {Base} from "bundle/Counter/functions/Base.sol";
import {AfterSwap} from "bundle/Counter/functions/AfterSwap.sol";
import {BeforeAddLiquidity} from "bundle/Counter/functions/BeforeAddLiquidity.sol";
import {BeforeRemoveLiquidity} from "bundle/Counter/functions/BeforeRemoveLiquidity.sol";
import {BeforeSwap} from "bundle/Counter/functions/BeforeSwap.sol";
import {CounterFacade} from "bundle/Counter/CounterFacade.sol";
import {Reader} from "bundle/Counter/Reader.sol";

contract CounterTest is MCTest, Fixtures {
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    Reader hook;
    PoolId poolId;

    uint256 tokenId;
    int24 tickLower;
    int24 tickUpper;

    function setUp() public {
        // creates the pool manager, utility routers, and test tokens
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        deployAndApprovePosm(manager);

        hook = Reader(deployHook());

        // Create the pool
        key = PoolKey(currency0, currency1, 3000, 60, IHooks(address(hook)));
        poolId = key.toId();
        manager.initialize(key, SQRT_PRICE_1_1);

        // Provide full-range liquidity to the pool
        tickLower = TickMath.minUsableTick(key.tickSpacing);
        tickUpper = TickMath.maxUsableTick(key.tickSpacing);

        uint128 liquidityAmount = 100e18;

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        (tokenId,) = posm.mint(
            key,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            address(this),
            block.timestamp,
            ZERO_BYTES
        );
    }

    function testCounterHooks() public {
        // positions were created in setup()
        assertEq(hook.beforeAddLiquidityCount(), 1);
        assertEq(hook.beforeRemoveLiquidityCount(), 0);

        assertEq(hook.beforeSwapCount(), 0);
        assertEq(hook.afterSwapCount(), 0);

        // Perform a test swap //
        bool zeroForOne = true;
        int256 amountSpecified = -1e18; // negative number indicates exact input swap!
        BalanceDelta swapDelta = swap(key, zeroForOne, amountSpecified, ZERO_BYTES);
        // ------------------- //

        assertEq(int256(swapDelta.amount0()), amountSpecified);

        assertEq(hook.beforeSwapCount(), 1);
        assertEq(hook.afterSwapCount(), 1);
    }

    function testLiquidityHooks() public {
        // positions were created in setup()
        assertEq(hook.beforeAddLiquidityCount(), 1);
        assertEq(hook.beforeRemoveLiquidityCount(), 0);

        // remove liquidity
        uint256 liquidityToRemove = 1e18;
        posm.decreaseLiquidity(
            tokenId,
            liquidityToRemove,
            MAX_SLIPPAGE_REMOVE_LIQUIDITY,
            MAX_SLIPPAGE_REMOVE_LIQUIDITY,
            address(this),
            block.timestamp,
            ZERO_BYTES
        );

        assertEq(hook.beforeAddLiquidityCount(), 1);
        assertEq(hook.beforeRemoveLiquidityCount(), 1);
    }

        function deployHook() public returns (address) {
        mc.init("Counter");
        Base base = new Base();
        mc.use("getHookPermissions", Base.getHookPermissions.selector, address(base));
        mc.use("validateHookAddress", Base.validateHookAddress.selector, address(base));
        mc.use("AfterSwap", AfterSwap.afterSwap.selector, address(new AfterSwap()));
        mc.use("BeforeAddLiquidity", BeforeAddLiquidity.beforeAddLiquidity.selector, address(new BeforeAddLiquidity()));
        mc.use("BeforeRemoveLiquidity", BeforeRemoveLiquidity.beforeRemoveLiquidity.selector, address(new BeforeRemoveLiquidity()));
        mc.use("BeforeSwap", BeforeSwap.beforeSwap.selector, address(new BeforeSwap()));
        Reader reader = new Reader();
        mc.use("beforeSwapCount", Reader.beforeSwapCount.selector, address(reader));
        mc.use("afterSwapCount", Reader.afterSwapCount.selector, address(reader));
        mc.use("beforeAddLiquidityCount", Reader.beforeAddLiquidityCount.selector, address(reader));
        mc.use("beforeRemoveLiquidityCount", Reader.beforeRemoveLiquidityCount.selector, address(reader));
        mc.useFacade(address(new CounterFacade()));
        address dictionaryAddress = mc.deployDictionary().addr;
        
        // hook contracts must have specific flags encoded in the address
        uint160 permissions = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
        );

        bytes memory initializeArgs = abi.encodeWithSelector(Base.validateHookAddress.selector);
        
        // Mine a salt that will produce a hook address with the correct permissions
        (address hookAddress, bytes32 salt) =
            HookMiner.find(address(this), permissions, type(UCSProxy).creationCode, abi.encode(dictionaryAddress, initializeArgs));

        // ----------------------------- //
        // Deploy the hook using CREATE2 //
        // ----------------------------- //
        UCSProxy counter = new UCSProxy{salt: salt}(dictionaryAddress, initializeArgs);
        require(address(counter) == hookAddress, "CounterScript: hook address mismatch");
        return address(counter);
    }
    receive() external payable override(MCTest, Fixtures) {}
}
