// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

import {IERC165} from "@shibuidao/solid/src/utils/interfaces/IERC165.sol";

/// @author ShibuiDAO
interface IOrderBook is IERC165 {
	event RawOrderBook(uint256 indexed dataStructureId, bytes indexed orderKey, bytes indexed order);
	event RawOrderCancel(uint256 indexed dataStructureId, bytes indexed orderKey);

	// solhint-disable-next-line func-name-mixedcase
	function __OrderBook_init() external;

	function fetchOrder(uint256 _dataStructureId, bytes calldata _orderKey) external view returns (bytes memory order);

	function bookOrder(
		uint256 _dataStructureId,
		bytes calldata _orderKey,
		bytes calldata _order
	) external;

	function cancelOrder(uint256 _dataStructureId, bytes calldata _orderKey) external;
}
