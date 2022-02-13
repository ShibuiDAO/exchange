// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

import {IERC165} from "@shibuidao/solid/src/utils/interfaces/IERC165.sol";

/// @author ShibuiDAO
interface IERC721Exchange is IERC165 {
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

	error ORDER_EXISTS(address account, address tokenContractAddress, uint256 tokenId);
	error ORDER_NOT_EXISTS(address account, address tokenContractAddress, uint256 tokenId);
	error ORDER_EXPIRED(uint256 expiration, uint256 time);
	error ORDER_PASSED_NOT_MATCH_STORED();
	error ASSET_STORED_OWNER_NOT_CURRENT_OWNER();
	error PAYMENT_MISSING(uint256 price, uint256 payment);
	error EXCHANGE_NOT_APPROVED_SUFFICIENTLY_EIP20(address token, uint256 amount);
	error EXCHANGE_NOT_APPROVED_EIP721(address tokenContractAddress, uint256 tokenId);
	error CONTRACT_NOT_EIP721();
	error TOKEN_NOT_EIP20(address token);

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
	) external payable;

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
	) external payable;

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
	function cancelSellOrder(address _tokenContractAddress, uint256 _tokenId) external payable;

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
	) external payable;

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
	) external payable;

	function exerciseBuyOrder(
		address payable _bidder,
		address _tokenContractAddress,
		uint256 _tokenId,
		uint256 _expiration,
		uint256 _offer,
		address _token
	) external payable;

	/// @notice Cancels a given BuyOrder where the buyer is the msg sender and emits `BuyOrderCanceled`.
	/// @param _tokenContractAddress Address of the ERC721 token contract.
	/// @param _tokenId ID of the token being bought.
	function cancelBuyOrder(address _tokenContractAddress, uint256 _tokenId) external payable;

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
	) external view returns (SellOrder memory);

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
	) external view returns (bool);

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
	) external view returns (BuyOrder memory);

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
	) external view returns (bool);

	/*///////////////////////////////////////////////////////////////
                        INFORMATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @return The current exchange version.
	function version() external returns (uint256);
}
