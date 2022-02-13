// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract TestERC721 is Ownable, ERC721, ERC721Enumerable {
	constructor() ERC721("TestERC721", "TST") {}

	function mint(address to, uint256 tokenId) public virtual onlyOwner {
		_safeMint(to, tokenId);
	}

	function mintNext(address to) public virtual onlyOwner {
		uint256 supply = totalSupply();
		mint(to, supply + 1);
	}

	function _beforeTokenTransfer(
		address from,
		address to,
		uint256 tokenId
	) internal override(ERC721, ERC721Enumerable) {
		super._beforeTokenTransfer(from, to, tokenId);
	}

	function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
		return super.supportsInterface(interfaceId);
	}
}
