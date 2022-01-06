// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.2;

import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";


/// @author Nejc Drobnič
/// @dev Handles the creation and execution of sell orders as well as their storage.
contract ERC721Market is Pausable, ReentrancyGuard {
    using ERC165Checker for address;

    /*///////////////////////////////////////////////////////////////
                                  CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Number used to check if the passed contract address correctly implements EIP721.
    bytes4 private InterfaceId_IERC721 = 0x80ac58cd;

    /*///////////////////////////////////////////////////////////////
                                ORDER STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(bytes => SellOrder) sellOrders;

    /// @param expiration Time of order expiration defined as a UNIX timestamp.
    /// @param price The price of the given ERC721 asset. Unit is wei.
    struct SellOrder {
        address payable seller;
        address tokenContractAddress;
        uint256 tokenId;
        uint256 expiration;
        uint256 price;
    }

    function createSellOrder(address tokenContractAddress, uint256 tokenId, uint256 expiration, uint256 price) external whenNotPaused {
        SellOrder memory sellOrder = SellOrder(
            payable(msg.sender),
            tokenContractAddress,
            tokenId,
            expiration,
            price
        );

        _createSellOrder(sellOrder);
    }

    function _createSellOrder(SellOrder memory sellOrder) internal {
        require(!sellOrderExists(sellOrder.seller, sellOrder.tokenContractAddress, sellOrder.tokenId), "This order already exists.");

        require(sellOrder.tokenContractAddress.supportsInterface(InterfaceId_IERC721), "IS_NOT_721_TOKEN");

        require((block.timestamp < sellOrder.expiration), "This sell order has expired.");

        IERC721 erc721 = IERC721(sellOrder.tokenContractAddress);

        require((erc721.ownerOf(sellOrder.tokenId) == sellOrder.seller), "The seller does not own this ERC721 token.");

        require(erc721.getApproved(sellOrder.tokenId) == address(this), "The ERC721Market contract is not approved to operate this ERC721 token.");

        sellOrders[formOrderId(sellOrder.seller, sellOrder.tokenContractAddress, sellOrder.tokenId)] = sellOrder;
    }

    /// @notice This relies on the fact that for one we treat expired orders as non-existant and that the default for structs in a mapping is that they have all their values set to 0.
    /// So if a order doesn't exist it will have an expiration of 0 which is in this context the same as being expired.
    function sellOrderExists(address seller, address tokenContractAddress, uint256 tokenId) public view returns (bool) {
        SellOrder memory sellOrder = sellOrders[formOrderId(seller, tokenContractAddress, tokenId)];

        return block.timestamp < sellOrder.expiration;
    }

    function cancelSellOrder(address seller, address tokenContractAddress, uint256 tokenId) external {
        require(msg.sender == seller, "You are not the sell order seller.");

        delete(sellOrders[formOrderId(seller, tokenContractAddress, tokenId)]);
    }

    function formOrderId(address user, address tokenContractAddress, uint256 tokenId) public pure returns (bytes memory) {
        return abi.encodePacked(user, "-", tokenContractAddress, "-", tokenId);
    }
}
