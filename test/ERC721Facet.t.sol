// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";

import "./helpers/DiamondUtils.sol";
import "./helpers/DiamondDeployer.sol";

contract ERC721FacetTest is DiamondDeployer {
    function testERC721Facet_Name() public {
        assertEq(ERC721_Diamond.name(), name);
    }

    function testERC721Facet_Symbol() public {
        assertEq(ERC721_Diamond.symbol(), symbol);
    }

    function testERC721Facet_Mint() public {
        vm.prank(user1);
        uint256 tokenId = 211;
        uint256 tokenId2 = 215;
        uint256 tokenId3 = 202345;
        uint256 tokenId4 = 2155;
        uint256 tokenId5 = 20256;

        ERC721_Diamond.mint(user1, tokenId);
        ERC721_Diamond.mint(user1, tokenId2);
        ERC721_Diamond.mint(user1, tokenId3);
        ERC721_Diamond.mint(user1, tokenId4);
        ERC721_Diamond.mint(user1, tokenId5);

        assertEq(ERC721_Diamond.balanceOf(user1), 5);
    }

    function testERC721Facet_Balances() public {
        testERC721Facet_Mint();

        assertEq(ERC721_Diamond.balanceOf(user1), 5);
    }

    function testERC721Facet_Owner() public {
        testERC721Facet_Mint();

        assertEq(ERC721_Diamond.ownerOf(211), user1);

        uint256 tokenId = 21586;

        ERC721_Diamond.mint(user2, tokenId);

        assertEq(ERC721_Diamond.ownerOf(tokenId), user2);
    }

    function testERC721Facet_tokenApproval() public {
        uint256 tokenId = 210;
        ERC721_Diamond.mint(user1, tokenId);
        vm.prank(user1);
        ERC721_Diamond.approve(user2, tokenId);

        assertEq(ERC721_Diamond.getApproved(210), user2);
    }

    function testERC721Facet_isApprovedForAll() public {
        uint256 tokenId = 211;
        uint256 tokenId2 = 215;
        ERC721_Diamond.mint(user1, tokenId);
        ERC721_Diamond.mint(user1, tokenId2);

        vm.prank(user1);
        ERC721_Diamond.setApprovalForAll(user2, true);

        assertTrue(ERC721_Diamond.isApprovedForAll(user1, user2));
    }

    function testERC721Facet_transferFrom() public {
        testERC721Facet_Mint();

        vm.prank(user1);
        ERC721_Diamond.setApprovalForAll(address(this), true);

        ERC721_Diamond.transferFrom(user1, user2, 215);

        assertEq(ERC721_Diamond.balanceOf(user1), 4);
        assertEq(ERC721_Diamond.balanceOf(user2), 1);

        assertEq(ERC721_Diamond.ownerOf(215), user2);
        assertEq(ERC721_Diamond.ownerOf(20256), user1);
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
