// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.9;
pragma abicoder v2;

import {ERC721ExchangeUpgradeable} from "../ERC721ExchangeUpgradeable.sol";

import {IERC721Exchange} from "../interfaces/IERC721Exchange.sol";

contract ERC721ExchangeUpgradeableUpgraded is ERC721ExchangeUpgradeable {
	/*///////////////////////////////////////////////////////////////
                        INFORMATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @inheritdoc IERC721Exchange
	function version() public pure virtual override returns (uint256) {
		return super.version() + 1;
	}
}
