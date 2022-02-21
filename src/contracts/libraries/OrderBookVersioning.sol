// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

/// @notice Library with constants of Order structure IDs/versions.
/// @author ShibuiDAO (https://github.com/ShibuiDAO/exchange/blob/main/src/contracts/libraries/OrderBookVersioning.sol)
library OrderBookVersioning {
	/// @notice Structure ID of the first revision of the ERC721-ERC20 SellOrder.
	uint256 public constant SELL_ORDER_INITIAL = 1;

	/// @notice Structure ID of the first revision of the ERC721-ERC20 BuyOrder.
	uint256 public constant BUY_ORDER_INITIAL = 2;
}
