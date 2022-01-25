pragma solidity ^0.8.11;
pragma abicoder v2;

import {IExchange} from "../interfaces/IExchange.sol";

library ExchangeOrderComparisonLib {
	/// @notice Compares 2 SellOrder instances to determine if they have the same parameters.
	/// @param _left SellOrder instance to be compared on the left side of the operator.
	/// @param _right SellOrder instance to be compared on the right side of the operator.
	/// @return A boolean value indication if the 2 SellOrder instances match.
	function compareSellOrders(IExchange.SellOrder memory _left, IExchange.SellOrder memory _right) internal pure returns (bool) {
		return (_left.expiration == _right.expiration) && (_left.price == _right.price);
	}

	/// @notice Compares 2 BuyOrder instances to determine if they have the same parameters.
	/// @param _left BuyOrder instance to compared on the left side of the operator.
	/// @param _right BuyOrder instance to be compared on the right side of the operator.
	/// @return A boolean value indication if the 2 BuyOrder instances match.
	function compareBuyOrders(IExchange.BuyOrder memory _left, IExchange.BuyOrder memory _right) internal pure returns (bool) {
		return (_left.owner == _right.owner) && (_left.expiration == _right.expiration) && (_left.offer == _right.offer);
	}
}
