// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.11;
pragma abicoder v2;

import {ERC165} from "@shibuidao/solid/src/utils/ERC165.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IERC165} from "@shibuidao/solid/src/utils/interfaces/IERC165.sol";
import {IOrderBook} from "./interfaces/IOrderBook.sol";

/// @author ShibuiDAO
contract OrderBookUpgradeable is ERC165, Initializable, ContextUpgradeable, OwnableUpgradeable, IOrderBook {
	mapping(address => bool) public orderKeepers;

	mapping(uint256 => mapping(bytes => bytes)) public orders;

	// solhint-disable-next-line no-empty-blocks
	constructor() initializer {}

	/// @inheritdoc IOrderBook
	// solhint-disable-next-line func-name-mixedcase
	function __OrderBook_init() public override initializer {
		__Context_init();
		__Ownable_init();
	}

	/// @inheritdoc IERC165
	function supportsInterface(bytes4 interfaceId) public pure virtual override(ERC165, IERC165) returns (bool) {
		return interfaceId == type(IOrderBook).interfaceId || super.supportsInterface(interfaceId);
	}

	/// @inheritdoc IOrderBook
	function fetchOrder(uint256 _dataStructureId, bytes calldata _orderKey) external view override returns (bytes memory order) {
		return orders[_dataStructureId][_orderKey];
	}

	/// @inheritdoc IOrderBook
	function bookOrder(
		uint256 _dataStructureId,
		bytes calldata _orderKey,
		bytes calldata _order
	) external override onlyOrderKeeper {
		orders[_dataStructureId][_orderKey] = _order;
	}

	/// @inheritdoc IOrderBook
	function removeOrder(uint256 _dataStructureId, bytes calldata _orderKey) external override onlyOrderKeeper {
		delete orders[_dataStructureId][_orderKey];
	}

	modifier onlyOrderKeeper() {
		require(orderKeepers[msg.sender], "Invalid Caller Address");
		_;
	}

	function addOrderKeeper(address _keeperAddress) public onlyOwner {
		orderKeepers[_keeperAddress] = true;
	}

	function removeOrderKeeper(address _keeperAddress) public onlyOwner {
		orderKeepers[_keeperAddress] = false;
	}
}
