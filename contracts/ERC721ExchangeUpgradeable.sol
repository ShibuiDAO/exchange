// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.2;
pragma abicoder v2;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {ContextUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol';
import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {PausableUpgradeable} from '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import {ReentrancyGuardUpgradeable} from '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';

import {ERC165CheckerUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol';

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/// @author Nejc Drobnič
/// @dev Handles the creation and execution of sell orders as well as their storage.
contract ERC721ExchangeUpgradeable is Initializable, ContextUpgradeable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
	using ERC165CheckerUpgradeable for address;

	/*///////////////////////////////////////////////////////////////
                                  CONSTANTS
    //////////////////////////////////////////////////////////////*/

	/// @dev Number used to check if the passed contract address correctly implements EIP721.
	bytes4 private constant InterfaceId_IERC721 = 0x80ac58cd;

	/// @dev Interface of the main canonical WETH deployment.
	IERC20 private WETH;

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

	/// @notice Emitted when `updateSellOrder` is called.
	/// @param seller Address of the ERC721 asset owner and seller.
	/// @param tokenContractAddress Address of the ERC721 token contract.
	/// @param tokenId ID of ERC721 asset for sale.
	/// @param expiration Time of order expiration defined as a UNIX timestamp.
	/// @param price The price in wei of the given ERC721 asset.
	event SellOrderUpdated(address indexed seller, address indexed tokenContractAddress, uint256 indexed tokenId, uint256 expiration, uint256 price);

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
	event SellOrderFufilled(address indexed seller, address recipient, address buyer, address indexed tokenContractAddress, uint256 indexed tokenId, uint256 price);

	/// @notice Emitted when `updateBuyOrder` is called.
	/// @param buyer Address of the ERC721 asset bidder.
	/// @param owner Address of the current ERC721 asset owner.
	/// @param tokenContractAddress Address of the ERC721 token contract.
	/// @param tokenId ID of ERC721 asset for sale.
	/// @param expiration Time of order expiration defined as a UNIX timestamp.
	/// @param offer The offer in wei for the given ERC721 asset.
	event BuyOrderUpdated(
		address indexed buyer,
		address owner,
		address indexed tokenContractAddress,
		uint256 indexed tokenId,
		uint256 expiration,
		uint256 offer
	);

	/// @notice Emitted when `createBuyOrder` is called.
	/// @param buyer Address of the ERC721 asset bidder.
	/// @param owner Address of the current ERC721 asset owner.
	/// @param tokenContractAddress Address of the ERC721 token contract.
	/// @param tokenId ID of ERC721 asset for sale.
	/// @param expiration Time of order expiration defined as a UNIX timestamp.
	/// @param offer The offer in wei for the given ERC721 asset.
	event BuyOrderBooked(
		address indexed buyer,
		address owner,
		address indexed tokenContractAddress,
		uint256 indexed tokenId,
		uint256 expiration,
		uint256 offer
	);

	/// @notice Emitted when `cancelBuyOrder` is call edor when `acceptBuyOrder` completes.
	/// @param buyer Address of BuyOrder buyer.
	/// @param tokenContractAddress Address of the ERC721 token contract.
	/// @param tokenId ID of canceled ERC721 asset.
	event BuyOrderCanceled(address indexed buyer, address indexed tokenContractAddress, uint256 indexed tokenId);

	/// @notice Emitted when `acceptBuy` is called.
	/// @param buyer Address of the ERC721 asset bidder.
	/// @param seller Address of the current ERC721 asset owner.
	/// @param tokenContractAddress Address of the ERC721 token contract.
	/// @param tokenId ID of ERC721 asset for sale.
	/// @param offer The offer in wei for the given ERC721 asset.
	event BuyOrderAccepted(address buyer, address indexed seller, address indexed tokenContractAddress, uint256 indexed tokenId, uint256 offer);

	/// @notice Emitted when `setRoyalty` is called.
	/// @param executor Address that triggered the royalty change.
	/// @param tokenContractAddress Address of the ERC721 token contract (collection).
	/// @param newPayoutAddress The newly set royalties payout address.
	/// @param oldPayoutAddress The previously set royalties payout address.
	event CollectionRoyaltyPayoutAddressUpdated(
		address indexed tokenContractAddress,
		address indexed executor,
		address indexed newPayoutAddress,
		address oldPayoutAddress
	);

	/// @notice Emitted when `setRoyalty` is called.
	/// @param tokenContractAddress Address of the ERC721 token contract (collection).
	/// @param executor Address that triggered the royalty change.
	/// @param newRoyaltiesAmount The newly set royalties amount. Example: 10 => 1%, 25 => 2,5%, 300 => 30%
	/// @param oldRoyaltiesAmount The previously set royalties amount. Example: 10 => 1%, 25 => 2,5%, 300 => 30%
	event CollectionRoyaltyFeeAmountUpdated(
		address indexed tokenContractAddress,
		address indexed executor,
		uint256 newRoyaltiesAmount,
		uint256 oldRoyaltiesAmount
	);

	/*///////////////////////////////////////////////////////////////
                                 SYSTEM FEE
    //////////////////////////////////////////////////////////////*/

	/// @dev The wallet address to which system fees get paid.
	address payable _systemFeeWallet;

	/// @dev System fee in %. Example: 10 => 1%, 25 => 2,5%, 300 => 30%
	uint256 private _systemFeePerMille;

	/*///////////////////////////////////////////////////////////////
                            COLLECTION ROYALTIES
    //////////////////////////////////////////////////////////////*/

	/// @dev Maximum collection royalty fee. The maximum fee value is equal to 30%. Example: 10 => 1%, 25 => 2,5%, 300 => 30%
	uint256 private _maxRoyaltyPerMille;

	/// @dev Maps a ERC721 contract address to its payout address.
	mapping(address => address payable) private collectionPayoutAddresses;

	/// @dev Maps a ERC721 contract address to its fee %. Example: 10 => 1%, 25 => 2,5%, 300 => 30%
	mapping(address => uint256) private payoutPerMille;

	/*///////////////////////////////////////////////////////////////
                                ORDER STORAGE
    //////////////////////////////////////////////////////////////*/

	/// @dev Maps orderId (composed of `{sellerAddress}-{tokenContractAddress}-{tokenId}`) to the SellOrder.
	mapping(bytes => SellOrder) sellOrders;

	/// @dev Maps orderId (composed of `{buyerAddress}-{tokenContractAddress}-{tokenId}`) to the BuyOrder.
	mapping(bytes => BuyOrder) buyOrders;

	/// @param expiration Time of order expiration defined as a UNIX timestamp.
	/// @param price The price in wei of the given ERC721 asset.
	struct SellOrder {
		uint256 expiration;
		uint256 price;
	}

	/// @param owner Address of the current ERC721 asset owner.
	/// @param expiration Time of order expiration defined as a UNIX timestamp.
	/// @param offer The offer in wei for the given ERC721 asset.
	struct BuyOrder {
		address payable owner;
		uint256 expiration;
		uint256 offer;
	}

	/*///////////////////////////////////////////////////////////////
                             SELL ORDER EXECUTION
    //////////////////////////////////////////////////////////////*/

    struct SellOrderExecutionSenders {
        address payable recipient;
        address buyer;
    }

	/*///////////////////////////////////////////////////////////////
          UPGRADEABLE CONTRACT INITIALIZER/CONTRUCTOR FUNCTION
    //////////////////////////////////////////////////////////////*/

	/// @notice Function acting as the contracts constructor.
	/// @param __maxRoyaltyPerMille The overall maximum royalty fee %. Example: 10 => 1%, 25 => 2,5%, 300 => 30%
	/// @param __systemFeePerMille The default system fee %. Example: 10 => 1%, 25 => 2,5%, 300 => 30%
	/// @param __wethAddress Address of the canonical WETH deployment.
	function __ERC721Exchange_init(
		uint256 __maxRoyaltyPerMille,
		uint256 __systemFeePerMille,
		address __wethAddress
	) public initializer {
		__Context_init();
		__Ownable_init();
		__Pausable_init();
		__ReentrancyGuard_init();

		_maxRoyaltyPerMille = __maxRoyaltyPerMille;
		_systemFeePerMille = __systemFeePerMille;

		WETH = IERC20(__wethAddress);
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
		SellOrder memory sellOrder = SellOrder(expiration, price);

		_createSellOrder(payable(_msgSender()), tokenContractAddress, tokenId, sellOrder);
	}

	/// @notice Updates/overwrites existing SellOrder.
	/// @param tokenContractAddress The ERC721 asset contract address of the desired SellOrder.
	/// @param tokenId ID of the desired ERC721 asset.
	/// @param expiration Time of order expiration defined as a UNIX timestamp.
	/// @param price The price in wei of the given ERC721 asset.
	function updateSellOrder(
		address tokenContractAddress,
		uint256 tokenId,
		uint256 expiration,
		uint256 price
	) external whenNotPaused {
		SellOrder memory sellOrder = SellOrder(expiration, price);

		_updateSellOrder(payable(_msgSender()), tokenContractAddress, tokenId, sellOrder);
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

		SellOrder memory sellOrder = SellOrder(expiration, price);

		_executeSellOrder(seller, tokenContractAddress, tokenId, sellOrder, SellOrderExecutionSenders(recipient, _msgSender()));
	}

	/// @notice Cancels a given SellOrder and emits `SellOrderCanceled`.
	/// @notice Can only be executed by the listed SellOrder seller.
	/// @param tokenContractAddress Address of the ERC721 token contract.
	/// @param tokenId ID of the token being sold.
	function cancelSellOrder(address tokenContractAddress, uint256 tokenId) external whenNotPaused {
		require(sellOrderExists(_msgSender(), tokenContractAddress, tokenId), 'This sell order does not exist.');

		_cancelSellOrder(_msgSender(), tokenContractAddress, tokenId);
	}

	/*///////////////////////////////////////////////////////////////
                   PUBLIC BUY ORDER MANIPULATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @notice Stores a new offer/bid for a given ERC721 asset.
	/// @param owner The current owner of the desired ERC721 asset.
	/// @param expiration Time of order expiration defined as a UNIX timestamp.
	/// @param offer The offered amount in wei for the given ERC721 asset.
	function createBuyOrder(
		address payable owner,
		address tokenContractAddress,
		uint256 tokenId,
		uint256 expiration,
		uint256 offer
	) external whenNotPaused {
		require(
			WETH.allowance(_msgSender(), address(this)) >= offer,
			'The ERC721Exchange contract is not approved to operate a sufficient amount of the buyers WETH.'
		);

		BuyOrder memory buyOrder = BuyOrder(owner, expiration, offer);

		_createBuyOrder(payable(_msgSender()), tokenContractAddress, tokenId, buyOrder);
	}

	/// @notice Updates/overwrites existing BuyOrder.
	/// @param owner The current owner of the desired ERC721 asset.
	/// @param tokenContractAddress The ERC721 asset contract address of the desired asset.
	/// @param tokenId ID of the desired ERC721 asset.
	/// @param expiration Time of order expiration defined as a UNIX timestamp.
	/// @param offer The offered amount in wei for the given ERC721 asset.
	function updateBuyOrder(
		address payable owner,
		address tokenContractAddress,
		uint256 tokenId,
		uint256 expiration,
		uint256 offer
	) external whenNotPaused {
		require(
			WETH.allowance(_msgSender(), address(this)) >= offer,
			'The ERC721Exchange contract is not approved to operate a sufficient amount of the buyers WETH.'
		);

		BuyOrder memory buyOrder = BuyOrder(owner, expiration, offer);

		_updateBuyOrder(payable(_msgSender()), tokenContractAddress, tokenId, buyOrder);
	}

	function acceptBuyOrder(
		address payable bidder,
		address tokenContractAddress,
		uint256 tokenId,
		uint256 expiration,
		uint256 offer
	) external whenNotPaused {
		require(
			WETH.allowance(bidder, address(this)) >= offer,
			'The ERC721Exchange contract is not approved to operate a sufficient amount of the buyers WETH.'
		);

		BuyOrder memory buyOrder = BuyOrder(payable(_msgSender()), expiration, offer);

		_acceptBuyOrder(bidder, tokenContractAddress, tokenId, buyOrder);
	}

	/// @notice Cancels a given BuyOrder where the buyer is the msg sender and emits `BuyOrderCanceled`.
	/// @param tokenContractAddress Address of the ERC721 token contract.
	/// @param tokenId ID of the token being bought.
	function cancelBuyOrder(address tokenContractAddress, uint256 tokenId) external whenNotPaused {
		require(buyOrderExists(_msgSender(), tokenContractAddress, tokenId), 'This buy order does not exist.');

		_cancelBuyOrder(_msgSender(), tokenContractAddress, tokenId);
	}

	/*///////////////////////////////////////////////////////////////
                          SELL ORDER VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @notice Finds the order matching the passed parameters. The returned order is possibly expired.
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
	/// So if a order doesn't exist it will have an expiration of 0.
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

		return 0 < sellOrder.expiration;
	}

	/*///////////////////////////////////////////////////////////////
                          BUY ORDER VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @notice Finds the order matching the passed parameters. The returned order is possibly expired.
	/// @param buyer Address of the buy order creator.
	/// @param tokenContractAddress Address of the ERC721 token contract.
	/// @param tokenId ID of the token being bought.
	/// @return Struct containing all the order data.
	function getBuyOrder(
		address buyer,
		address tokenContractAddress,
		uint256 tokenId
	) public view returns (BuyOrder memory) {
		require(buyOrderExists(buyer, tokenContractAddress, tokenId), 'This buy order does not exist.');

		return buyOrders[_formOrderId(buyer, tokenContractAddress, tokenId)];
	}

	/// @notice This relies on the fact that for one we treat expired orders as non-existant and that the default for structs in a mapping is that they have all their values set to 0.
	/// So if a order doesn't exist it will have an expiration of 0.
	/// @param buyer Address of the buy order creator.
	/// @param tokenContractAddress Address of the ERC721 token contract.
	/// @param tokenId ID of the token being bought.
	/// @return The validy of the queried order.
	function buyOrderExists(
		address buyer,
		address tokenContractAddress,
		uint256 tokenId
	) public view returns (bool) {
		BuyOrder memory buyOrder = buyOrders[_formOrderId(buyer, tokenContractAddress, tokenId)];

		return 0 < buyOrder.expiration;
	}

	/*///////////////////////////////////////////////////////////////
                   INTERNAL ORDER MANIPULATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @param seller The address of the asset seller/owner.
	/// @param tokenContractAddress The ERC721 asset contract address of the desired SellOrder.
	/// @param tokenId ID of the desired ERC721 asset.
	/// @param sellOrder Filled in SellOrder to be listed.
	function _createSellOrder(
		address payable seller,
		address tokenContractAddress,
		uint256 tokenId,
		SellOrder memory sellOrder
	) internal {
		require(!sellOrderExists(seller, tokenContractAddress, tokenId), 'This order already exists.');

		require(tokenContractAddress.supportsInterface(InterfaceId_IERC721), 'IS_NOT_721_TOKEN');

		require((block.timestamp < sellOrder.expiration), 'This sell order is expired.');

		IERC721 erc721 = IERC721(tokenContractAddress);

		require((erc721.ownerOf(tokenId) == seller), 'The seller does not own this ERC721 token.');

		require(erc721.getApproved(tokenId) == address(this), 'The ERC721Exchange contract is not approved to operate this ERC721 token.');

		sellOrders[_formOrderId(seller, tokenContractAddress, tokenId)] = sellOrder;
		emit SellOrderBooked(seller, tokenContractAddress, tokenId, sellOrder.expiration, sellOrder.price);
	}

	/// @param seller The address of the asset seller/owner.
	/// @param tokenContractAddress The ERC721 asset contract address of the desired SellOrder.
	/// @param tokenId ID of the desired ERC721 asset.
	/// @param sellOrder Filled in SellOrder to replace/update existing.
	function _updateSellOrder(
		address payable seller,
		address tokenContractAddress,
		uint256 tokenId,
		SellOrder memory sellOrder
	) internal {
		require(sellOrderExists(seller, tokenContractAddress, tokenId), "This order doesn't exists.");

		require(tokenContractAddress.supportsInterface(InterfaceId_IERC721), 'IS_NOT_721_TOKEN');

		require((block.timestamp < sellOrder.expiration), 'This sell order is expired.');

		IERC721 erc721 = IERC721(tokenContractAddress);

		require((erc721.ownerOf(tokenId) == seller), 'The seller does not own this ERC721 token.');

		require(erc721.getApproved(tokenId) == address(this), 'The ERC721Exchange contract is not approved to operate this ERC721 token.');

		sellOrders[_formOrderId(seller, tokenContractAddress, tokenId)] = sellOrder;
		emit SellOrderUpdated(seller, tokenContractAddress, tokenId, sellOrder.expiration, sellOrder.price);
	}

	/// @param seller The address of the asset seller/owner.
	/// @param tokenContractAddress The ERC721 asset contract address of the desired SellOrder.
	/// @param tokenId ID of the desired ERC721 asset.
	/// @param _sellOrder Filled in SellOrder to be compared to the stored one.
	/// @param _senders Struct containing recipient and buyer address'.
	function _executeSellOrder(
		address payable seller,
		address tokenContractAddress,
		uint256 tokenId,
		SellOrder memory _sellOrder,
        SellOrderExecutionSenders memory _senders
	) internal {
		SellOrder memory sellOrder = getSellOrder(seller, tokenContractAddress, tokenId);

		require(_compareSellOrders(sellOrder, _sellOrder), "Passed sell order data doesn't equal stored sell order data.");

		require(tokenContractAddress.supportsInterface(InterfaceId_IERC721), 'IS_NOT_721_TOKEN');

		require((block.timestamp < sellOrder.expiration), 'This sell order is expired.');

		IERC721 erc721 = IERC721(tokenContractAddress);

		require((erc721.ownerOf(tokenId) == seller), 'The seller does not own this ERC721 token.');

		require(erc721.getApproved(tokenId) == address(this), 'The ERC721Exchange contract is not approved to operate this ERC721 token.');

		uint256 royaltyPayout = (payoutPerMille[tokenContractAddress] * msg.value) / 1000;
		uint256 systemFeePayout = (_systemFeePerMille * msg.value) / 1000;
		uint256 remainingPayout = msg.value - royaltyPayout - systemFeePayout;

		if (royaltyPayout > 0) {
			address payable royaltyPayoutAddress = collectionPayoutAddresses[tokenContractAddress];
			(bool royaltyPayoutSent, bytes memory royaltyPayoutData) = royaltyPayoutAddress.call{value: royaltyPayout}('');
			require(royaltyPayoutSent, 'Failed to send ETH to collectiond royalties wallet.');
		}

		(bool systemFeeSent, bytes memory systemFeeData) = _systemFeeWallet.call{value: systemFeePayout}('');
		require(systemFeeSent, 'Failed to send ETH to system fee wallet.');

		(bool sellerSent, bytes memory sellerData) = seller.call{value: remainingPayout}('');
		require(sellerSent, 'Failed to send ETH to seller.');

		erc721.safeTransferFrom(seller, _senders.recipient, tokenId);

		// TODO: Evaluate the viability of this since even when the order gets fufilled it will emit that it got canceled. This might be a problem when building the subgraph.
		_cancelSellOrder(seller, tokenContractAddress, tokenId);
		emit SellOrderFufilled(seller, _senders.recipient, _senders.buyer, tokenContractAddress, tokenId, sellOrder.price);
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

	/// @param buyer Address of the user placing the BuyOrder.
	/// @param tokenContractAddress The ERC721 asset contract address of the desired asset.
	/// @param tokenId ID of the desired ERC721 asset.
	/// @param buyOrder Filled in BuyOrder to be listed.
	function _createBuyOrder(
		address payable buyer,
		address tokenContractAddress,
		uint256 tokenId,
		BuyOrder memory buyOrder
	) internal {
		require(!buyOrderExists(buyer, tokenContractAddress, tokenId), 'This order already exists.');

		require(tokenContractAddress.supportsInterface(InterfaceId_IERC721), 'IS_NOT_721_TOKEN');

		require((block.timestamp < buyOrder.expiration), 'This sell order is expired.');

		IERC721 erc721 = IERC721(tokenContractAddress);

		require((erc721.ownerOf(tokenId) == buyOrder.owner), 'The desired BuyOrder "owner" does not own this ERC721 token.');

		buyOrders[_formOrderId(buyer, tokenContractAddress, tokenId)] = buyOrder;
		emit BuyOrderBooked(buyer, buyOrder.owner, tokenContractAddress, tokenId, buyOrder.expiration, buyOrder.offer);
	}

	/// @param buyer Address of the user placing the BuyOrder.
	/// @param tokenContractAddress The ERC721 asset contract address of the desired asset.
	/// @param tokenId ID of the desired ERC721 asset.
	/// @param buyOrder Filled in BuyOrder to replace/update existing.
	function _updateBuyOrder(
		address payable buyer,
		address tokenContractAddress,
		uint256 tokenId,
		BuyOrder memory buyOrder
	) internal {
		require(buyOrderExists(buyer, tokenContractAddress, tokenId), "This order doesn't exists.");

		require(tokenContractAddress.supportsInterface(InterfaceId_IERC721), 'IS_NOT_721_TOKEN');

		require((block.timestamp < buyOrder.expiration), 'This buy order is expired.');

		IERC721 erc721 = IERC721(tokenContractAddress);

		require((erc721.ownerOf(tokenId) == buyOrder.owner), 'The desired BuyOrder "owner" does not own this ERC721 token.');

		buyOrders[_formOrderId(buyer, tokenContractAddress, tokenId)] = buyOrder;
		emit BuyOrderUpdated(buyer, buyOrder.owner, tokenContractAddress, tokenId, buyOrder.expiration, buyOrder.offer);
	}

	/// @param buyer Address of the user placing the BuyOrder.
	/// @param tokenContractAddress The ERC721 asset contract address of the desired asset.
	/// @param tokenId ID of the desired ERC721 asset.
	/// @param _buyOrder Filled in BuyOrder to be compared to the stored one.
	function _acceptBuyOrder(
		address payable buyer,
		address tokenContractAddress,
		uint256 tokenId,
		BuyOrder memory _buyOrder
	) internal {
		BuyOrder memory buyOrder = getBuyOrder(buyer, tokenContractAddress, tokenId);

		require(_compareBuyOrders(_buyOrder, buyOrder), "Passed buy order data doesn't equal stored buy order data.");

		require(tokenContractAddress.supportsInterface(InterfaceId_IERC721), 'IS_NOT_721_TOKEN');

		require((block.timestamp < buyOrder.expiration), 'This buy order has expired.');

		IERC721 erc721 = IERC721(tokenContractAddress);

		require((erc721.ownerOf(tokenId) == buyOrder.owner), 'The desired BuyOrder "owner" does not own this ERC721 token.');

		require(erc721.getApproved(tokenId) == address(this), 'The ERC721Exchange contract is not approved to operate this ERC721 token.');

		uint256 royaltyPayout = (payoutPerMille[tokenContractAddress] * buyOrder.offer) / 1000;
		uint256 systemFeePayout = (_systemFeePerMille * buyOrder.offer) / 1000;
		uint256 remainingPayout = buyOrder.offer - royaltyPayout - systemFeePayout;

		if (royaltyPayout > 0) {
			address payable royaltyPayoutAddress = collectionPayoutAddresses[tokenContractAddress];
			WETH.transferFrom(buyer, royaltyPayoutAddress, royaltyPayout);
		}

		WETH.transferFrom(buyer, _systemFeeWallet, systemFeePayout);
		WETH.transferFrom(buyer, buyOrder.owner, remainingPayout);

		erc721.safeTransferFrom(buyOrder.owner, buyer, tokenId);

		// TODO: Evaluate the viability of this since even when the order gets fufilled it will emit that it got canceled. This might be a problem when building the subgraph.
		_cancelBuyOrder(buyer, tokenContractAddress, tokenId);
		emit BuyOrderAccepted(buyer, buyOrder.owner, tokenContractAddress, tokenId, buyOrder.offer);
	}

	/// @notice Cancels a given BuyOrder and emits `BuyOrderCanceled`.
	/// @param buyer Address of the buy order owner.
	/// @param tokenContractAddress Address of the ERC721 token contract.
	/// @param tokenId ID of the token being bought.
	function _cancelBuyOrder(
		address buyer,
		address tokenContractAddress,
		uint256 tokenId
	) internal {
		delete (buyOrders[_formOrderId(buyer, tokenContractAddress, tokenId)]);

		emit BuyOrderCanceled(buyer, tokenContractAddress, tokenId);
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

	/// @notice Hashes and compares 2 BuyOrder instances to determine if they have the same parameters.
	/// @param _left BuyOrder instance to be hashed and compared on the left side of the operator.
	/// @param _right BuyOrder instance to be hashed and compared on the right side of the operator.
	/// @return A boolean value indication if the 2 BuyOrder instances match.
	function _compareBuyOrders(BuyOrder memory _left, BuyOrder memory _right) internal pure returns (bool) {
		return keccak256(abi.encode(_left)) == keccak256(abi.encode(_right));
	}

	/*///////////////////////////////////////////////////////////////
                        COLLECTION ROYALTY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @notice Sets a new or initial value for the collection royalty fee.
	/// @param _tokenContractAddress The ERC721 contract (collection) for which to set the fee/royalty.
	/// @param _payoutAddress The address to which royalties get paid.
	/// @param _payoutPerMille The royalty/fee amount. Example: 10 => 1%, 25 => 2,5%, 300 => 30%
	function setRoyalty(
		address _tokenContractAddress,
		address payable _payoutAddress,
		uint256 _payoutPerMille
	) external {
		require(
			(_payoutPerMille >= 0 && _payoutPerMille <= _maxRoyaltyPerMille),
			string(abi.encodePacked('Royalty must be between 0 and ', _maxRoyaltyPerMille / 10, '%'))
		);
		require(_tokenContractAddress.supportsInterface(InterfaceId_IERC721), 'IS_NOT_721_TOKEN');

		Ownable ownableNFTContract = Ownable(_tokenContractAddress);
		require(_msgSender() == ownableNFTContract.owner() || _msgSender() == owner(), 'ADDRESS_NOT_AUTHORIZED');

		emit CollectionRoyaltyPayoutAddressUpdated(
			_tokenContractAddress,
			_msgSender(),
			_payoutAddress,
			collectionPayoutAddresses[_tokenContractAddress]
		);
		collectionPayoutAddresses[_tokenContractAddress] = _payoutAddress;

		emit CollectionRoyaltyFeeAmountUpdated(_tokenContractAddress, _msgSender(), _payoutPerMille, payoutPerMille[_tokenContractAddress]);
		payoutPerMille[_tokenContractAddress] = _payoutPerMille;
	}

	/// @param _tokenContractAddress The ERC721 contract (collection) for which to get the payout address.
	/// @return The collection payout address.
	function getRoyaltyPayoutAddress(address _tokenContractAddress) public view returns (address) {
		return collectionPayoutAddresses[_tokenContractAddress];
	}

	/// @param _tokenContractAddress The ERC721 contract (collection) for which to get the fee/royalties amount.
	/// @return The collection fee/royalties amount. Example: 10 => 1%, 25 => 2,5%, 300 => 30%
	function getRoyaltyPayoutRate(address _tokenContractAddress) public view returns (uint256) {
		return payoutPerMille[_tokenContractAddress];
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
	function version() external pure virtual returns (string memory) {
		return 'v1.0.1';
	}
}
