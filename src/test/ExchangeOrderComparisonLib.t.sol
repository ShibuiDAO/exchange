pragma solidity ^0.8.11;

import {BaseTest} from "./base/BaseTest.sol";

import {IERC721Exchange} from "../contracts/interfaces/IERC721Exchange.sol";
import {ExchangeOrderComparisonLib} from "../contracts/libraries/ExchangeOrderComparisonLib.sol";

contract ExchangeOrderComparisonLibTest is BaseTest {
	function proveSellOrderComparison(uint256 l_expiration, uint256 l_price) public {
		assertTrue(
			ExchangeOrderComparisonLib.compareSellOrders(IERC721Exchange.SellOrder(l_expiration, l_price), IERC721Exchange.SellOrder(l_expiration, l_price))
		);
	}

	function testFailWrongSellOrderComparison(
		uint256 l_expiration,
		uint256 l_price,
		uint256 r_expiration,
		uint256 r_price
	) public {
		assertTrue(
			ExchangeOrderComparisonLib.compareSellOrders(IERC721Exchange.SellOrder(l_expiration, l_price), IERC721Exchange.SellOrder(r_expiration, r_price))
		);
	}
}
