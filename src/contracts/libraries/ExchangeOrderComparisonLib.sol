pragma solidity ^0.8.11;
pragma abicoder v2;

import {IExchange} from "../interfaces/IExchange.sol";

library ExchangeOrderComparisonLib {
	/// @notice Hashes and compares 2 SellOrder instances to determine if they have the same parameters.
	/// @param _left SellOrder instance to be hashed and compared on the left side of the operator.
	/// @param _right SellOrder instance to be hashed and compared on the right side of the operator.
	/// @return A boolean value indication if the 2 SellOrder instances match.
	function compareSellOrders(IExchange.SellOrder memory _left, IExchange.SellOrder memory _right) internal pure returns (bool) {
		return keccak256(abi.encode(_left)) == keccak256(abi.encode(_right));
	}

	/// @notice Hashes and compares 2 BuyOrder instances to determine if they have the same parameters.
	/// @param _left BuyOrder instance to be hashed and compared on the left side of the operator.
	/// @param _right BuyOrder instance to be hashed and compared on the right side of the operator.
	/// @return A boolean value indication if the 2 BuyOrder instances match.
	function compareBuyOrders(IExchange.BuyOrder memory _left, IExchange.BuyOrder memory _right) internal pure returns (bool) {
		return keccak256(abi.encode(_left)) == keccak256(abi.encode(_right));
	}
}
