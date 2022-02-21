// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.9;
pragma abicoder v2;

import {ERC165} from "@shibuidao/solid/src/utils/ERC165.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IERC165} from "@shibuidao/solid/src/utils/interfaces/IERC165.sol";
import {IOrderBook} from "./interfaces/IOrderBook.sol";

/// @title Shibui 🌊 Shared Order Book
/// @author ShibuiDAO (https://github.com/ShibuiDAO/exchange/blob/main/src/contracts/OrderBookUpgradeable.sol)
contract OrderBookUpgradeable is ERC165, Initializable, ContextUpgradeable, OwnableUpgradeable, IOrderBook {
	//////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                        ORDER KEEPER STORAGE                                        ///
	//////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice Stores allowed order keepers.
	mapping(address => bool) public orderKeepers;

	///////////////////////////////////////////////////////////////////////
	///                          ORDER STORAGE                          ///
	///////////////////////////////////////////////////////////////////////

	/// @notice Maps a structure ID to bytes acting as a key to bytes acting as data.
	mapping(uint256 => mapping(bytes => bytes)) public orders;

	//////////////////////////////////////////////////////////////////////////////////////////////////
	///                    UPGRADEABLE CONTRACT INITIALIZER/CONTRUCTOR FUNCTION                    ///
	//////////////////////////////////////////////////////////////////////////////////////////////////

	/// @dev Never called.
	/// @custom:oz-upgrades-unsafe-allow constructor
	// solhint-disable-next-line no-empty-blocks
	constructor() initializer {}

	/// @inheritdoc IOrderBook
	// solhint-disable-next-line func-name-mixedcase
	function __OrderBook_init() public override initializer {
		__Context_init();
		__Ownable_init();
	}

	/////////////////////////////////////////////////////////////////////////////////
	///                              ERC165 FUNCTION                              ///
	/////////////////////////////////////////////////////////////////////////////////

	/// @inheritdoc IERC165
	function supportsInterface(bytes4 interfaceId) public pure virtual override(ERC165, IERC165) returns (bool) {
		return interfaceId == type(IOrderBook).interfaceId || super.supportsInterface(interfaceId);
	}

	//////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                        CORE ORDER FUNCTIONS                                        ///
	//////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice Fetches/gets a specific order.
	/// @param _dataStructureId ID of the structure being fetched.
	/// @param _orderKey The key of the fetched order.
	/// @return order Raw order data in the form of bytes.
	/// @inheritdoc IOrderBook
	function fetchOrder(uint256 _dataStructureId, bytes calldata _orderKey) external view override returns (bytes memory order) {
		return orders[_dataStructureId][_orderKey];
	}

	/// @notice Books/saves/sets a specific order.
	/// @param _dataStructureId ID of the structure getting manipulated.
	/// @param _orderKey The key of the order getting booked.
	/// @param _order The data of the saved order.
	/// @inheritdoc IOrderBook
	function bookOrder(
		uint256 _dataStructureId,
		bytes calldata _orderKey,
		bytes calldata _order
	) external override onlyOrderKeeper {
		emit RawOrderBook(_dataStructureId, _orderKey, _order);
		orders[_dataStructureId][_orderKey] = _order;
	}

	/// @notice Cancels/deletes a specific order.
	/// @param _dataStructureId ID of the structure getting manipulated.
	/// @param _orderKey The key of the order getting canceled/deleted.
	/// @inheritdoc IOrderBook
	function cancelOrder(uint256 _dataStructureId, bytes calldata _orderKey) external override onlyOrderKeeper {
		emit RawOrderCancel(_dataStructureId, _orderKey);
		delete orders[_dataStructureId][_orderKey];
	}

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                            ORDER KEEPER MODIFIERS                                            ///
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice Throws if the caller is a not a registered order keeper.
	modifier onlyOrderKeeper() {
		require(orderKeepers[msg.sender], "CALLER_NOT_KEEPER");
		_;
	}

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                            ORDER KEEPER FUNCTIONS                                            ///
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice Adds a new order keeper.
	/// @param _keeperAddress Address of the order keeper to add.
	function addOrderKeeper(address _keeperAddress) public onlyOwner {
		orderKeepers[_keeperAddress] = true;
	}

	/// @notice Removes a order keeper.
	/// @param _keeperAddress Address of the order keeper to remove.
	function cancelOrderKeeper(address _keeperAddress) public onlyOwner {
		orderKeepers[_keeperAddress] = false;
	}
}
