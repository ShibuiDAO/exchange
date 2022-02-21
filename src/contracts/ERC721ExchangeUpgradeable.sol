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
	///////////////////////////////////////////////////
	///                  CONSTANTS                  ///
	///////////////////////////////////////////////////

	/// @dev Number used to check if the passed contract address correctly implements EIP721.
	bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;

	/// @dev Number used to check if the passed contract address correctly implements EIP20.
	bytes4 private constant INTERFACE_ID_ERC20 = 0x36372b07;

	////////////////////////////////////
	///            SUNSET            ///
	////////////////////////////////////

	/// @dev Indicates if the exchange has been permanently disabled.
	bool private _sunset;

	//////////////////////////////////////////////
	///                ADDRESS'                ///
	//////////////////////////////////////////////

	/// @notice Address of the "RoyaltyEngineV1" deployment.
	address public royaltyEngine;

	/// @notice Address of the "OrderBook" deployment.
	address public orderBook;

	/// @notice Addeess of the main canonical WETH deployment.
	address public wETH;

	////////////////////////////////////////////////////////
	///                    SYSTEM FEE                    ///
	////////////////////////////////////////////////////////

	/// @dev The wallet address to which system fees get paid.
	address payable private systemFeeWallet;

	/// @dev System fee in %. Example: 10 => 1%, 25 => 2,5%, 300 => 30%
	uint256 private systemFeePerMille;

	//////////////////////////////////////////////////////////////////////////////////////////////////
	///                    UPGRADEABLE CONTRACT INITIALIZER/CONTRUCTOR FUNCTION                    ///
	//////////////////////////////////////////////////////////////////////////////////////////////////

	/// @dev Never called.
	/// @custom:oz-upgrades-unsafe-allow constructor
	// solhint-disable-next-line no-empty-blocks
	constructor() initializer {}

	/// @notice Function acting as the contracts constructor.
	/// @param _systemFeeWallet Address to which system fees get paid.
	/// @param _systemFeePerMille The default system fee %. Example: 10 => 1%, 25 => 2,5%, 300 => 30%
	/// @param _royaltyEngine Address of the RoyaltyEngine deployment.
	/// @param _orderBook Address of the shared OrderBook deployment.
	/// @param _wethAddress Address of the canonical WETH deployment.
	// solhint-disable-next-line func-name-mixedcase
	function __ERC721Exchange_init(
		address _systemFeeWallet,
		uint256 _systemFeePerMille,
		address _royaltyEngine,
		address _orderBook,
		address _wethAddress
	) public override initializer {
		__Context_init();
		__Ownable_init();
		__Pausable_init();
		__ReentrancyGuard_init();

		_sunset = false;

		systemFeeWallet = payable(_systemFeeWallet);
		systemFeePerMille = _systemFeePerMille;

		require(ERC165Checker.supportsInterface(_royaltyEngine, type(IRoyaltyEngineV1).interfaceId), "ENGINE_ADDRESS_NOT_COMPLIANT");
		royaltyEngine = _royaltyEngine;

		require(ERC165Checker.supportsInterface(_orderBook, type(IOrderBook).interfaceId), "ORDER_BOOK_ADDRESS_NOT_COMPLIANT");
		orderBook = _orderBook;

		wETH = _wethAddress;
	}

	/////////////////////////////////////////////////////////////////////////////////
	///                              ERC165 FUNCTION                              ///
	/////////////////////////////////////////////////////////////////////////////////

	/// @inheritdoc IERC165
	function supportsInterface(bytes4 interfaceId) public pure virtual override(ERC165, IERC165) returns (bool) {
		return interfaceId == type(IERC721Exchange).interfaceId || super.supportsInterface(interfaceId);
	}

	//////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                              PUBLIC SELL ORDER MANIPULATION FUNCTIONS                              ///
	//////////////////////////////////////////////////////////////////////////////////////////////////////////

	//        ,-.
	//        `-'
	//        /|\
	//         |             ,-------------------------.                                                 ,--------------------.
	//        / \            |ERC721ExchangeUpgradeable|                                                 |OrderBookUpgradeable|
	//      Caller           `------------+------------'                                                 `---------+----------'
	//        |      bookSellOrder()      |                                                                        |
	//        | ------------------------->|                                                                        |
	//        |                           |                                                                        |
	//        |                           ----.
	//        |                               | _bookSellOrder(_seller, _tokenContractAddress, _tokenId, _sellOrder)
	//        |                           <---'
	//        |                           |                                                                        |
	//        |                           |                                                                        |
	//        |    _____________________________________________________________________________________________________________________
	//        |    ! ALT  /  SellOrder already exists for this token?                                              |                    !
	//        |    !_____/                |                                                                        |                    !
	//        |    !                      ----.                                                                    |                    !
	//        |    !                          | _cancelSellOrder(_seller, _tokenContractAddress, _tokenId)         |                    !
	//        |    !                      <---'                                                                    |                    !
	//        |    !                      |                                                                        |                    !
	//        |    !                      |                     cancelOrder(_orderKey, _order)                     |                    !
	//        |    !                      |------------------------------------------------------------------------>                    !
	//        |    !                      |                                                                        |                    !
	//        |    !                      ----.                                                                    |                    !
	//        |    !                          | emit SellOrderCanceled()                                           |                    !
	//        |    !                      <---'                                                                    |                    !
	//        |    !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
	//        |    !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
	//        |                           |                                                                        |
	//        |                           ----.                                                                    |
	//        |                               | create SellOrder                                                   |
	//        |                           <---'                                                                    |
	//        |                           |                                                                        |
	//        |                           |                      bookOrder(_orderKey, _order)                      |
	//        |                           |------------------------------------------------------------------------>
	//        |                           |                                                                        |
	//        |                           ----.                                                                    |
	//        |                               | emit SellOrderBooked()                                             |
	//        |                           <---'                                                                    |
	//      Caller           ,------------+------------.                                                 ,---------+----------.
	//        ,-.            |ERC721ExchangeUpgradeable|                                                 |OrderBookUpgradeable|
	//        `-'            `-------------------------'                                                 `--------------------'
	//        /|\
	//         |
	//        / \
	//
	/// @dev If `_token` is a zero address then the order will treat it as plain ETH.
	/// @param _tokenContractAddress The ERC721 asset contract address of the desired SellOrder.
	/// @param _tokenId ID of the desired ERC721 asset.
	/// @param _expiration Time of order expiration defined as a UNIX timestamp.
	/// @param _price The price in wei of the given ERC721 asset.
	/// @param _token Alternative ERC20 asset used for payment.
	function bookSellOrder(
		address _tokenContractAddress,
		uint256 _tokenId,
		uint256 _expiration,
		uint256 _price,
		address _token
	) external payable override whenNotPaused nonReentrant {
		SellOrder memory sellOrder = SellOrder(_expiration, _price, _token);

		_bookSellOrder(payable(_msgSender()), _tokenContractAddress, _tokenId, sellOrder);
	}

	//                       ,-.                     ,-.                 ,-.
	//                       `-'                     `-'                 `-'
	//                       /|\                     /|\                 /|\
	//                        |                       |                   |               ,-------------------------.                                                     ,--------------------.
	//                       / \                     / \                 / \              |ERC721ExchangeUpgradeable|                                                     |OrderBookUpgradeable|
	//                     Caller                  Seller            Collection           `------------+------------'                                                     `---------+----------'
	//                       |       exerciseSellOrder(_seller, _tokenContractAddress, _tokenId)       |                                                                            |
	//                       | ----------------------------------------------------------------------->|                                                                            |
	//                       |                       |                   |                             |                                                                            |
	//                       |                       |                   |                             ----.
	//                       |                       |                   |                                 | _exerciseSellOrder(_seller, _tokenContractAddress, _tokenId, _sellOrder)
	//                       |                       |                   |                             <---'
	//                       |                       |                   |                             |                                                                            |
	//                       |                       |                   |                             ----.                                                                        |
	//                       |                       |                   |                                 | exercise SellOrder                                                     |
	//                       |                       |                   |                             <---'                                                                        |
	//                       |                       |                   |                             |                                                                            |
	//                       |                       |                   |                             |                                                                            |
	//          ______________________________________________________________________________________________________________                                                      |
	//          ! ALT  /  Funds for system fees?     |                   |                             |                      !                                                     |
	//          !_____/      |                       |                   |                             |                      !                                                     |
	//          !            |                       |  transfer system fees                           |                      !                                                     |
	//          !            | ----------------------------------------------------------------------->|                      !                                                     |
	//          !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!                                                     |
	//          !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!                                                     |
	//                       |                       |                   |                             |                                                                            |
	//                       |                       |                   |                             |                                                                            |
	//          _________________________________________________________________________              |                                                                            |
	//          ! ALT  /  Royalty recipients found?  |                   |               !             |                                                                            |
	//          !_____/      |                       |                   |               !             |                                                                            |
	//          !            |             transfer royalties            |               !             |                                                                            |
	//          !            | ------------------------------------------>               !             |                                                                            |
	//          !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!             |                                                                            |
	//          !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!             |                                                                            |
	//                       |                       |                   |                             |                                                                            |
	//                       |                       |                   |                             |                                                                            |
	//          ___________________________________________________      |                             |                                                                            |
	//          ! ALT  /  Remaining payout for seller?             !     |                             |                                                                            |
	//          !_____/      |                       |             !     |                             |                                                                            |
	//          !            | transfer remaining ETH|             !     |                             |                                                                            |
	//          !            | ---------------------->             !     |                             |                                                                            |
	//          !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!     |                             |                                                                            |
	//          !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!     |                             |                                                                            |
	//                       |                       |                   |                             |                                                                            |
	//                       |     transfer asset    |                   |                             |                                                                            |
	//                       | <----------------------                   |                             |                                                                            |
	//                       |                       |                   |                             |                                                                            |
	//                       |                       |                   |                             |                       cancelOrder(_orderKey, _order)                       |
	//                       |                       |                   |                             |---------------------------------------------------------------------------->
	//                       |                       |                   |                             |                                                                            |
	//                       |                       |                   |                             ----.                                                                        |
	//                       |                       |                   |                                 | emit SellOrderCanceled()                                               |
	//                       |                       |                   |                             <---'                                                                        |
	//                       |                       |                   |                             |                                                                            |
	//                       |                       |                   |                             ----.                                                                        |
	//                       |                       |                   |                                 | emit SellOrderExercised()                                              |
	//                       |                       |                   |                             <---'                                                                        |
	//                     Caller                  Seller            Collection           ,------------+------------.                                                     ,---------+----------.
	//                       ,-.                     ,-.                 ,-.              |ERC721ExchangeUpgradeable|                                                     |OrderBookUpgradeable|
	//                       `-'                     `-'                 `-'              `-------------------------'                                                     `--------------------'
	//                       /|\                     /|\                 /|\
	//                        |                       |                   |
	//                       / \                     / \                 / \
	//
	/// @dev If `_token` is a zero address then the order will treat it as plain ETH.
	/// @param _seller The seller address of the desired SellOrder.
	/// @param _tokenContractAddress The ERC721 asset contract address of the desired SellOrder.
	/// @param _tokenId ID of the desired ERC721 asset.
	/// @param _expiration Time of order expiration defined as a UNIX timestamp.
	/// @param _price The price in wei of the given ERC721 asset.
	/// @param _recipient The address of the ERC721 asset recipient.
	/// @param _token Alternative ERC20 asset used for payment.
	function exerciseSellOrder(
		address payable _seller,
		address _tokenContractAddress,
		uint256 _tokenId,
		uint256 _expiration,
		uint256 _price,
		address _recipient,
		address _token
	) external payable override whenNotPaused nonReentrant {
		require(_token != address(0) || (_token == address(0) && msg.value >= _price), "PAYMENT_MISSING");
		require(
			_token == address(0) ||
				((_token == wETH || !ERC165Checker.supportsInterface(_token, INTERFACE_ID_ERC20)) &&
					IERC20(_token).allowance(_msgSender(), address(this)) >= _price),
			"EXCHANGE_NOT_APPROVED_SUFFICIENTLY_EIP20"
		);

		SellOrder memory sellOrder = SellOrder(_expiration, _price, _token);

		_exerciseSellOrder(_seller, _tokenContractAddress, _tokenId, sellOrder, SellOrderExecutionSenders(_recipient, _msgSender()));
	}

	//        ,-.
	//        `-'
	//        /|\
	//         |             ,-------------------------.                                            ,--------------------.
	//        / \            |ERC721ExchangeUpgradeable|                                            |OrderBookUpgradeable|
	//      Caller           `------------+------------'                                            `---------+----------'
	//        |     cancelSellOrder()     |                                                                   |
	//        | ------------------------->|                                                                   |
	//        |                           |                                                                   |
	//        |                           ----.
	//        |                               | _cancelSellOrder(msg.sender(), _tokenContractAddress, _tokenId)
	//        |                           <---'
	//        |                           |                                                                   |
	//        |                           ----.                                                               |
	//        |                               | cancel SellOrder                                              |
	//        |                           <---'                                                               |
	//        |                           |                                                                   |
	//        |                           |                  cancelOrder(_orderKey, _order)                   |
	//        |                           |------------------------------------------------------------------->
	//        |                           |                                                                   |
	//        |                           ----.                                                               |
	//        |                               | emit SellOrderCanceled()                                      |
	//        |                           <---'                                                               |
	//      Caller           ,------------+------------.                                            ,---------+----------.
	//        ,-.            |ERC721ExchangeUpgradeable|                                            |OrderBookUpgradeable|
	//        `-'            `-------------------------'                                            `--------------------'
	//        /|\
	//         |
	//        / \
	//
	/// @notice Cancels a given SellOrder and emits "SellOrderCanceled".
	/// @dev Can only be executed by the listed SellOrder seller.
	/// @param _tokenContractAddress Address of the ERC721 token contract.
	/// @param _tokenId ID of the token being sold.
	function cancelSellOrder(address _tokenContractAddress, uint256 _tokenId) public payable override whenNotPaused {
		_cancelSellOrder(_msgSender(), _tokenContractAddress, _tokenId);
	}

	/////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                              PUBLIC BUY ORDER MANIPULATION FUNCTIONS                              ///
	/////////////////////////////////////////////////////////////////////////////////////////////////////////

	//        ,-.
	//        `-'
	//        /|\
	//         |             ,-------------------------.                                              ,--------------------.
	//        / \            |ERC721ExchangeUpgradeable|                                              |OrderBookUpgradeable|
	//      Caller           `------------+------------'                                              `---------+----------'
	//        |      bookBuyOrder()       |                                                                     |
	//        | ------------------------->|                                                                     |
	//        |                           |                                                                     |
	//        |                           ----.
	//        |                               | _bookBuyOrder(_buyer, _tokenContractAddress, _tokenId, _buyOrder)
	//        |                           <---'
	//        |                           |                                                                     |
	//        |                           |                                                                     |
	//        |    __________________________________________________________________________________________________________________
	//        |    ! ALT  /  BuyOrder already exists for this token?                                            |                    !
	//        |    !_____/                |                                                                     |                    !
	//        |    !                      ----.                                                                 |                    !
	//        |    !                          | _cancelBuyOrder(_buyer, _tokenContractAddress, _tokenId)        |                    !
	//        |    !                      <---'                                                                 |                    !
	//        |    !                      |                                                                     |                    !
	//        |    !                      |                   cancelOrder(_orderKey, _order)                    |                    !
	//        |    !                      |--------------------------------------------------------------------->                    !
	//        |    !                      |                                                                     |                    !
	//        |    !                      ----.                                                                 |                    !
	//        |    !                          | emit BuyOrderCanceled()                                         |                    !
	//        |    !                      <---'                                                                 |                    !
	//        |    !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
	//        |    !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
	//        |                           |                                                                     |
	//        |                           ----.                                                                 |
	//        |                               | create BuyOrder                                                 |
	//        |                           <---'                                                                 |
	//        |                           |                                                                     |
	//        |                           |                    bookOrder(_orderKey, _order)                     |
	//        |                           |--------------------------------------------------------------------->
	//        |                           |                                                                     |
	//        |                           ----.                                                                 |
	//        |                               | emit BuyOrderBooked()                                           |
	//        |                           <---'                                                                 |
	//      Caller           ,------------+------------.                                              ,---------+----------.
	//        ,-.            |ERC721ExchangeUpgradeable|                                              |OrderBookUpgradeable|
	//        `-'            `-------------------------'                                              `--------------------'
	//        /|\
	//         |
	//        / \
	//
	/// @notice Stores a new offer/bid for a given ERC721 asset.
	/// @dev If `_token` is a zero address then the order will treat it as being WETH.
	/// @param _owner The current owner of the desired ERC721 asset.
	/// @param _tokenContractAddress The ERC721 asset contract address.
	/// @param _tokenId ID of the desired ERC721 asset.
	/// @param _expiration Time of order expiration defined as a UNIX timestamp.
	/// @param _offer The offered amount in wei for the given ERC721 asset.
	/// @param _token Alternative ERC20 asset used for payment.
	function bookBuyOrder(
		address payable _owner,
		address _tokenContractAddress,
		uint256 _tokenId,
		uint256 _expiration,
		uint256 _offer,
		address _token
	) external payable override whenNotPaused nonReentrant {
		_token = _token == address(0) ? wETH : _token;
		require(
			(_token == wETH || !ERC165Checker.supportsInterface(_token, INTERFACE_ID_ERC20)) &&
				IERC20(_token).allowance(_msgSender(), address(this)) >= _offer,
			"EXCHANGE_NOT_APPROVED_SUFFICIENTLY_EIP20"
		);

		BuyOrder memory buyOrder = BuyOrder(_owner, _token, _expiration, _offer);

		_bookBuyOrder(payable(_msgSender()), _tokenContractAddress, _tokenId, buyOrder);
	}

	//                       ,-.                       ,-.                 ,-.
	//                       `-'                       `-'                 `-'
	//                       /|\                       /|\                 /|\
	//                        |                         |                   |               ,-------------------------.                                                  ,--------------------.
	//                       / \                       / \                 / \              |ERC721ExchangeUpgradeable|                                                  |OrderBookUpgradeable|
	//                     Caller                    Bidder            Collection           `------------+------------'                                                  `---------+----------'
	//                       |         exerciseBuyOrder(_buyer, _tokenContractAddress, _tokenId)         |                                                                         |
	//                       | ------------------------------------------------------------------------->|                                                                         |
	//                       |                         |                   |                             |                                                                         |
	//                       |                         |                   |                             ----.
	//                       |                         |                   |                                 | _exerciseBuyOrder(_buyer, _tokenContractAddress, _tokenId, _buyOrder)
	//                       |                         |                   |                             <---'
	//                       |                         |                   |                             |                                                                         |
	//                       |                         |                   |                             ----.                                                                     |
	//                       |                         |                   |                                 | exercise BuyOrder                                                   |
	//                       |                         |                   |                             <---'                                                                     |
	//                       |                         |                   |                             |                                                                         |
	//                       |                         |                   |                             |                                                                         |
	//                       |            ______________________________________________________________________________________                                                   |
	//                       |            ! ALT  /  Funds for system fees? |                             |                      !                                                  |
	//                       |            !_____/      |                   |                             |                      !                                                  |
	//                       |            !            |              transfer system fees               |                      !                                                  |
	//                       |            !            | ----------------------------------------------->|                      !                                                  |
	//                       |            !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!                                                  |
	//                       |            !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!                                                  |
	//                       |                         |                   |                             |                                                                         |
	//                       |                         |                   |                             |                                                                         |
	//                       |            _________________________________________________              |                                                                         |
	//                       |            ! ALT  /  Royalty recipients found?              !             |                                                                         |
	//                       |            !_____/      |                   |               !             |                                                                         |
	//                       |            !            | transfer royalties|               !             |                                                                         |
	//                       |            !            | ------------------>               !             |                                                                         |
	//                       |            !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!             |                                                                         |
	//                       |            !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!             |                                                                         |
	//                       |                         |                   |                             |                                                                         |
	//                       |                         |                   |                             |                                                                         |
	//          _____________________________________________________      |                             |                                                                         |
	//          ! ALT  /  Remaining payout for owner?  |             !     |                             |                                                                         |
	//          !_____/      |                         |             !     |                             |                                                                         |
	//          !            | transfer remaining ERC20|             !     |                             |                                                                         |
	//          !            | <------------------------             !     |                             |                                                                         |
	//          !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!     |                             |                                                                         |
	//          !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!     |                             |                                                                         |
	//                       |                         |                   |                             |                                                                         |
	//                       |      transfer asset     |                   |                             |                                                                         |
	//                       | ------------------------>                   |                             |                                                                         |
	//                       |                         |                   |                             |                                                                         |
	//                       |                         |                   |                             |                     cancelOrder(_orderKey, _order)                      |
	//                       |                         |                   |                             |------------------------------------------------------------------------->
	//                       |                         |                   |                             |                                                                         |
	//                       |                         |                   |                             ----.                                                                     |
	//                       |                         |                   |                                 | emit BuyOrderCanceled()                                             |
	//                       |                         |                   |                             <---'                                                                     |
	//                       |                         |                   |                             |                                                                         |
	//                       |                         |                   |                             ----.                                                                     |
	//                       |                         |                   |                                 | emit BuyOrderExercised()                                            |
	//                       |                         |                   |                             <---'                                                                     |
	//                     Caller                    Bidder            Collection           ,------------+------------.                                                  ,---------+----------.
	//                       ,-.                       ,-.                 ,-.              |ERC721ExchangeUpgradeable|                                                  |OrderBookUpgradeable|
	//                       `-'                       `-'                 `-'              `-------------------------'                                                  `--------------------'
	//                       /|\                       /|\                 /|\
	//                        |                         |                   |
	//                       / \                       / \                 / \
	//
	/// @dev If `_token` is a zero address then the order will treat it as being WETH.
	/// @param _bidder Address that placed the bid.
	/// @param _tokenContractAddress The ERC721 asset contract address.
	/// @param _tokenId ID of the desired ERC721 asset.
	/// @param _expiration Time of order expiration defined as a UNIX timestamp.
	/// @param _offer The offered amount in wei for the given ERC721 asset.
	/// @param _token Alternative ERC20 asset used for payment.
	function exerciseBuyOrder(
		address payable _bidder,
		address _tokenContractAddress,
		uint256 _tokenId,
		uint256 _expiration,
		uint256 _offer,
		address _token
	) external payable override whenNotPaused nonReentrant {
		BuyOrder memory buyOrder = BuyOrder(payable(_msgSender()), _token, _expiration, _offer);

		_exerciseBuyOrder(_bidder, _tokenContractAddress, _tokenId, buyOrder);
	}

	//        ,-.
	//        `-'
	//        /|\
	//         |             ,-------------------------.                                           ,--------------------.
	//        / \            |ERC721ExchangeUpgradeable|                                           |OrderBookUpgradeable|
	//      Caller           `------------+------------'                                           `---------+----------'
	//        |     cancelBuyOrder()      |                                                                  |
	//        | ------------------------->|                                                                  |
	//        |                           |                                                                  |
	//        |                           ----.
	//        |                               | _cancelBuyOrder(msg.sender(), _tokenContractAddress, _tokenId)
	//        |                           <---'
	//        |                           |                                                                  |
	//        |                           ----.                                                              |
	//        |                               | cancel BuyOrder                                              |
	//        |                           <---'                                                              |
	//        |                           |                                                                  |
	//        |                           |                  cancelOrder(_orderKey, _order)                  |
	//        |                           |------------------------------------------------------------------>
	//        |                           |                                                                  |
	//        |                           ----.                                                              |
	//        |                               | emit BuyOrderCanceled()                                      |
	//        |                           <---'                                                              |
	//      Caller           ,------------+------------.                                           ,---------+----------.
	//        ,-.            |ERC721ExchangeUpgradeable|                                           |OrderBookUpgradeable|
	//        `-'            `-------------------------'                                           `--------------------'
	//        /|\
	//         |
	//        / \
	//
	/// @notice Cancels a given BuyOrder and emits "BuyOrderCanceled".
	/// @dev Can only be executed by the listed BuyOrder placer.
	/// @param _tokenContractAddress Address of the ERC721 token contract.
	/// @param _tokenId ID of the token being bid on.
	function cancelBuyOrder(address _tokenContractAddress, uint256 _tokenId) public payable override whenNotPaused {
		_cancelBuyOrder(_msgSender(), _tokenContractAddress, _tokenId);
	}

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                                  SELL ORDER VIEW FUNCTIONS                                                  ///
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice Finds the order matching the passed parameters. The returned order is possibly expired.
	/// @param _seller Address of the sell order owner.
	/// @param _tokenContractAddress Address of the ERC721 token contract.
	/// @param _tokenId ID of the token being sold.
	/// @return Struct containing all the order data.
	function getSellOrder(
		address _seller,
		address _tokenContractAddress,
		uint256 _tokenId
	) public view override whenNotSunset returns (SellOrder memory) {
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
	) public view override whenNotSunset returns (bool) {
		SellOrder memory sellOrder = getSellOrder(_seller, _tokenContractAddress, _tokenId);

		return 1 <= sellOrder.expiration;
	}

	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                                  BUY ORDER VIEW FUNCTIONS                                                  ///
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice Finds the order matching the passed parameters. The returned order is possibly expired.
	/// @param _buyer Address of the buy order creator.
	/// @param _tokenContractAddress Address of the ERC721 token contract.
	/// @param _tokenId ID of the token being bought.
	/// @return Struct containing all the order data.
	function getBuyOrder(
		address _buyer,
		address _tokenContractAddress,
		uint256 _tokenId
	) public view override whenNotSunset returns (BuyOrder memory) {
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
	) public view override whenNotSunset returns (bool) {
		BuyOrder memory buyOrder = getBuyOrder(_buyer, _tokenContractAddress, _tokenId);

		return 1 <= buyOrder.expiration;
	}

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                                                          INTERNAL ORDER MANIPULATION FUNCTIONS                                                                          ///
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @param _seller The address of the asset seller/owner.
	/// @param _tokenContractAddress The ERC721 asset contract address of the desired SellOrder.
	/// @param _tokenId ID of the desired ERC721 asset.
	/// @param _sellOrder Filled in SellOrder to be listed.
	function _bookSellOrder(
		address payable _seller,
		address _tokenContractAddress,
		uint256 _tokenId,
		SellOrder memory _sellOrder
	) private {
		if (sellOrderExists(_seller, _tokenContractAddress, _tokenId)) _cancelSellOrder(_seller, _tokenContractAddress, _tokenId);
		require(ERC165Checker.supportsInterface(_tokenContractAddress, INTERFACE_ID_ERC721), "CONTRACT_NOT_EIP721");
		require(block.timestamp < _sellOrder.expiration, "ORDER_EXPIRED");

		IERC721 erc721 = IERC721(_tokenContractAddress);

		require(erc721.ownerOf(_tokenId) == _seller, "ASSET_STORED_OWNER_NOT_CURRENT_OWNER");
		require(erc721.isApprovedForAll(_seller, address(this)) || erc721.getApproved(_tokenId) == address(this), "EXCHANGE_NOT_APPROVED_EIP721");
		require(
			_sellOrder.token == address(0) || _sellOrder.token == wETH || ERC165Checker.supportsInterface(_sellOrder.token, INTERFACE_ID_ERC20),
			"TOKEN_NOT_EIP20"
		);

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
	) private {
		require(sellOrderExists(_seller, _tokenContractAddress, _tokenId), "ORDER_NOT_EXISTS");

		SellOrder memory sellOrder = getSellOrder(_seller, _tokenContractAddress, _tokenId);

		require(ExchangeOrderComparisonLib.compareSellOrders(sellOrder, _sellOrder), "ORDER_PASSED_NOT_MATCH_STORED");
		if (block.timestamp > sellOrder.expiration) {
			_cancelSellOrder(_seller, _tokenContractAddress, _tokenId);
			revert("ORDER_EXPIRED");
		}

		IERC721 erc721 = IERC721(_tokenContractAddress);

		if (erc721.ownerOf(_tokenId) != _seller) {
			_cancelSellOrder(_seller, _tokenContractAddress, _tokenId);
			revert("ASSET_STORED_OWNER_NOT_CURRENT_OWNER");
		}
		if (!(erc721.isApprovedForAll(_seller, address(this)) || erc721.getApproved(_tokenId) == address(this))) {
			_cancelSellOrder(_seller, _tokenContractAddress, _tokenId);
			revert("EXCHANGE_NOT_APPROVED_EIP721");
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
	) private {
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
	) private {
		if (buyOrderExists(_buyer, _tokenContractAddress, _tokenId)) _cancelBuyOrder(_buyer, _tokenContractAddress, _tokenId);
		require(ERC165Checker.supportsInterface(_tokenContractAddress, INTERFACE_ID_ERC721), "CONTRACT_NOT_EIP721");
		require(block.timestamp < _buyOrder.expiration, "ORDER_EXPIRED");

		IERC721 erc721 = IERC721(_tokenContractAddress);

		require(erc721.ownerOf(_tokenId) == _buyOrder.owner, "ASSET_STORED_OWNER_NOT_CURRENT_OWNER");

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
	) private {
		require(buyOrderExists(_buyer, _tokenContractAddress, _tokenId), "ORDER_NOT_EXISTS");

		BuyOrder memory buyOrder = getBuyOrder(_buyer, _tokenContractAddress, _tokenId);
		address _token = buyOrder.token == address(0) ? wETH : buyOrder.token;

		require(ExchangeOrderComparisonLib.compareBuyOrders(_buyOrder, buyOrder), "ORDER_PASSED_NOT_MATCH_STORED");
		require(IERC20(_token).allowance(_buyer, address(this)) >= buyOrder.offer, "EXCHANGE_NOT_APPROVED_SUFFICIENTLY_EIP20");
		if (block.timestamp > buyOrder.expiration) {
			_cancelBuyOrder(_buyer, _tokenContractAddress, _tokenId);
			revert("ORDER_EXPIRED");
		}
		if (!(IERC721(_tokenContractAddress).ownerOf(_tokenId) == buyOrder.owner)) {
			_cancelBuyOrder(_buyer, _tokenContractAddress, _tokenId);
			revert("ASSET_STORED_OWNER_NOT_CURRENT_OWNER");
		}
		if (
			!(IERC721(_tokenContractAddress).isApprovedForAll(buyOrder.owner, address(this)) ||
				IERC721(_tokenContractAddress).getApproved(_tokenId) == address(this))
		) {
			_cancelBuyOrder(_buyer, _tokenContractAddress, _tokenId);
			revert("EXCHANGE_NOT_APPROVED_EIP721");
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
	) private {
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

	//////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                        SYSTEM FEE FUNCTIONS                                        ///
	//////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice Sets the new wallet to which all system fees get paid.
	/// @param _newSystemFeeWallet Address of the new system fee wallet.
	function setSystemFeeWallet(address payable _newSystemFeeWallet) external whenNotSunset onlyOwner {
		systemFeeWallet = _newSystemFeeWallet;
	}

	/// @notice Sets the new overall fee %. Example: 10 => 1%, 25 => 2,5%, 300 => 30%
	/// @param _newSystemFeePerMille New fee amount.
	function setSystemFeePerMille(uint256 _newSystemFeePerMille) external whenNotSunset onlyOwner {
		systemFeePerMille = _newSystemFeePerMille;
	}

	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                                      SHARED DEPLOYMENT FUNCTIONS                                                      ///
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice Sets the new RoyaltyEngine address.
	/// @param _newRoyaltyEngine New address for the RoyaltyEngine.
	function setRoyaltyEngine(address _newRoyaltyEngine) external whenNotSunset onlyOwner {
		royaltyEngine = _newRoyaltyEngine;
	}

	/// @notice Sets the new OrderBook address.
	/// @param _newOrderBook New address for the OrderBook.
	function setOrderBook(address _newOrderBook) external whenNotSunset onlyOwner {
		orderBook = _newOrderBook;
	}

	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                                ADMINISTRATIVE FUNCTIONS                                                ///
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice Pauses the execution and creation of sell orders on the exchange. Should only be used in emergencies.
	function pause() external whenNotSunset onlyOwner {
		_pause();
	}

	/// @notice Unpauses the execution and creation of sell orders on the exchange. Should only be used in emergencies.
	function unpause() external whenNotSunset onlyOwner {
		_unpause();
	}

	/// @notice Withdraws any Ether in-case it's ever accidentaly sent to the contract.
	function withdraw() public whenNotSunset onlyOwner {
		uint256 balance = address(this).balance;
		payable(msg.sender).transfer(balance);
	}

	//////////////////////////////////////////////////////////////////////////////////////
	///                                SUNSET FUNCTIONS                                ///
	//////////////////////////////////////////////////////////////////////////////////////

	/// @notice Sunsets the contract.
	function goTowardsTheSunset() public whenNotSunset onlyOwner {
		_pause();
		renounceOwnership();
		_sunset = true;
	}

	/// @notice Returns the status of the sunset.
	/// @return The status of sunset.
	function sunset() public view returns (bool) {
		return _sunset;
	}

	//////////////////////////////////////////////////////////////////////////////////////
	///                                SUNSET MODIFIERS                                ///
	//////////////////////////////////////////////////////////////////////////////////////

	/// @notice Throws if called when the contract is sunset.
	modifier whenNotSunset() {
		require(!sunset(), "SUNSET");
		_;
	}

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                          INFORMATIVE FUNCTIONS                                          ///
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @inheritdoc IERC721Exchange
	function version() public pure virtual override returns (uint256) {
		return 2;
	}

	///////////////////////////////////////////////////////////////////////////////////////////
	///                                  UTILITY FUNCTIONS                                  ///
	///////////////////////////////////////////////////////////////////////////////////////////

	/// @dev Increments a loop within a unchecked context.
	/// @param i The number to increment.
	/// @return The incremented number.
	function uncheckedInc(uint256 i) private pure returns (uint256) {
		unchecked {
			return i + 1;
		}
	}
}
