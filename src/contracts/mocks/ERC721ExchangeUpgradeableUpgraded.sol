// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.2;
pragma abicoder v2;

import {ERC721ExchangeUpgradeable} from '../ERC721ExchangeUpgradeable.sol';

contract ERC721ExchangeUpgradeableUpgraded is ERC721ExchangeUpgradeable {
	/*///////////////////////////////////////////////////////////////
                        INFORMATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @return The current exchange version.
	function version() external pure override returns (string memory) {
		return 'v1.0.4';
	}
}
