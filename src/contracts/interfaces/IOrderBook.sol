// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

import {IERC165} from "@shibuidao/solid/src/utils/interfaces/IERC165.sol";

/// @author ShibuiDAO (https://github.com/ShibuiDAO/exchange/blob/main/src/contracts/interfaces/IOrderBook.sol)
interface IOrderBook is IERC165 {
	////////////////////////////////////
	///            EVENTS            ///
	////////////////////////////////////

	/// @notice Emitted when `bookOrder` is called.
	/// @param dataStructureId ID of the structure getting manipulated.
	/// @param orderKey The key of the order getting booked.
	/// @param order The data of the saved order.
	event RawOrderBook(uint256 indexed dataStructureId, bytes indexed orderKey, bytes indexed order);

	/// @notice Emitted when `cancelOrder` is called.
	/// @param dataStructureId ID of the structure getting manipulated.
	/// @param orderKey The key of the order getting canceled/deleted.
	event RawOrderCancel(uint256 indexed dataStructureId, bytes indexed orderKey);

	//////////////////////////////////////////////////////////////////////////////////////////////////
	///                    UPGRADEABLE CONTRACT INITIALIZER/CONTRUCTOR FUNCTION                    ///
	//////////////////////////////////////////////////////////////////////////////////////////////////

	// solhint-disable-next-line func-name-mixedcase
	function __OrderBook_init() external;

	//////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                        CORE ORDER FUNCTIONS                                        ///
	//////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice Fetches/gets a specific order.
	/// @param _dataStructureId ID of the structure being fetched.
	/// @param _orderKey The key of the fetched order.
	/// @return order Raw order data in the form of bytes.
	function fetchOrder(uint256 _dataStructureId, bytes calldata _orderKey) external view returns (bytes memory order);

	/// @notice Books/saves/sets a specific order.
	/// @param _dataStructureId ID of the structure getting manipulated.
	/// @param _orderKey The key of the order getting booked.
	/// @param _order The data of the saved order.
	function bookOrder(
		uint256 _dataStructureId,
		bytes calldata _orderKey,
		bytes calldata _order
	) external;

	/// @notice Cancels/deletes a specific order.
	/// @param _dataStructureId ID of the structure getting manipulated.
	/// @param _orderKey The key of the order getting deleted.
	function cancelOrder(uint256 _dataStructureId, bytes calldata _orderKey) external;
}
