// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.17;

import "forge-std/Test.sol";

import "@openzeppelin/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

import "../src/Arbitrage.sol";
import "../src/Tokens.sol";

contract ArbitrageTest is Test {
    Arbitrage private _arbitrage;

    function setUp() public {
        _arbitrage = new Arbitrage();
    }

    function testSwap() public {
        _arbitrage.swap();
    }
}
