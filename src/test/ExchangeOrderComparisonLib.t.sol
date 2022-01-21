pragma solidity ^0.8.2;

import "ds-test/test.sol";

import {IExchange} from "../contracts/interfaces/IExchange.sol";
import {ExchangeOrderComparisonLib} from "../contracts/libraries/ExchangeOrderComparisonLib.sol";

contract ExchangeOrderComparisonLibTest is DSTest {
	function proveSellOrderComparison(uint256 l_expiration, uint256 l_price) public {
		assertTrue(
			ExchangeOrderComparisonLib.compareSellOrders(IExchange.SellOrder(l_expiration, l_price), IExchange.SellOrder(l_expiration, l_price))
		);
	}

	function testFailWrongSellOrderComparison(
		uint256 l_expiration,
		uint256 l_price,
		uint256 r_expiration,
		uint256 r_price
	) public {
		assertTrue(
			ExchangeOrderComparisonLib.compareSellOrders(IExchange.SellOrder(l_expiration, l_price), IExchange.SellOrder(r_expiration, r_price))
		);
	}
}
