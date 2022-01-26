// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.11;
pragma abicoder v2;

interface IExchange {
	/*///////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

	/// @notice Emitted when `bookSellOrder` is called.
	/// @param seller Address of the ERC721 asset owner and seller.
	/// @param tokenContractAddress Address of the ERC721 token contract.
	/// @param tokenId ID of ERC721 asset for sale.
	/// @param expiration Time of order expiration defined as a UNIX timestamp.
	/// @param price The price in wei of the given ERC721 asset.
	event SellOrderBooked(address indexed seller, address indexed tokenContractAddress, uint256 indexed tokenId, uint256 expiration, uint256 price);

	/// @notice Emitted when `cancelSellOrder` is called or when `exerciseSellOrder` completes.
	/// @param seller Address of SellOrder seller.
	/// @param tokenContractAddress Address of the ERC721 token contract.
	/// @param tokenId ID of canceled ERC721 asset.
	event SellOrderCanceled(address indexed seller, address indexed tokenContractAddress, uint256 indexed tokenId);

	/// @notice Emitted when `exerciseSellOrder` is called.
	/// @param seller Address of the previous ERC721 asset owner and seller.
	/// @param recipient Address of the new ERC721 asset owner and buyer.
	/// @param tokenContractAddress Address of the ERC721 token contract.
	/// @param tokenId ID of the bought ERC721 asset.
	/// @param price The price in wei at which the ERC721 asset was bought.
	event SellOrderExercised(
		address indexed seller,
		address recipient,
		address buyer,
		address indexed tokenContractAddress,
		uint256 indexed tokenId,
		uint256 price
	);

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
                                    ERRORS
    //////////////////////////////////////////////////////////////*/

	error OrderExists();
	error OrderNotExists();
	error OrderExpired();
	error OrderPassedNotMatchStored();
	error AssetStoredOwnerNotCurrentOwner();
	error PaymentMissing();
	error ExchangeNotApprovedWETH();
	error ExchangeNotApprovedEIP721();
	error ContractNotEIP721();
	error RoyaltyNotWithinRange(uint256 min, uint256 max);
	error SenderNotAuthorised();

	/*///////////////////////////////////////////////////////////////
                                ORDER STORAGE
    //////////////////////////////////////////////////////////////*/

	/// @param expiration Time of order expiration defined as a UNIX timestamp.
	/// @param price The price in wei of the given ERC721 asset.
	struct SellOrder {
		uint256 expiration;
		uint256 price;
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
	) external;

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
		uint256 _price
	) external;

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
	) external;

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
		address payable _recipient
	) external payable;

	/// @notice Cancels a given SellOrder and emits `SellOrderCanceled`.
	/// @notice Can only be executed by the listed SellOrder seller.
	/// @param _tokenContractAddress Address of the ERC721 token contract.
	/// @param _tokenId ID of the token being sold.
	function cancelSellOrder(address _tokenContractAddress, uint256 _tokenId) external;

	/*///////////////////////////////////////////////////////////////
                        INFORMATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @return The current exchange version.
	function version() external returns (bytes memory);
}
