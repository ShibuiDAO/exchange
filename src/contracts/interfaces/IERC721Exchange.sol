// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

/// @author ShibuiDAO
interface IERC721Exchange {
	/*///////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

	/// @notice Emitted when `bookSellOrder` is called.
	/// @param seller Address of the ERC721 asset owner and seller.
	/// @param tokenContractAddress Address of the ERC721 token contract.
	/// @param tokenId ID of ERC721 asset for sale.
	/// @param expiration Time of order expiration defined as a UNIX timestamp.
	/// @param price The price in wei of the given ERC721 asset.
	/// @param token Alternative ERC20 asset used for payment.
	event SellOrderBooked(
		address indexed seller,
		address indexed tokenContractAddress,
		uint256 indexed tokenId,
		uint256 expiration,
		uint256 price,
		address token
	);

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
	/// @param token Alternative ERC20 asset used for payment.
	event SellOrderExercised(
		address indexed seller,
		address recipient,
		address buyer,
		address indexed tokenContractAddress,
		uint256 indexed tokenId,
		uint256 price,
		address token
	);

	/// @notice Emitted when `bookBuyOrder` is called.
	/// @param buyer Address of the ERC721 asset bidder.
	/// @param owner Address of the current ERC721 asset owner.
	/// @param tokenContractAddress Address of the ERC721 token contract.
	/// @param tokenId ID of ERC721 asset for sale.
	/// @param expiration Time of order expiration defined as a UNIX timestamp.
	/// @param offer The offer in wei for the given ERC721 asset.
	/// @param token Alternative ERC20 asset used for payment.
	event BuyOrderBooked(
		address indexed buyer,
		address owner,
		address indexed tokenContractAddress,
		uint256 indexed tokenId,
		uint256 expiration,
		uint256 offer,
		address token
	);

	/// @notice Emitted when `cancelBuyOrder` is call edor when `exerciseBuyOrder` completes.
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
	/// @param token Alternative ERC20 asset used for payment.
	event BuyOrderExercised(
		address buyer,
		address indexed seller,
		address indexed tokenContractAddress,
		uint256 indexed tokenId,
		uint256 offer,
		address token
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
	error ExchangeNotApprovedSufficientlyEIP20(address token, uint256 amount);
	error ExchangeNotApprovedEIP721();
	error ContractNotEIP721();
	error TokenNotEIP20(address token);
	error SenderNotAuthorised();

	/*///////////////////////////////////////////////////////////////
                                ORDER STORAGE
    //////////////////////////////////////////////////////////////*/

	/// @param expiration Time of order expiration defined as a UNIX timestamp.
	/// @param price The price in wei of the given ERC721 asset.
	/// @param token Alternative ERC20 asset used for payment.
	struct SellOrder {
		uint256 expiration;
		uint256 price;
		address token;
	}

	/// @param owner Address of the current ERC721 asset owner.
	/// @param token Alternative ERC20 asset used for payment.
	/// @param expiration Time of order expiration defined as a UNIX timestamp.
	/// @param offer The offer in wei for the given ERC721 asset.
	struct BuyOrder {
		address payable owner;
		address token;
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
	/// @param _maxRoyaltyPerMille The overall maximum royalty fee %. Example: 10 => 1%, 25 => 2,5%, 300 => 30%
	/// @param _wethAddress Address of the canonical WETH deployment.
	// solhint-disable-next-line func-name-mixedcase
	function __ERC721Exchange_init(
		uint256 _maxRoyaltyPerMille,
		address _royaltyEngine,
		address _orderBook,
		address _wethAddress
	) external;

	/*///////////////////////////////////////////////////////////////
                   PUBLIC SELL ORDER MANIPULATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
	) external;

	/// @notice Updates/overwrites existing SellOrder.
	/// @param _tokenContractAddress The ERC721 asset contract address of the desired SellOrder.
	/// @param _tokenId ID of the desired ERC721 asset.
	/// @param _expiration Time of order expiration defined as a UNIX timestamp.
	/// @param _price The price in wei of the given ERC721 asset.
	/// @param _token Alternative ERC20 asset used for payment.
	function updateSellOrder(
		address _tokenContractAddress,
		uint256 _tokenId,
		uint256 _expiration,
		uint256 _price,
		address _token
	) external;

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
		address payable _recipient,
		address _token
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
	function version() external returns (uint256);
}
