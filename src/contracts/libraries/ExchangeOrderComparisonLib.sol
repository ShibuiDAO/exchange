pragma solidity ^0.8.11;
pragma abicoder v2;

import {IERC721PutExchange} from "../interfaces/IERC721PutExchange.sol";

library ExchangeOrderComparisonLib {
	/// @notice Compares 2 SellOrder instances to determine if they have the same parameters.
	/// @param _left SellOrder instance to be compared on the left side of the operator.
	/// @param _right SellOrder instance to be compared on the right side of the operator.
	/// @return A boolean value indication if the 2 SellOrder instances match.
	function compareSellOrders(IERC721PutExchange.SellOrder memory _left, IERC721PutExchange.SellOrder memory _right) internal pure returns (bool) {
		return (_left.expiration == _right.expiration) && (_left.price == _right.price);
	}
}
