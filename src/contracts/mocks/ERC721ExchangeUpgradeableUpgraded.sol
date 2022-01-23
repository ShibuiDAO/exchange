// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.6;
pragma abicoder v2;

import {ERC721ExchangeUpgradeable} from "../ERC721ExchangeUpgradeable.sol";

contract ERC721ExchangeUpgradeableUpgraded is ERC721ExchangeUpgradeable {
	/*///////////////////////////////////////////////////////////////
                        INFORMATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @return The current exchange version.
	function version() external pure virtual override returns (bytes memory) {
		uint256 major = 1;
		uint256 minor = 0;
		uint256 patch = 4;
		return abi.encode(major, minor, patch);
	}
}
