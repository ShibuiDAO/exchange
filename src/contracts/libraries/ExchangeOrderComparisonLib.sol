pragma solidity ^0.8.11;
pragma abicoder v2;

import {IERC721Exchange} from "../interfaces/IERC721Exchange.sol";

library ExchangeOrderComparisonLib {
	/// @notice Compares 2 SellOrder instances to determine if they have the same parameters.
	/// @param _left SellOrder instance to be compared on the left side of the operator.
	/// @param _right SellOrder instance to be compared on the right side of the operator.
	/// @return A boolean value indication if the 2 SellOrder instances match.
	function compareSellOrders(IERC721Exchange.SellOrder memory _left, IERC721Exchange.SellOrder memory _right) internal pure returns (bool) {
		return (_left.expiration == _right.expiration) && (_left.price == _right.price);
	}

	function compareStoredSellOrders(IERC721Exchange.SellOrder memory passed, bytes memory stored) internal pure returns (bool) {
		return keccak256(stored) == keccak256(abi.encode(passed));
	}

	/// @notice Compares 2 BuyOrder instances to determine if they have the same parameters.
	/// @param _left BuyOrder instance to compared on the left side of the operator.
	/// @param _right BuyOrder instance to be compared on the right side of the operator.
	/// @return A boolean value indication if the 2 BuyOrder instances match.
	function compareBuyOrders(IERC721Exchange.BuyOrder memory _left, IERC721Exchange.BuyOrder memory _right) internal pure returns (bool) {
		return (_left.owner == _right.owner) && (_left.expiration == _right.expiration) && (_left.offer == _right.offer);
	}

	function compareStoredBuyOrders(IERC721Exchange.BuyOrder memory passed, bytes memory stored) internal pure returns (bool) {
		return keccak256(stored) == keccak256(abi.encode(passed));
	}
}
