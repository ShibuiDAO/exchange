// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.2;
pragma abicoder v2;

import {Context} from '@openzeppelin/contracts/utils/Context.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';
import {ReentrancyGuard} from '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import {ERC165Checker} from '@openzeppelin/contracts/utils/introspection/ERC165Checker.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

/// @author Nejc Drobnič
/// @dev Handles the creation and execution of sell orders as well as their storage.
contract ERC721Market is Context, Ownable, Pausable, ReentrancyGuard {
	using ERC165Checker for address;

	/*///////////////////////////////////////////////////////////////
                                  CONSTANTS
    //////////////////////////////////////////////////////////////*/

	/// @notice Number used to check if the passed contract address correctly implements EIP721.
	bytes4 private InterfaceId_IERC721 = 0x80ac58cd;

	/*///////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

	/// @notice Emitted when `createSellOrder` is called.
	/// @param seller Address of the ERC721 asset owner and seller.
	/// @param tokenContractAddress Address of the ERC721 token contract.
	/// @param tokenId ID of ERC721 asset for sale.
	/// @param expiration Time of order expiration defined as a UNIX timestamp.
	/// @param price The price in wei of the given ERC721 asset.
	event SellOrderBooked(address indexed seller, address indexed tokenContractAddress, uint256 indexed tokenId, uint256 expiration, uint256 price);

	/// @notice Emitted when `cancelSellOrder` is called or when `executeSellOrder` completes.
	/// @param seller Address of SellOrder seller.
	/// @param tokenContractAddress Address of the ERC721 token contract.
	/// @param tokenId ID of canceled ERC721 asset.
	event SellOrderCanceled(address indexed seller, address indexed tokenContractAddress, uint256 indexed tokenId);

	/// @notice Emitted when `executeSellOrder` is called.
	/// @param seller Address of the previous ERC721 asset owner and seller.
	/// @param recipient Address of the new ERC721 asset owner and buyer.
	/// @param tokenContractAddress Address of the ERC721 token contract.
	/// @param tokenId ID of the bought ERC721 asset.
	/// @param price The price in wei at which the ERC721 asset was bought.
	event SellOrderFufilled(address indexed seller, address recipient, address indexed tokenContractAddress, uint256 indexed tokenId, uint256 price);

	/*///////////////////////////////////////////////////////////////
                                FEE VALUES
    //////////////////////////////////////////////////////////////*/

    /// @notice The wallet address to which system fees get paid.
    address payable _systemFeeWallet;

    /// @notice System fee per million.
    uint256 private _systemFeePerMille = 25;

	/*///////////////////////////////////////////////////////////////
                                ORDER STORAGE
    //////////////////////////////////////////////////////////////*/

    // TODO: possibly convert to multi level mapping.
    /// @notice Maps orderId (composed of `{sellerAddress}-{tokenContractAddress}-{tokenId}`) to the SellOrder.
	mapping(bytes => SellOrder) sellOrders;

	/// @param seller Address of the ERC721 asset owner and seller.
	/// @param tokenContractAddress Address of the ERC721 token contract.
	/// @param tokenId ID of ERC721 asset for sale.
	/// @param expiration Time of order expiration defined as a UNIX timestamp.
	/// @param price The price in wei of the given ERC721 asset.
	struct SellOrder {
		address payable seller;
		address tokenContractAddress;
		uint256 tokenId;
		uint256 expiration;
		uint256 price;
	}

    /*///////////////////////////////////////////////////////////////
                   PUBLIC SELL ORDER MANIPULATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @param tokenContractAddress The ERC721 asset contract address of the desired SellOrder.
    /// @param tokenId ID of the desired ERC721 asset.
	/// @param expiration Time of order expiration defined as a UNIX timestamp.
	/// @param price The price in wei of the given ERC721 asset.
	function createSellOrder(
		address tokenContractAddress,
		uint256 tokenId,
		uint256 expiration,
		uint256 price
	) external whenNotPaused {
		SellOrder memory sellOrder = SellOrder(payable(_msgSender()), tokenContractAddress, tokenId, expiration, price);

		_createSellOrder(sellOrder);
	}

    /// @param seller The seller address of the desired SellOrder.
    /// @param tokenContractAddress The ERC721 asset contract address of the desired SellOrder.
    /// @param tokenId ID of the desired ERC721 asset.
	/// @param expiration Time of order expiration defined as a UNIX timestamp.
	/// @param price The price in wei of the given ERC721 asset.
    /// @param recipient The address of the ERC721 asset recipient.
	function executeSellOrder(
		address payable seller,
		address tokenContractAddress,
		uint256 tokenId,
		uint256 expiration,
		uint256 price,
		address payable recipient
	) external payable whenNotPaused nonReentrant {
		require(msg.value >= price, "Your transaction doesn't have the required payment.");

		SellOrder memory sellOrder = SellOrder(seller, tokenContractAddress, tokenId, expiration, price);

		_executeSellOrder(sellOrder, recipient);
	}

	/// @notice Cancels a given SellOrder and emits `SellOrderCanceled`.
	/// @notice Can only be executed by the listed SellOrder seller.
	/// @param seller Address of the sell order owner.
	/// @param tokenContractAddress Address of the ERC721 token contract.
	/// @param tokenId ID of the token being sold.
	function cancelSellOrder(
		address seller,
		address tokenContractAddress,
		uint256 tokenId
        // TODO: Should cancelling only be allowed while the Market isn't paused?
	) external {
		require(_msgSender() == seller, 'You are not the sell order seller.');
        require(sellOrderExists(seller, tokenContractAddress, tokenId), 'This sell order does not exist.');

		_cancelSellOrder(seller, tokenContractAddress, tokenId);
	}

    /*///////////////////////////////////////////////////////////////
                          SELL ORDER VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @param seller Address of the sell order owner.
	/// @param tokenContractAddress Address of the ERC721 token contract.
	/// @param tokenId ID of the token being sold.
	/// @return Struct containing all the order data.
	function getSellOrder(
		address seller,
		address tokenContractAddress,
		uint256 tokenId
	) public view returns (SellOrder memory) {
		require(sellOrderExists(seller, tokenContractAddress, tokenId), 'This sell order does not exist.');

		return sellOrders[_formOrderId(seller, tokenContractAddress, tokenId)];
	}

	/// @notice This relies on the fact that for one we treat expired orders as non-existant and that the default for structs in a mapping is that they have all their values set to 0.
	/// So if a order doesn't exist it will have an expiration of 0 which is in this context the same as being expired.
	/// @param seller Address of the sell order owner.
	/// @param tokenContractAddress Address of the ERC721 token contract.
	/// @param tokenId ID of the token being sold.
	/// @return The validy of the queried order.
	function sellOrderExists(
		address seller,
		address tokenContractAddress,
		uint256 tokenId
	) public view returns (bool) {
		SellOrder memory sellOrder = sellOrders[_formOrderId(seller, tokenContractAddress, tokenId)];

		return block.timestamp < sellOrder.expiration;
	}

    /*///////////////////////////////////////////////////////////////
                   INTERNAL ORDER MANIPULATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @param sellOrder Filled in SellOrder to be listed.
	function _createSellOrder(SellOrder memory sellOrder) internal {
		require(!sellOrderExists(sellOrder.seller, sellOrder.tokenContractAddress, sellOrder.tokenId), 'This order already exists.');

		require(sellOrder.tokenContractAddress.supportsInterface(InterfaceId_IERC721), 'IS_NOT_721_TOKEN');

		require((block.timestamp < sellOrder.expiration), 'This sell order has expired.');

		IERC721 erc721 = IERC721(sellOrder.tokenContractAddress);

		require((erc721.ownerOf(sellOrder.tokenId) == sellOrder.seller), 'The seller does not own this ERC721 token.');

		require(erc721.getApproved(sellOrder.tokenId) == address(this), 'The ERC721Market contract is not approved to operate this ERC721 token.');

		sellOrders[_formOrderId(sellOrder.seller, sellOrder.tokenContractAddress, sellOrder.tokenId)] = sellOrder;
		emit SellOrderBooked(sellOrder.seller, sellOrder.tokenContractAddress, sellOrder.tokenId, sellOrder.expiration, sellOrder.price);
	}

    /// @param _sellOrder Filled in SellOrder to be compared to the stored one.
    /// @param recipient The address of the ERC721 asset recipient.
	function _executeSellOrder(SellOrder memory _sellOrder, address payable recipient) internal {
		SellOrder memory sellOrder = getSellOrder(_sellOrder.seller, _sellOrder.tokenContractAddress, _sellOrder.tokenId);

		require(_compareSellOrders(sellOrder, _sellOrder), "Passed sell order data doesn't equal stored sell order data.");

		require(sellOrder.tokenContractAddress.supportsInterface(InterfaceId_IERC721), 'IS_NOT_721_TOKEN');

		require((block.timestamp < sellOrder.expiration), 'This sell order has expired.');

		IERC721 erc721 = IERC721(sellOrder.tokenContractAddress);

		require((erc721.ownerOf(sellOrder.tokenId) == sellOrder.seller), 'The seller does not own this ERC721 token.');

		require(erc721.getApproved(sellOrder.tokenId) == address(this), 'The ERC721Market contract is not approved to operate this ERC721 token.');

        uint256 systemFeePayout = (_systemFeePerMille * msg.value) / 1000;
		// TODO: Account for royalties
		uint256 remainingPayout = msg.value - systemFeePayout;

		(bool systemFeeSent, bytes memory systemFeeData) = _systemFeeWallet.call{value: systemFeePayout}('');
		require(systemFeeSent, 'Failed to send ETH to system fee wallet.');

		(bool sellerSent, bytes memory sellerData) = sellOrder.seller.call{value: remainingPayout}('');
		require(sellerSent, 'Failed to send ETH to seller.');

		erc721.safeTransferFrom(sellOrder.seller, recipient, sellOrder.tokenId);

		// TODO: Evaluate the viability of this since even when the order gets fufilled it will emit that it got canceled. This might be a problem when building the subgraph.
		_cancelSellOrder(sellOrder.seller, sellOrder.tokenContractAddress, sellOrder.tokenId);
		emit SellOrderFufilled(sellOrder.seller, recipient, sellOrder.tokenContractAddress, sellOrder.tokenId, sellOrder.price);
	}

	/// @notice Cancels a given SellOrder and emits `SellOrderCanceled`.
	/// @param seller Address of the sell order owner.
	/// @param tokenContractAddress Address of the ERC721 token contract.
	/// @param tokenId ID of the token being sold.
	function _cancelSellOrder(
		address seller,
		address tokenContractAddress,
		uint256 tokenId
	) internal {
		delete (sellOrders[_formOrderId(seller, tokenContractAddress, tokenId)]);

		emit SellOrderCanceled(seller, tokenContractAddress, tokenId);
	}

	/// @notice Forms the ID used in the orders mapping.
	/// @param userAddress The creator of the SellOrder.
	/// @param tokenContractAddress Address of the ERC721 token contract.
	/// @param tokenId ID of ERC721 asset.
	/// @return The order ID composed of user address, contract address, and token ID (`{userAddress}-{tokenContractAddress}-{tokenId}`).
	function _formOrderId(
		address userAddress,
		address tokenContractAddress,
		uint256 tokenId
	) internal pure returns (bytes memory) {
		return abi.encodePacked(userAddress, '-', tokenContractAddress, '-', tokenId);
	}

	/// @notice Hashes and compares 2 SellOrder instances to determine if they have the same parameters.
	/// @param _left SellOrder instance to be hashed and compared on the left side of the operator.
	/// @param _right SellOrder instance to be hashed and compared on the right side of the operator.
	/// @return A boolean value indication if the 2 SellOrder instances match.
	function _compareSellOrders(SellOrder memory _left, SellOrder memory _right) internal pure returns (bool) {
		return keccak256(abi.encode(_left)) == keccak256(abi.encode(_right));
	}

    /*///////////////////////////////////////////////////////////////
                                FEE  FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the new wallet to which all system fees get transfered.
    /// @param _newSystemFeeWallet Address of the new system fee wallet.
    function setSystemFeeWallet(address payable _newSystemFeeWallet) external onlyOwner {
        _systemFeeWallet = _newSystemFeeWallet;
    }

    /// @notice Sets the new overall fee per million value.
    /// @param _newSystemFeePerMille New fee amount.
    function setSystemFeePerMille(uint256 _newSystemFeePerMille) external onlyOwner {
        _systemFeePerMille = _newSystemFeePerMille;
    }

	/*///////////////////////////////////////////////////////////////
                        ADMINISTRATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Pauses the execution and creation of sell orders on the market. Should only be used in emergencies.
	function pause() external onlyOwner {
		_pause();
	}

    /// @notice Unpauses the execution and creation of sell orders on the market. Should only be used in emergencies.
	function unpause() external onlyOwner {
		_unpause();
	}

    /// @notice Withdraws any Ether in-case it's ever accidentaly sent to the contract.
    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
}
