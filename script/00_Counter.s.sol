// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";

import {Constants} from "./base/Constants.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";

import {MCScript} from "@mc-devkit/MCScript.sol";
import {Proxy as UCSProxy} from "@ucs.mc/proxy/Proxy.sol";

import {Base} from "bundle/Counter/functions/Base.sol";
import {AfterSwap} from "bundle/Counter/functions/AfterSwap.sol";
import {BeforeAddLiquidity} from "bundle/Counter/functions/BeforeAddLiquidity.sol";
import {BeforeRemoveLiquidity} from "bundle/Counter/functions/BeforeRemoveLiquidity.sol";
import {BeforeSwap} from "bundle/Counter/functions/BeforeSwap.sol";
import {CounterFacade} from "bundle/Counter/CounterFacade.sol";

/// @notice Mines the address and deploys the Counter.sol Hook contract
contract CounterScript is MCScript, Constants {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        mc.init("Counter");
        Base base = new Base();
        mc.use("getHookPermissions", Base.getHookPermissions.selector, address(base));
        mc.use("validateHookAddress", Base.validateHookAddress.selector, address(base));
        mc.use("AfterSwap", AfterSwap.afterSwap.selector, address(new AfterSwap()));
        mc.use("BeforeAddLiquidity", BeforeAddLiquidity.beforeAddLiquidity.selector, address(new BeforeAddLiquidity()));
        mc.use("BeforeRemoveLiquidity", BeforeRemoveLiquidity.beforeRemoveLiquidity.selector, address(new BeforeRemoveLiquidity()));
        mc.use("BeforeSwap", BeforeSwap.beforeSwap.selector, address(new BeforeSwap()));
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
            HookMiner.find(CREATE2_DEPLOYER, permissions, type(UCSProxy).creationCode, abi.encode(dictionaryAddress, initializeArgs));

        // ----------------------------- //
        // Deploy the hook using CREATE2 //
        // ----------------------------- //
        UCSProxy counter = new UCSProxy{salt: salt}(dictionaryAddress, initializeArgs);
        require(address(counter) == hookAddress, "CounterScript: hook address mismatch");

        vm.stopBroadcast();
    }
}
