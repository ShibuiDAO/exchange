// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.11;
pragma abicoder v2;

import {ERC165} from "@shibuidao/solid/src/utils/ERC165.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {SafeTransferLib} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import {ExchangeOrderComparisonLib} from "./libraries/ExchangeOrderComparisonLib.sol";

import {IERC721PutExchange} from "./interfaces/IERC721PutExchange.sol";
import {IERC165} from "@shibuidao/solid/src/utils/interfaces/IERC165.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @dev Handles the creation and execution of sell orders as well as their storage.
/// @author Shibui
contract ERC721PutExchange is
    ERC165,
	Context,
	Ownable,
	Pausable,
	ReentrancyGuard,
	IERC721PutExchange
{
	/*///////////////////////////////////////////////////////////////
                                  CONSTANTS
    //////////////////////////////////////////////////////////////*/

	/// @dev Number used to check if the passed contract address correctly implements EIP721.
	bytes4 private immutable interfaceIdERC721 = type(IERC721).interfaceId;

	/*///////////////////////////////////////////////////////////////
                                 SYSTEM FEE
    //////////////////////////////////////////////////////////////*/

	/// @dev The wallet address to which system fees get paid.
	address payable private _systemFeeWallet;

	/// @dev System fee in %. Example: 10 => 1%, 25 => 2,5%, 300 => 30%
	uint256 private _systemFeePerMille;

    /// @inheritdoc IERC165
	function supportsInterface(bytes4 interfaceId) public pure virtual override(ERC165, IERC165) returns (bool) {
		return interfaceId == type(IERC721PutExchange).interfaceId || super.supportsInterface(interfaceId);
	}

	/*///////////////////////////////////////////////////////////////
                              SYSTEM FEE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @notice Sets the new wallet to which all system fees get paid.
	/// @param _newSystemFeeWallet Address of the new system fee wallet.
	function setSystemFeeWallet(address payable _newSystemFeeWallet) external onlyOwner {
		_systemFeeWallet = _newSystemFeeWallet;
	}

	/// @notice Sets the new overall fee %. Example: 10 => 1%, 25 => 2,5%, 300 => 30%
	/// @param _newSystemFeePerMille New fee amount.
	function setSystemFeePerMille(uint256 _newSystemFeePerMille) external onlyOwner {
		_systemFeePerMille = _newSystemFeePerMille;
	}

	/*///////////////////////////////////////////////////////////////
                        ADMINISTRATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @notice Pauses the execution and creation of sell orders on the exchange. Should only be used in emergencies.
	function pause() external onlyOwner {
		_pause();
	}

	/// @notice Unpauses the execution and creation of sell orders on the exchange. Should only be used in emergencies.
	function unpause() external onlyOwner {
		_unpause();
	}

	/// @notice Withdraws any Ether in-case it's ever accidentaly sent to the contract.
	function withdraw() public onlyOwner {
		uint256 balance = address(this).balance;
		payable(msg.sender).transfer(balance);
	}

	/*///////////////////////////////////////////////////////////////
                        INFORMATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @return The current exchange version.
	function version() external pure virtual override returns (uint256) {
		return 1;
	}
}
