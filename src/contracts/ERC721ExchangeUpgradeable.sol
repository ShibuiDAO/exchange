// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.9;
pragma abicoder v2;

import {ERC165} from "@shibuidao/solid/src/utils/ERC165.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC165} from "@shibuidao/solid/src/utils/interfaces/IERC165.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IRoyaltyEngineV1} from "@shibuidao/royalty-registry/src/contracts/IRoyaltyEngineV1.sol";
import {IERC721Exchange} from "./interfaces/IERC721Exchange.sol";
import {IOrderBook} from "./interfaces/IOrderBook.sol";

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {SafeTransferLib} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import {OrderBookVersioning} from "./libraries/OrderBookVersioning.sol";
import {ExchangeOrderComparisonLib} from "./libraries/ExchangeOrderComparisonLib.sol";

/// @dev Handles the creation and execution of sell orders as well as their storage.
/// @author ShibuiDAO
contract ERC721ExchangeUpgradeable is
	ERC165,
	Initializable,
	ContextUpgradeable,
	OwnableUpgradeable,
	PausableUpgradeable,
	ReentrancyGuardUpgradeable,
	IERC721Exchange
{
	/*///////////////////////////////////////////////////////////////
                                  CONSTANTS
    //////////////////////////////////////////////////////////////*/

	/// @dev Number used to check if the passed contract address correctly implements EIP721.
	bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;

	/// @dev Number used to check if the passed contract address correctly implements EIP20.
	bytes4 private constant INTERFACE_ID_ERC20 = 0x36372b07;

	/*///////////////////////////////////////////////////////////////
                                ADDRESS'
    //////////////////////////////////////////////////////////////*/

	/// @notice Address of the "RoyaltyEngineV1" deployment.
	address public royaltyEngine;

	/// @notice Address of the "OrderBook" deployment.
	address public orderBook;

	/// @notice Addeess of the main canonical WETH deployment.
	address public wETH;

	/*///////////////////////////////////////////////////////////////
                                 SYSTEM FEE
    //////////////////////////////////////////////////////////////*/

	/// @dev The wallet address to which system fees get paid.
	address payable private systemFeeWallet;

	/// @dev System fee in %. Example: 10 => 1%, 25 => 2,5%, 300 => 30%
	uint256 private systemFeePerMille;

	/*///////////////////////////////////////////////////////////////
          UPGRADEABLE CONTRACT INITIALIZER/CONTRUCTOR FUNCTION
    //////////////////////////////////////////////////////////////*/

	/// @dev Never called.
	/// @custom:oz-upgrades-unsafe-allow constructor
	// solhint-disable-next-line no-empty-blocks
	constructor() initializer {}

	/// @notice Function acting as the contracts constructor.
	/// @param _systemFeePerMille The default system fee %. Example: 10 => 1%, 25 => 2,5%, 300 => 30%
	/// @param _wethAddress Address of the canonical WETH deployment.
	// solhint-disable-next-line func-name-mixedcase
	function __ERC721Exchange_init(
		uint256 _systemFeePerMille,
		address _royaltyEngine,
		address _orderBook,
		address _wethAddress
	) public override initializer {
		__Context_init();
		__Ownable_init();
		__Pausable_init();
		__ReentrancyGuard_init();

		systemFeePerMille = _systemFeePerMille;

		require(ERC165Checker.supportsInterface(_royaltyEngine, type(IRoyaltyEngineV1).interfaceId), "ENGINE_ADDRESS_NOT_COMPLIANT");
		royaltyEngine = _royaltyEngine;

		require(ERC165Checker.supportsInterface(_orderBook, type(IOrderBook).interfaceId), "ORDER_BOOK_ADDRESS_NOT_COMPLIANT");
		orderBook = _orderBook;

		wETH = _wethAddress;
	}

	/*///////////////////////////////////////////////////////////////
                             ERC165 FUNCTION
    //////////////////////////////////////////////////////////////*/

	/// @inheritdoc IERC165
	function supportsInterface(bytes4 interfaceId) public pure virtual override(ERC165, IERC165) returns (bool) {
		return interfaceId == type(IERC721Exchange).interfaceId || super.supportsInterface(interfaceId);
	}

	/*///////////////////////////////////////////////////////////////
                   PUBLIC SELL ORDER MANIPULATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @param _tokenContractAddress The ERC721 asset contract address of the desired SellOrder.
	/// @param _tokenId ID of the desired ERC721 asset.
	/// @param _expiration Time of order expiration defined as a UNIX timestamp.
	/// @param _price The price in wei of the given ERC721 asset.
	function bookSellOrder(
		address _tokenContractAddress,
		uint256 _tokenId,
		uint256 _expiration,
		uint256 _price,
		address _token
	) external payable override whenNotPaused {
		SellOrder memory sellOrder = SellOrder(_expiration, _price, _token);

		_bookSellOrder(payable(_msgSender()), _tokenContractAddress, _tokenId, sellOrder);
	}

	/// @notice Updates/overwrites existing SellOrder.
	/// @param _tokenContractAddress The ERC721 asset contract address of the desired SellOrder.
	/// @param _tokenId ID of the desired ERC721 asset.
	/// @param _expiration Time of order expiration defined as a UNIX timestamp.
	/// @param _price The price in wei of the given ERC721 asset.
	function updateSellOrder(
		address _tokenContractAddress,
		uint256 _tokenId,
		uint256 _expiration,
		uint256 _price,
		address _token
	) external payable override whenNotPaused {
		cancelSellOrder(_tokenContractAddress, _tokenId);

		SellOrder memory sellOrder = SellOrder(_expiration, _price, _token);
		_bookSellOrder(payable(_msgSender()), _tokenContractAddress, _tokenId, sellOrder);
	}

	/// @param _seller The seller address of the desired SellOrder.
	/// @param _tokenContractAddress The ERC721 asset contract address of the desired SellOrder.
	/// @param _tokenId ID of the desired ERC721 asset.
	/// @param _expiration Time of order expiration defined as a UNIX timestamp.
	/// @param _price The price in wei of the given ERC721 asset.
	/// @param _recipient The address of the ERC721 asset recipient.
	function exerciseSellOrder(
		address payable _seller,
		address _tokenContractAddress,
		uint256 _tokenId,
		uint256 _expiration,
		uint256 _price,
		address payable _recipient,
		address _token
	) external payable override whenNotPaused nonReentrant {
		if (_token == address(0) && msg.value < _price) revert PaymentMissing();
		if (
			_token != address(0) &&
			(_token == wETH || !ERC165Checker.supportsInterface(_token, INTERFACE_ID_ERC20)) &&
			IERC20(_token).allowance(_msgSender(), address(this)) < _price
		) revert ExchangeNotApprovedSufficientlyEIP20(_token, _price);

		SellOrder memory sellOrder = SellOrder(_expiration, _price, _token);

		_exerciseSellOrder(_seller, _tokenContractAddress, _tokenId, sellOrder, SellOrderExecutionSenders(_recipient, _msgSender()));
	}

	/// @notice Cancels a given SellOrder and emits `SellOrderCanceled`.
	/// @notice Can only be executed by the listed SellOrder seller.
	/// @param _tokenContractAddress Address of the ERC721 token contract.
	/// @param _tokenId ID of the token being sold.
	function cancelSellOrder(address _tokenContractAddress, uint256 _tokenId) public payable override whenNotPaused {
		_cancelSellOrder(_msgSender(), _tokenContractAddress, _tokenId);
	}

	/*///////////////////////////////////////////////////////////////
                   PUBLIC BUY ORDER MANIPULATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @notice Stores a new offer/bid for a given ERC721 asset.
	/// @param _owner The current owner of the desired ERC721 asset.
	/// @param _tokenContractAddress The ERC721 asset contract address.
	/// @param _tokenId ID of the desired ERC721 asset.
	/// @param _expiration Time of order expiration defined as a UNIX timestamp.
	/// @param _offer The offered amount in wei for the given ERC721 asset.
	function bookBuyOrder(
		address payable _owner,
		address _tokenContractAddress,
		uint256 _tokenId,
		uint256 _expiration,
		uint256 _offer,
		address _token
	) external payable override whenNotPaused {
		_token = _token == address(0) ? wETH : _token;
		if (
			(_token == wETH || !ERC165Checker.supportsInterface(_token, INTERFACE_ID_ERC20)) &&
			IERC20(_token).allowance(_msgSender(), address(this)) < _offer
		) revert ExchangeNotApprovedSufficientlyEIP20(_token, _offer);

		BuyOrder memory buyOrder = BuyOrder(_owner, _token, _expiration, _offer);

		_bookBuyOrder(payable(_msgSender()), _tokenContractAddress, _tokenId, buyOrder);
	}

	/// @notice Updates/overwrites existing BuyOrder.
	/// @param _owner The current owner of the desired ERC721 asset.
	/// @param _tokenContractAddress The ERC721 asset contract address of the desired asset.
	/// @param _tokenId ID of the desired ERC721 asset.
	/// @param _expiration Time of order expiration defined as a UNIX timestamp.
	/// @param _offer The offered amount in wei for the given ERC721 asset.
	function updateBuyOrder(
		address payable _owner,
		address _tokenContractAddress,
		uint256 _tokenId,
		uint256 _expiration,
		uint256 _offer,
		address _token
	) external payable override whenNotPaused {
		_token = _token == address(0) ? wETH : _token;
		if (
			(_token == wETH || !ERC165Checker.supportsInterface(_token, INTERFACE_ID_ERC20)) &&
			IERC20(_token).allowance(_msgSender(), address(this)) < _offer
		) revert ExchangeNotApprovedSufficientlyEIP20(_token, _offer);

		cancelBuyOrder(_tokenContractAddress, _tokenId);

		BuyOrder memory buyOrder = BuyOrder(_owner, _token, _expiration, _offer);
		_bookBuyOrder(payable(_msgSender()), _tokenContractAddress, _tokenId, buyOrder);
	}

	function exerciseBuyOrder(
		address payable _bidder,
		address _tokenContractAddress,
		uint256 _tokenId,
		uint256 _expiration,
		uint256 _offer,
		address _token
	) external payable override whenNotPaused {
		BuyOrder memory buyOrder = BuyOrder(payable(_msgSender()), _token, _expiration, _offer);

		_exerciseBuyOrder(_bidder, _tokenContractAddress, _tokenId, buyOrder);
	}

	/// @notice Cancels a given BuyOrder where the buyer is the msg sender and emits `BuyOrderCanceled`.
	/// @param _tokenContractAddress Address of the ERC721 token contract.
	/// @param _tokenId ID of the token being bought.
	function cancelBuyOrder(address _tokenContractAddress, uint256 _tokenId) public payable override whenNotPaused {
		_cancelBuyOrder(_msgSender(), _tokenContractAddress, _tokenId);
	}

	/*///////////////////////////////////////////////////////////////
                          SELL ORDER VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @notice Finds the order matching the passed parameters. The returned order is possibly expired.
	/// @param _seller Address of the sell order owner.
	/// @param _tokenContractAddress Address of the ERC721 token contract.
	/// @param _tokenId ID of the token being sold.
	/// @return Struct containing all the order data.
	function getSellOrder(
		address _seller,
		address _tokenContractAddress,
		uint256 _tokenId
	) public view override returns (SellOrder memory) {
		bytes memory order = IOrderBook(orderBook).fetchOrder(
			OrderBookVersioning.SELL_ORDER_INITIAL,
			_formOrderId(_seller, _tokenContractAddress, _tokenId)
		);

		if (order.length == 0) return SellOrder(0, 0, address(0));
		return abi.decode(order, (SellOrder));
	}

	/// @notice This relies on the fact that for one we treat expired orders as non-existant and that the default for structs in a mapping is that they have all their values set to 0.
	/// So if a order doesn't exist it will have an expiration of 0.
	/// @param _seller Address of the sell order owner.
	/// @param _tokenContractAddress Address of the ERC721 token contract.
	/// @param _tokenId ID of the token being sold.
	/// @return The validy of the queried order.
	function sellOrderExists(
		address _seller,
		address _tokenContractAddress,
		uint256 _tokenId
	) public view override returns (bool) {
		SellOrder memory sellOrder = getSellOrder(_seller, _tokenContractAddress, _tokenId);

		return 1 <= sellOrder.expiration;
	}

	/*///////////////////////////////////////////////////////////////
                          BUY ORDER VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @notice Finds the order matching the passed parameters. The returned order is possibly expired.
	/// @param _buyer Address of the buy order creator.
	/// @param _tokenContractAddress Address of the ERC721 token contract.
	/// @param _tokenId ID of the token being bought.
	/// @return Struct containing all the order data.
	function getBuyOrder(
		address _buyer,
		address _tokenContractAddress,
		uint256 _tokenId
	) public view override returns (BuyOrder memory) {
		bytes memory order = IOrderBook(orderBook).fetchOrder(
			OrderBookVersioning.BUY_ORDER_INITIAL,
			_formOrderId(_buyer, _tokenContractAddress, _tokenId)
		);

		if (order.length == 0) return BuyOrder(payable(0), address(0), 0, 0);
		return
			abi.decode(
				IOrderBook(orderBook).fetchOrder(OrderBookVersioning.BUY_ORDER_INITIAL, _formOrderId(_buyer, _tokenContractAddress, _tokenId)),
				(BuyOrder)
			);
	}

	/// @notice This relies on the fact that for one we treat expired orders as non-existant and that the default for structs in a mapping is that they have all their values set to 0.
	/// So if a order doesn't exist it will have an expiration of 0.
	/// @param _buyer Address of the buy order creator.
	/// @param _tokenContractAddress Address of the ERC721 token contract.
	/// @param _tokenId ID of the token being bought.
	/// @return The validy of the queried order.
	function buyOrderExists(
		address _buyer,
		address _tokenContractAddress,
		uint256 _tokenId
	) public view override returns (bool) {
		BuyOrder memory buyOrder = getBuyOrder(_buyer, _tokenContractAddress, _tokenId);

		return 1 <= buyOrder.expiration;
	}

	/*///////////////////////////////////////////////////////////////
                   INTERNAL ORDER MANIPULATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @param _seller The address of the asset seller/owner.
	/// @param _tokenContractAddress The ERC721 asset contract address of the desired SellOrder.
	/// @param _tokenId ID of the desired ERC721 asset.
	/// @param _sellOrder Filled in SellOrder to be listed.
	function _bookSellOrder(
		address payable _seller,
		address _tokenContractAddress,
		uint256 _tokenId,
		SellOrder memory _sellOrder
	) internal {
		if (sellOrderExists(_seller, _tokenContractAddress, _tokenId)) revert OrderExists();
		if (!ERC165Checker.supportsInterface(_tokenContractAddress, INTERFACE_ID_ERC721)) revert ContractNotEIP721();
		if (block.timestamp > _sellOrder.expiration) revert OrderExpired();

		IERC721 erc721 = IERC721(_tokenContractAddress);

		if (erc721.ownerOf(_tokenId) != _seller) revert AssetStoredOwnerNotCurrentOwner();
		if (!(erc721.isApprovedForAll(_seller, address(this)) || erc721.getApproved(_tokenId) == address(this))) revert ExchangeNotApprovedEIP721();
		if (_sellOrder.token != address(0) && _sellOrder.token != wETH && !ERC165Checker.supportsInterface(_sellOrder.token, INTERFACE_ID_ERC20))
			revert TokenNotEIP20(_sellOrder.token);

		IOrderBook(orderBook).bookOrder(
			OrderBookVersioning.SELL_ORDER_INITIAL,
			_formOrderId(_seller, _tokenContractAddress, _tokenId),
			abi.encode(_sellOrder)
		);
		emit SellOrderBooked(_seller, _tokenContractAddress, _tokenId, _sellOrder.expiration, _sellOrder.price, _sellOrder.token);
	}

	/// @param _seller The address of the asset seller/owner.
	/// @param _tokenContractAddress The ERC721 asset contract address of the desired SellOrder.
	/// @param _tokenId ID of the desired ERC721 asset.
	/// @param _sellOrder Filled in SellOrder to be compared to the stored one.
	/// @param _senders Struct containing recipient and buyer address'.
	function _exerciseSellOrder(
		address payable _seller,
		address _tokenContractAddress,
		uint256 _tokenId,
		SellOrder memory _sellOrder,
		SellOrderExecutionSenders memory _senders
	) internal {
		if (!sellOrderExists(_seller, _tokenContractAddress, _tokenId)) revert OrderNotExists();

		SellOrder memory sellOrder = getSellOrder(_seller, _tokenContractAddress, _tokenId);

		if (!ExchangeOrderComparisonLib.compareSellOrders(sellOrder, _sellOrder)) revert OrderPassedNotMatchStored();
		if (block.timestamp > sellOrder.expiration) {
			_cancelSellOrder(_seller, _tokenContractAddress, _tokenId);
			revert OrderExpired();
		}

		IERC721 erc721 = IERC721(_tokenContractAddress);

		if (!(erc721.ownerOf(_tokenId) == _seller)) {
			_cancelSellOrder(_seller, _tokenContractAddress, _tokenId);
			revert AssetStoredOwnerNotCurrentOwner();
		}
		if (!(erc721.isApprovedForAll(_seller, address(this)) || erc721.getApproved(_tokenId) == address(this))) {
			_cancelSellOrder(_seller, _tokenContractAddress, _tokenId);
			revert ExchangeNotApprovedEIP721();
		}

		uint256 value = sellOrder.token == address(0) ? msg.value : sellOrder.price;
		uint256 systemFeePayout = systemFeeWallet != address(0) ? (systemFeePerMille * value) / 1000 : 0;
		uint256 remainingPayout = value - systemFeePayout;
		(address payable[] memory recipients, uint256[] memory amounts) = IRoyaltyEngineV1(royaltyEngine).getRoyalty(
			_tokenContractAddress,
			_tokenId,
			remainingPayout
		);

		if (systemFeePayout > 0) {
			if (sellOrder.token == address(0)) SafeTransferLib.safeTransferETH(systemFeeWallet, systemFeePayout);
			else IERC20(sellOrder.token).transferFrom(_senders.buyer, systemFeeWallet, systemFeePayout);
		}
		uint256 recipientsLength = recipients.length;
		for (uint256 i = 0; i < recipientsLength; i = uncheckedInc(i)) {
			uint256 amount = amounts[i];
			if (amount == 0 || remainingPayout == 0) continue;
			uint256 cappedRoyaltyTransaction = amount <= remainingPayout ? amount : amount - (amount - remainingPayout);
			if (sellOrder.token == address(0)) SafeTransferLib.safeTransferETH(recipients[i], cappedRoyaltyTransaction);
			else IERC20(sellOrder.token).transferFrom(_senders.buyer, recipients[i], cappedRoyaltyTransaction);
			remainingPayout -= cappedRoyaltyTransaction;
		}

		if (remainingPayout > 0) {
			if (sellOrder.token == address(0)) SafeTransferLib.safeTransferETH(_seller, remainingPayout);
			else IERC20(sellOrder.token).transferFrom(_senders.buyer, _seller, remainingPayout);
		}
		erc721.safeTransferFrom(_seller, _senders.recipient, _tokenId);

		_cancelSellOrder(_seller, _tokenContractAddress, _tokenId);
		emit SellOrderExercised(_seller, _senders.recipient, _senders.buyer, _tokenContractAddress, _tokenId, sellOrder.price, sellOrder.token);
	}

	/// @notice Cancels a given SellOrder and emits `SellOrderCanceled`.
	/// @param _seller Address of the sell order owner.
	/// @param _tokenContractAddress Address of the ERC721 token contract.
	/// @param _tokenId ID of the token being sold.
	function _cancelSellOrder(
		address _seller,
		address _tokenContractAddress,
		uint256 _tokenId
	) internal {
		IOrderBook(orderBook).cancelOrder(OrderBookVersioning.SELL_ORDER_INITIAL, _formOrderId(_seller, _tokenContractAddress, _tokenId));

		emit SellOrderCanceled(_seller, _tokenContractAddress, _tokenId);
	}

	/// @param _buyer Address of the user placing the BuyOrder.
	/// @param _tokenContractAddress The ERC721 asset contract address of the desired asset.
	/// @param _tokenId ID of the desired ERC721 asset.
	/// @param _buyOrder Filled in BuyOrder to be listed.
	function _bookBuyOrder(
		address payable _buyer,
		address _tokenContractAddress,
		uint256 _tokenId,
		BuyOrder memory _buyOrder
	) internal {
		if (buyOrderExists(_buyer, _tokenContractAddress, _tokenId)) revert OrderExists();
		if (!ERC165Checker.supportsInterface(_tokenContractAddress, INTERFACE_ID_ERC721)) revert ContractNotEIP721();
		if (block.timestamp > _buyOrder.expiration) revert OrderExpired();

		IERC721 erc721 = IERC721(_tokenContractAddress);

		if (erc721.ownerOf(_tokenId) != _buyOrder.owner) revert AssetStoredOwnerNotCurrentOwner();

		IOrderBook(orderBook).bookOrder(
			OrderBookVersioning.BUY_ORDER_INITIAL,
			_formOrderId(_buyer, _tokenContractAddress, _tokenId),
			abi.encode(_buyOrder)
		);
		emit BuyOrderBooked(_buyer, _buyOrder.owner, _tokenContractAddress, _tokenId, _buyOrder.expiration, _buyOrder.offer, _buyOrder.token);
	}

	/// @param _buyer Address of the user placing the BuyOrder.
	/// @param _tokenContractAddress The ERC721 asset contract address of the desired asset.
	/// @param _tokenId ID of the desired ERC721 asset.
	/// @param _buyOrder Filled in BuyOrder to be compared to the stored one.
	function _exerciseBuyOrder(
		address payable _buyer,
		address _tokenContractAddress,
		uint256 _tokenId,
		BuyOrder memory _buyOrder
	) internal {
		if (!buyOrderExists(_buyer, _tokenContractAddress, _tokenId)) revert OrderNotExists();

		BuyOrder memory buyOrder = getBuyOrder(_buyer, _tokenContractAddress, _tokenId);
		address _token = buyOrder.token == address(0) ? wETH : buyOrder.token;

		if (!ExchangeOrderComparisonLib.compareBuyOrders(_buyOrder, buyOrder)) revert OrderPassedNotMatchStored();
		if (IERC20(_token).allowance(_buyer, address(this)) < buyOrder.offer) revert ExchangeNotApprovedSufficientlyEIP20(_token, buyOrder.offer);
		if (block.timestamp > buyOrder.expiration) {
			_cancelBuyOrder(_buyer, _tokenContractAddress, _tokenId);
			revert OrderExpired();
		}
		if (!(IERC721(_tokenContractAddress).ownerOf(_tokenId) == buyOrder.owner)) {
			_cancelBuyOrder(_buyer, _tokenContractAddress, _tokenId);
			revert AssetStoredOwnerNotCurrentOwner();
		}
		if (
			!(IERC721(_tokenContractAddress).isApprovedForAll(buyOrder.owner, address(this)) ||
				IERC721(_tokenContractAddress).getApproved(_tokenId) == address(this))
		) {
			_cancelBuyOrder(_buyer, _tokenContractAddress, _tokenId);
			revert ExchangeNotApprovedEIP721();
		}

		uint256 systemFeePayout = systemFeeWallet != address(0) ? (systemFeePerMille * buyOrder.offer) / 1000 : 0;
		uint256 remainingPayout = buyOrder.offer - systemFeePayout;
		(address payable[] memory recipients, uint256[] memory amounts) = IRoyaltyEngineV1(royaltyEngine).getRoyalty(
			_tokenContractAddress,
			_tokenId,
			remainingPayout
		);

		if (systemFeePayout > 0) IERC20(_token).transferFrom(_buyer, systemFeeWallet, systemFeePayout);

		uint256 recipientsLength = recipients.length;
		for (uint256 i = 0; i < recipientsLength; i = uncheckedInc(i)) {
			uint256 amount = amounts[i];
			if (amount == 0 || remainingPayout == 0) continue;
			uint256 cappedRoyaltyTransaction = amount <= remainingPayout ? amount : amount - (amount - remainingPayout);
			IERC20(_token).transferFrom(_buyer, recipients[i], cappedRoyaltyTransaction);
			remainingPayout -= cappedRoyaltyTransaction;
		}

		if (remainingPayout > 0) IERC20(_token).transferFrom(_buyer, buyOrder.owner, remainingPayout);
		IERC721(_tokenContractAddress).safeTransferFrom(buyOrder.owner, _buyer, _tokenId);

		_cancelBuyOrder(_buyer, _tokenContractAddress, _tokenId);
		emit BuyOrderExercised(_buyer, buyOrder.owner, _tokenContractAddress, _tokenId, buyOrder.offer, _token);
	}

	/// @notice Cancels a given BuyOrder and emits `BuyOrderCanceled`.
	/// @param _buyer Address of the buy order owner.
	/// @param _tokenContractAddress Address of the ERC721 token contract.
	/// @param _tokenId ID of the token being bought.
	function _cancelBuyOrder(
		address _buyer,
		address _tokenContractAddress,
		uint256 _tokenId
	) internal {
		IOrderBook(orderBook).cancelOrder(OrderBookVersioning.BUY_ORDER_INITIAL, _formOrderId(_buyer, _tokenContractAddress, _tokenId));

		emit BuyOrderCanceled(_buyer, _tokenContractAddress, _tokenId);
	}

	/// @notice Forms the ID used in the orders mapping.
	/// @param _userAddress The creator of the SellOrder.
	/// @param _tokenContractAddress Address of the ERC721 token contract.
	/// @param _tokenId ID of ERC721 asset.
	/// @return The order ID composed of user address, contract address, and token ID (`{userAddress}-{tokenContractAddress}-{tokenId}`).
	function _formOrderId(
		address _userAddress,
		address _tokenContractAddress,
		uint256 _tokenId
	) internal pure returns (bytes memory) {
		return abi.encode(_userAddress, _tokenContractAddress, _tokenId);
	}

	/*///////////////////////////////////////////////////////////////
                              SYSTEM FEE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @notice Sets the new wallet to which all system fees get paid.
	/// @param _newSystemFeeWallet Address of the new system fee wallet.
	function setSystemFeeWallet(address payable _newSystemFeeWallet) external onlyOwner {
		systemFeeWallet = _newSystemFeeWallet;
	}

	/// @notice Sets the new overall fee %. Example: 10 => 1%, 25 => 2,5%, 300 => 30%
	/// @param _newSystemFeePerMille New fee amount.
	function setSystemFeePerMille(uint256 _newSystemFeePerMille) external onlyOwner {
		systemFeePerMille = _newSystemFeePerMille;
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

	/// @dev Increments a loop within a unchecked context.
	function uncheckedInc(uint256 i) private pure returns (uint256) {
		unchecked {
			return i + 1;
		}
	}

	/*///////////////////////////////////////////////////////////////
                        INFORMATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @inheritdoc IERC721Exchange
	function version() public pure virtual override returns (uint256) {
		return 1;
	}
}
