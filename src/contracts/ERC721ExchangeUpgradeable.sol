// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.2;
pragma abicoder v2;

import {IExchange} from "./interfaces/IExchange.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {ERC165CheckerUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SafeTransferLib} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import {ExchangeOrderComparisonLib} from "./libraries/ExchangeOrderComparisonLib.sol";

/// @author Nejc Drobnič
/// @dev Handles the creation and execution of sell orders as well as their storage.
contract ERC721ExchangeUpgradeable is
	Initializable,
	ContextUpgradeable,
	OwnableUpgradeable,
	PausableUpgradeable,
	ReentrancyGuardUpgradeable,
	IExchange
{
	using ERC165CheckerUpgradeable for address;

	/*///////////////////////////////////////////////////////////////
                                  CONSTANTS
    //////////////////////////////////////////////////////////////*/

	/// @dev Number used to check if the passed contract address correctly implements EIP721.
	bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;

	/// @dev Interface of the main canonical WETH deployment.
	IERC20 private WETH;

	/*///////////////////////////////////////////////////////////////
                                 SYSTEM FEE
    //////////////////////////////////////////////////////////////*/

	/// @dev The wallet address to which system fees get paid.
	address payable private _systemFeeWallet;

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
	mapping(bytes => SellOrder) private sellOrders;

	/// @dev Maps orderId (composed of `{buyerAddress}-{tokenContractAddress}-{tokenId}`) to the BuyOrder.
	mapping(bytes => BuyOrder) private buyOrders;

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
	) public override initializer {
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

	/// @param _tokenContractAddress The ERC721 asset contract address of the desired SellOrder.
	/// @param _tokenId ID of the desired ERC721 asset.
	/// @param _expiration Time of order expiration defined as a UNIX timestamp.
	/// @param _price The price in wei of the given ERC721 asset.
	function createSellOrder(
		address _tokenContractAddress,
		uint256 _tokenId,
		uint256 _expiration,
		uint256 _price
	) external override whenNotPaused {
		SellOrder memory sellOrder = SellOrder(_expiration, _price);

		_createSellOrder(payable(_msgSender()), _tokenContractAddress, _tokenId, sellOrder);
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
		uint256 _price
	) external override whenNotPaused {
		SellOrder memory sellOrder = SellOrder(_expiration, _price);

		_updateSellOrder(payable(_msgSender()), _tokenContractAddress, _tokenId, sellOrder);
	}

	/// @param _seller The seller address of the desired SellOrder.
	/// @param _tokenContractAddress The ERC721 asset contract address of the desired SellOrder.
	/// @param _tokenId ID of the desired ERC721 asset.
	/// @param _expiration Time of order expiration defined as a UNIX timestamp.
	/// @param _price The price in wei of the given ERC721 asset.
	/// @param _recipient The address of the ERC721 asset recipient.
	function executeSellOrder(
		address payable _seller,
		address _tokenContractAddress,
		uint256 _tokenId,
		uint256 _expiration,
		uint256 _price,
		address payable _recipient
	) external payable override whenNotPaused nonReentrant {
		require(msg.value >= _price, "Your transaction doesn't have the required payment.");

		SellOrder memory sellOrder = SellOrder(_expiration, _price);

		_executeSellOrder(_seller, _tokenContractAddress, _tokenId, sellOrder, SellOrderExecutionSenders(_recipient, _msgSender()));
	}

	/// @notice Cancels a given SellOrder and emits `SellOrderCanceled`.
	/// @notice Can only be executed by the listed SellOrder seller.
	/// @param _tokenContractAddress Address of the ERC721 token contract.
	/// @param _tokenId ID of the token being sold.
	function cancelSellOrder(address _tokenContractAddress, uint256 _tokenId) external override whenNotPaused {
		require(sellOrderExists(_msgSender(), _tokenContractAddress, _tokenId), "This sell order does not exist.");

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
	function createBuyOrder(
		address payable _owner,
		address _tokenContractAddress,
		uint256 _tokenId,
		uint256 _expiration,
		uint256 _offer
	) external whenNotPaused {
		require(
			WETH.allowance(_msgSender(), address(this)) >= _offer,
			"The ERC721Exchange contract is not approved to operate a sufficient amount of the buyers WETH."
		);

		BuyOrder memory buyOrder = BuyOrder(_owner, _expiration, _offer);

		_createBuyOrder(payable(_msgSender()), _tokenContractAddress, _tokenId, buyOrder);
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
		uint256 _offer
	) external whenNotPaused {
		require(
			WETH.allowance(_msgSender(), address(this)) >= _offer,
			"The ERC721Exchange contract is not approved to operate a sufficient amount of the buyers WETH."
		);

		BuyOrder memory buyOrder = BuyOrder(_owner, _expiration, _offer);

		_updateBuyOrder(payable(_msgSender()), _tokenContractAddress, _tokenId, buyOrder);
	}

	function acceptBuyOrder(
		address payable _bidder,
		address _tokenContractAddress,
		uint256 _tokenId,
		uint256 _expiration,
		uint256 _offer
	) external whenNotPaused {
		require(
			WETH.allowance(_bidder, address(this)) >= _offer,
			"The ERC721Exchange contract is not approved to operate a sufficient amount of the buyers WETH."
		);

		BuyOrder memory buyOrder = BuyOrder(payable(_msgSender()), _expiration, _offer);

		_acceptBuyOrder(_bidder, _tokenContractAddress, _tokenId, buyOrder);
	}

	/// @notice Cancels a given BuyOrder where the buyer is the msg sender and emits `BuyOrderCanceled`.
	/// @param _tokenContractAddress Address of the ERC721 token contract.
	/// @param _tokenId ID of the token being bought.
	function cancelBuyOrder(address _tokenContractAddress, uint256 _tokenId) external whenNotPaused {
		require(buyOrderExists(_msgSender(), _tokenContractAddress, _tokenId), "This buy order does not exist.");

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
	) public view returns (SellOrder memory) {
		require(sellOrderExists(_seller, _tokenContractAddress, _tokenId), "This sell order does not exist.");

		return sellOrders[_formOrderId(_seller, _tokenContractAddress, _tokenId)];
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
	) public view returns (bool) {
		SellOrder memory sellOrder = sellOrders[_formOrderId(_seller, _tokenContractAddress, _tokenId)];

		return 0 < sellOrder.expiration;
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
	) public view returns (BuyOrder memory) {
		require(buyOrderExists(_buyer, _tokenContractAddress, _tokenId), "This buy order does not exist.");

		return buyOrders[_formOrderId(_buyer, _tokenContractAddress, _tokenId)];
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
	) public view returns (bool) {
		BuyOrder memory buyOrder = buyOrders[_formOrderId(_buyer, _tokenContractAddress, _tokenId)];

		return 0 < buyOrder.expiration;
	}

	/*///////////////////////////////////////////////////////////////
                   INTERNAL ORDER MANIPULATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @param _seller The address of the asset seller/owner.
	/// @param _tokenContractAddress The ERC721 asset contract address of the desired SellOrder.
	/// @param _tokenId ID of the desired ERC721 asset.
	/// @param _sellOrder Filled in SellOrder to be listed.
	function _createSellOrder(
		address payable _seller,
		address _tokenContractAddress,
		uint256 _tokenId,
		SellOrder memory _sellOrder
	) internal {
		require(!sellOrderExists(_seller, _tokenContractAddress, _tokenId), "This order already exists.");

		require(_tokenContractAddress.supportsInterface(INTERFACE_ID_ERC721), "IS_NOT_721_TOKEN");

		require((block.timestamp < _sellOrder.expiration), "This sell order is expired.");

		IERC721 erc721 = IERC721(_tokenContractAddress);

		require((erc721.ownerOf(_tokenId) == _seller), "The seller does not own this ERC721 token.");

		require(erc721.isApprovedForAll(_seller, address(this)), "The ERC721Exchange contract is not approved to operate this ERC721 token.");

		sellOrders[_formOrderId(_seller, _tokenContractAddress, _tokenId)] = _sellOrder;
		emit SellOrderBooked(_seller, _tokenContractAddress, _tokenId, _sellOrder.expiration, _sellOrder.price);
	}

	/// @param _seller The address of the asset seller/owner.
	/// @param _tokenContractAddress The ERC721 asset contract address of the desired SellOrder.
	/// @param _tokenId ID of the desired ERC721 asset.
	/// @param _sellOrder Filled in SellOrder to replace/update existing.
	function _updateSellOrder(
		address payable _seller,
		address _tokenContractAddress,
		uint256 _tokenId,
		SellOrder memory _sellOrder
	) internal {
		require(sellOrderExists(_seller, _tokenContractAddress, _tokenId), "This order doesn't exists.");

		require(_tokenContractAddress.supportsInterface(INTERFACE_ID_ERC721), "IS_NOT_721_TOKEN");

		require((block.timestamp < _sellOrder.expiration), "This sell order is expired.");

		IERC721 erc721 = IERC721(_tokenContractAddress);

		require((erc721.ownerOf(_tokenId) == _seller), "The seller does not own this ERC721 token.");

		require(erc721.isApprovedForAll(_seller, address(this)), "The ERC721Exchange contract is not approved to operate this ERC721 token.");

		sellOrders[_formOrderId(_seller, _tokenContractAddress, _tokenId)] = _sellOrder;
		emit SellOrderUpdated(_seller, _tokenContractAddress, _tokenId, _sellOrder.expiration, _sellOrder.price);
	}

	/// @param _seller The address of the asset seller/owner.
	/// @param _tokenContractAddress The ERC721 asset contract address of the desired SellOrder.
	/// @param _tokenId ID of the desired ERC721 asset.
	/// @param _sellOrder Filled in SellOrder to be compared to the stored one.
	/// @param _senders Struct containing recipient and buyer address'.
	function _executeSellOrder(
		address payable _seller,
		address _tokenContractAddress,
		uint256 _tokenId,
		SellOrder memory _sellOrder,
		SellOrderExecutionSenders memory _senders
	) internal {
		SellOrder memory sellOrder = getSellOrder(_seller, _tokenContractAddress, _tokenId);

		if (!ExchangeOrderComparisonLib.compareSellOrders(sellOrder, _sellOrder)) {
			_cancelSellOrder(_seller, _tokenContractAddress, _tokenId);
			revert("Passed sell order data doesn't equal stored sell order data.");
		}

		if (!_tokenContractAddress.supportsInterface(INTERFACE_ID_ERC721)) {
			_cancelSellOrder(_seller, _tokenContractAddress, _tokenId);
			revert("IS_NOT_721_TOKEN");
		}

		if (!(block.timestamp < sellOrder.expiration)) {
			_cancelSellOrder(_seller, _tokenContractAddress, _tokenId);
			revert("This sell order is expired.");
		}

		IERC721 erc721 = IERC721(_tokenContractAddress);

		if (!(erc721.ownerOf(_tokenId) == _seller)) {
			_cancelSellOrder(_seller, _tokenContractAddress, _tokenId);
			revert("The seller does not own this ERC721 token.");
		}

		if (!erc721.isApprovedForAll(_seller, address(this))) {
			_cancelSellOrder(_seller, _tokenContractAddress, _tokenId);
			revert("The ERC721Exchange contract is not approved to operate this ERC721 token.");
		}

		uint256 royaltyPayout = (payoutPerMille[_tokenContractAddress] * msg.value) / 1000;
		uint256 systemFeePayout = (_systemFeePerMille * msg.value) / 1000;
		uint256 remainingPayout = msg.value - royaltyPayout - systemFeePayout;

		if (royaltyPayout > 0) {
			address payable royaltyPayoutAddress = collectionPayoutAddresses[_tokenContractAddress];
			SafeTransferLib.safeTransferETH(royaltyPayoutAddress, royaltyPayout);
		}

		SafeTransferLib.safeTransferETH(_systemFeeWallet, systemFeePayout);
		SafeTransferLib.safeTransferETH(_seller, remainingPayout);

		erc721.safeTransferFrom(_seller, _senders.recipient, _tokenId);

		_cancelSellOrder(_seller, _tokenContractAddress, _tokenId);
		emit SellOrderFufilled(_seller, _senders.recipient, _senders.buyer, _tokenContractAddress, _tokenId, sellOrder.price);
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
		delete (sellOrders[_formOrderId(_seller, _tokenContractAddress, _tokenId)]);

		emit SellOrderCanceled(_seller, _tokenContractAddress, _tokenId);
	}

	/// @param _buyer Address of the user placing the BuyOrder.
	/// @param _tokenContractAddress The ERC721 asset contract address of the desired asset.
	/// @param _tokenId ID of the desired ERC721 asset.
	/// @param _buyOrder Filled in BuyOrder to be listed.
	function _createBuyOrder(
		address payable _buyer,
		address _tokenContractAddress,
		uint256 _tokenId,
		BuyOrder memory _buyOrder
	) internal {
		require(!buyOrderExists(_buyer, _tokenContractAddress, _tokenId), "This order already exists.");

		require(_tokenContractAddress.supportsInterface(INTERFACE_ID_ERC721), "IS_NOT_721_TOKEN");

		require((block.timestamp < _buyOrder.expiration), "This sell order is expired.");

		IERC721 erc721 = IERC721(_tokenContractAddress);

		require((erc721.ownerOf(_tokenId) == _buyOrder.owner), 'The desired BuyOrder "owner" does not own this ERC721 token.');

		buyOrders[_formOrderId(_buyer, _tokenContractAddress, _tokenId)] = _buyOrder;
		emit BuyOrderBooked(_buyer, _buyOrder.owner, _tokenContractAddress, _tokenId, _buyOrder.expiration, _buyOrder.offer);
	}

	/// @param _buyer Address of the user placing the BuyOrder.
	/// @param _tokenContractAddress The ERC721 asset contract address of the desired asset.
	/// @param _tokenId ID of the desired ERC721 asset.
	/// @param _buyOrder Filled in BuyOrder to replace/update existing.
	function _updateBuyOrder(
		address payable _buyer,
		address _tokenContractAddress,
		uint256 _tokenId,
		BuyOrder memory _buyOrder
	) internal {
		require(buyOrderExists(_buyer, _tokenContractAddress, _tokenId), "This order doesn't exists.");

		require(_tokenContractAddress.supportsInterface(INTERFACE_ID_ERC721), "IS_NOT_721_TOKEN");

		require((block.timestamp < _buyOrder.expiration), "This buy order is expired.");

		IERC721 erc721 = IERC721(_tokenContractAddress);

		require((erc721.ownerOf(_tokenId) == _buyOrder.owner), 'The desired BuyOrder "owner" does not own this ERC721 token.');

		buyOrders[_formOrderId(_buyer, _tokenContractAddress, _tokenId)] = _buyOrder;
		emit BuyOrderUpdated(_buyer, _buyOrder.owner, _tokenContractAddress, _tokenId, _buyOrder.expiration, _buyOrder.offer);
	}

	/// @param _buyer Address of the user placing the BuyOrder.
	/// @param _tokenContractAddress The ERC721 asset contract address of the desired asset.
	/// @param _tokenId ID of the desired ERC721 asset.
	/// @param _buyOrder Filled in BuyOrder to be compared to the stored one.
	function _acceptBuyOrder(
		address payable _buyer,
		address _tokenContractAddress,
		uint256 _tokenId,
		BuyOrder memory _buyOrder
	) internal {
		BuyOrder memory buyOrder = getBuyOrder(_buyer, _tokenContractAddress, _tokenId);

		if (!ExchangeOrderComparisonLib.compareBuyOrders(_buyOrder, buyOrder)) {
			_cancelBuyOrder(_buyer, _tokenContractAddress, _tokenId);
			revert("Passed buy order data doesn't equal stored buy order data.");
		}

		if (!_tokenContractAddress.supportsInterface(INTERFACE_ID_ERC721)) {
			_cancelBuyOrder(_buyer, _tokenContractAddress, _tokenId);
			revert("IS_NOT_721_TOKEN");
		}

		if (!(block.timestamp < buyOrder.expiration)) {
			_cancelBuyOrder(_buyer, _tokenContractAddress, _tokenId);
			revert("This buy order has expired.");
		}

		IERC721 erc721 = IERC721(_tokenContractAddress);

		if (!(erc721.ownerOf(_tokenId) == buyOrder.owner)) {
			_cancelBuyOrder(_buyer, _tokenContractAddress, _tokenId);
			revert('The desired BuyOrder "owner" does not own this ERC721 token.');
		}

		if (!erc721.isApprovedForAll(buyOrder.owner, address(this))) {
			_cancelBuyOrder(_buyer, _tokenContractAddress, _tokenId);
			revert("The ERC721Exchange contract is not approved to operate this ERC721 token.");
		}

		uint256 royaltyPayout = (payoutPerMille[_tokenContractAddress] * buyOrder.offer) / 1000;
		uint256 systemFeePayout = (_systemFeePerMille * buyOrder.offer) / 1000;
		uint256 remainingPayout = buyOrder.offer - royaltyPayout - systemFeePayout;

		if (royaltyPayout > 0) {
			address payable royaltyPayoutAddress = collectionPayoutAddresses[_tokenContractAddress];
			WETH.transferFrom(_buyer, royaltyPayoutAddress, royaltyPayout);
		}

		WETH.transferFrom(_buyer, _systemFeeWallet, systemFeePayout);
		WETH.transferFrom(_buyer, buyOrder.owner, remainingPayout);

		erc721.safeTransferFrom(buyOrder.owner, _buyer, _tokenId);

		_cancelBuyOrder(_buyer, _tokenContractAddress, _tokenId);
		emit BuyOrderAccepted(_buyer, buyOrder.owner, _tokenContractAddress, _tokenId, buyOrder.offer);
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
		delete (buyOrders[_formOrderId(_buyer, _tokenContractAddress, _tokenId)]);

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
		return abi.encodePacked(_userAddress, "-", _tokenContractAddress, "-", _tokenId);
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
			string(abi.encodePacked("Royalty must be between 0 and ", _maxRoyaltyPerMille / 10, "%"))
		);
		require(_tokenContractAddress.supportsInterface(INTERFACE_ID_ERC721), "IS_NOT_721_TOKEN");

		if (!(_msgSender() == owner())) {
			Ownable ownableNFTContract = Ownable(_tokenContractAddress);
			require(_msgSender() == ownableNFTContract.owner(), "ADDRESS_NOT_AUTHORIZED");
		}

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
	function version() external pure virtual override returns (bytes memory) {
		uint256 major = 1;
		uint256 minor = 0;
		uint256 patch = 3;
		return abi.encode(major, minor, patch);
	}
}
