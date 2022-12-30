// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.17;

import "forge-std/console.sol";

import "@openzeppelin/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import "@sushiswap/protocols/sushiswap/contracts/interfaces/IUniswapV2Router02.sol";
import "@sushiswap/protocols/sushiswap/contracts/libraries/UniswapV2Library.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3FlashCallback.sol";
import "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";

import "./Tokens.sol";

address constant uniswapV3Factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
address constant sushiSwapV2Factory = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
address constant sushiSwapRouter = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;

contract Arbitrage is IUniswapV3FlashCallback {

    // costs = loan_fee + swap_fee_one + swap_fee_two + gas

    // DAI/USDC on A is 10
    // DAI/USDC on B is 11
    // 1. Borrow X DAI/USDC -> ex. 100 DAI
    // 2. Sell X DAI/USDC on B -> ex. 1100 USDC
    // 3. Buy X "   " on A -> ex. 100 DAI and 100 USDC
    // 4. Payback loan
    function swap() external {
        console.log("hi");

        FlashParams memory params = FlashParams({
            token0: uni,
            token1: dai,
            fee1: 500,
            amount0: 10,
            amount1: 0,
            fee2: 0,
            fee3: 0
        });
        this.initFlash(params);

        console.log("bye");

        console.log(IERC20(uni).balanceOf(address(this)));
        console.log(IERC20(dai).balanceOf(address(this)));
    }

        // fee2 and fee3 are the two other fees associated with the two other pools of token0 and token1
    struct FlashCallbackData {
        uint256 amount0;
        uint256 amount1;
        address payer;
        PoolAddress.PoolKey poolKey;
        uint24 poolFee2;
        uint24 poolFee3;
    }

    /// @param fee0 The fee from calling flash for token0
    /// @param fee1 The fee from calling flash for token1
    /// @param data The data needed in the callback passed as FlashCallbackData from `initFlash`
    /// @notice implements the callback called from flash
    /// @dev fails if the flash is not profitable, meaning the amountOut from the flash is less than the amount borrowed
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external override {
        console.log("callback!");

        address[] memory path = new address[](2);
        path[0] = uni;
        path[1] = dai;

        console.log(IERC20(uni).balanceOf(address(this)));
        console.log(IERC20(dai).balanceOf(address(this)));

        IUniswapV2Router02 sushiRouter = IUniswapV2Router02(sushiSwapRouter);
        IERC20(uni).approve(address(sushiRouter), 1);

        uint256 amountRequired = UniswapV2Library.getAmountsIn(
            sushiSwapV2Factory,
            1,
            path
        )[0];

        console.log(amountRequired);

        // INSUFFICIENT_OUTPUT_AMOUNT
        // TRANSFER_FROM_FAILED
        sushiRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            1,
            0,//amountRequired, // need to know conversion
            path,
            address(this),
            block.timestamp + 10 days // need to change
        );

        console.log(IERC20(uni).balanceOf(address(this)));
        console.log(IERC20(dai).balanceOf(address(this)));
    }

    //fee1 is the fee of the pool from the initial borrow
    //fee2 is the fee of the first pool to arb from
    //fee3 is the fee of the second pool to arb from
    struct FlashParams {
        address token0;
        address token1;
        uint24 fee1;
        uint256 amount0;
        uint256 amount1;
        uint24 fee2;
        uint24 fee3;
    }

    /// @param params The parameters necessary for flash and the callback, passed in as FlashParams
    /// @notice Calls the pools flash function with data needed in `uniswapV3FlashCallback`
    function initFlash(FlashParams memory params) external {
        PoolAddress.PoolKey memory poolKey =
            PoolAddress.PoolKey({token0: params.token0, token1: params.token1, fee: params.fee1});
        IUniswapV3Pool pool = IUniswapV3Pool(PoolAddress.computeAddress(uniswapV3Factory, poolKey));
        // recipient of borrowed amounts
        // amount of token0 requested to borrow
        // amount of token1 requested to borrow
        // need amount 0 and amount1 in callback to pay back pool
        // recipient of flash should be THIS contract
        pool.flash(
            address(this),
            params.amount0,
            params.amount1,
            abi.encode(
                FlashCallbackData({
                    amount0: params.amount0,
                    amount1: params.amount1,
                    payer: msg.sender,
                    poolKey: poolKey,
                    poolFee2: params.fee2,
                    poolFee3: params.fee3
                })
            )
        );
    }

}