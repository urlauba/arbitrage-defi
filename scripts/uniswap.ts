import { ethers } from 'ethers'
import { FACTORY_ADDRESS, Pool } from '@uniswap/v3-sdk'
import { Token } from '@uniswap/sdk-core'
import { abi as IUniswapv3PoolABI } from '@uniswap/v3-core/artifacts/contracts/interfaces/IUniswapV3Pool.sol/IUniswapV3Pool.json'
import { abi as IUniswapV3Factory } from '@uniswap/v3-core/artifacts/contracts/interfaces/IUniswapV3Factory.sol/IUniswapV3Factory.json'
import dotenv from 'dotenv'

dotenv.config()

const provider = new ethers.providers.JsonRpcProvider(process.env.ETHEREUM_NODE_URL)

const poolAddress = '0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8' // USDC over WETH
const poolContract = new ethers.Contract(poolAddress, IUniswapv3PoolABI, provider)

const daiAddress = '0x6b175474e89094c44da98b954eedeac495271d0f'
const usdcAddress = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'
const wethAddress = '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2'
const factoryContract = new ethers.Contract(FACTORY_ADDRESS, IUniswapV3Factory, provider)

interface Immutables {
    factory: string
    token0: string
    token1: string
    fee: number
    tickSpacing: number
    maxLiquidityPerTick: ethers.BigNumber
}

interface State {
    liquidity: ethers.BigNumber
    sqrtPriceX96: ethers.BigNumber
    tick: number
    observationIndex: number
    observationCardinality: number
    observationCardinalityNext: number
    feeProtocol: number
    unlocked: boolean
}

async function getPoolImmutables() {
    const [factory, token0, token1, fee, tickSpacing, maxLiquidityPerTick] = await Promise.all([
        poolContract.factory(),
        poolContract.token0(),
        poolContract.token1(),
        poolContract.fee(),
        poolContract.tickSpacing(),
        poolContract.maxLiquidityPerTick(),
    ])

    const immutables: Immutables = {
        factory,
        token0,
        token1,
        fee,
        tickSpacing,
        maxLiquidityPerTick,
    }

    return immutables
}

async function getPoolState() {
    const [liquidity, slot] = await Promise.all([poolContract.liquidity(), poolContract.slot0()])

    const PoolState: State = {
        liquidity,
        sqrtPriceX96: slot[0],
        tick: slot[1],
        observationIndex: slot[2],
        observationCardinality: slot[3],
        observationCardinalityNext: slot[4],
        feeProtocol: slot[5],
        unlocked: slot[6],
    }

    return PoolState
}

async function main() {
    const [immutables, state] = await Promise.all([getPoolImmutables(), getPoolState()])

    const TokenA = new Token(3, immutables.token0, 6, 'USDC', 'USD Coin')
    const TokenB = new Token(3, immutables.token1, 18, 'WETH', 'Wrapped Ether')

    const pool = new Pool(
        TokenA,
        TokenB,
        immutables.fee,
        state.sqrtPriceX96.toString(),
        state.liquidity.toString(),
        state.tick
        // (optional) tick data - can be used to model the result of a swap
    )

    const token0Price = pool.token0Price
    const token1Price = pool.token1Price

    // token0 is USDC
    // 1 USDC = 0.00062 WETH
    // token0 significant price is 0.00061866
    // if I want 1 of token0(USDC), I need 0.00061866 of token1(WETH)
    console.log(token0Price.toSignificant(6))

    // token1 is WETH
    // 1 WETH = 1,616.77 USDC
    // token1 significant price is 1617.69
    // if I want 1 of token1(WETH), I need 1617.69 of token0(USDC)
    console.log(token1Price.toSignificant(6))

    const poolDAIUSDC = await factoryContract.getPool(
        daiAddress,
        usdcAddress,
        3000
    )

    // 0xa63b490aA077f541c9d64bFc1Cc0db2a752157b5 DAI, USDC
    // 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8 USDC, WETH (matches above)
    console.log(poolDAIUSDC)
}

main()
