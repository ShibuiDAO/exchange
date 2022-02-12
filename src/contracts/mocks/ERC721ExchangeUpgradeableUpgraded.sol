// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.11;
pragma abicoder v2;

import {ERC721ExchangeUpgradeable} from "../ERC721ExchangeUpgradeable.sol";

contract ERC721ExchangeUpgradeableUpgraded is ERC721ExchangeUpgradeable {
	/*///////////////////////////////////////////////////////////////
                        INFORMATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @return The current exchange version.
	function version() public pure virtual override returns (uint256) {
		return super.version() + 1;
	}
}
