// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

import {IERC721Exchange} from "../interfaces/IERC721Exchange.sol";

/// @author ShibuiDAO
library ExchangeOrderComparisonLib {
	/// @notice Compares 2 SellOrder instances to determine if they have the same parameters.
	/// @param _left SellOrder instance to be compared on the left side of the operator.
	/// @param _right SellOrder instance to be compared on the right side of the operator.
	/// @return A boolean value indication if the 2 SellOrder instances match.
	function compareSellOrders(IERC721Exchange.SellOrder memory _left, IERC721Exchange.SellOrder memory _right) internal pure returns (bool) {
		return keccak256(abi.encode(_left)) == keccak256(abi.encode(_right));
	}

	/// @return A boolean value indication if the stored SellOrder instance and found encoded data match.
	function compareStoredSellOrders(IERC721Exchange.SellOrder memory passed, bytes memory stored) internal pure returns (bool) {
		return keccak256(stored) == keccak256(abi.encode(passed));
	}

	/// @notice Compares 2 BuyOrder instances to determine if they have the same parameters.
	/// @param _left BuyOrder instance to compared on the left side of the operator.
	/// @param _right BuyOrder instance to be compared on the right side of the operator.
	/// @return A boolean value indication if the 2 BuyOrder instances match.
	function compareBuyOrders(IERC721Exchange.BuyOrder memory _left, IERC721Exchange.BuyOrder memory _right) internal pure returns (bool) {
		return keccak256(abi.encode(_left)) == keccak256(abi.encode(_right));
	}

	/// @return A boolean value indication if the stored BuyOrder instance and found encoded data match.
	function compareStoredBuyOrders(IERC721Exchange.BuyOrder memory passed, bytes memory stored) internal pure returns (bool) {
		return keccak256(stored) == keccak256(abi.encode(passed));
	}
}
