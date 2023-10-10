// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/ERC721Facet.sol";
import "./helpers/DiamondUtils.sol";
import "../contracts/facets/NFTMarketPlaceFacet.sol";

contract DiamondDeployer is DiamondUtils, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupeFacet;
    OwnershipFacet ownerFacet;
    ERC721Facet erc721Facet;
    ERC721Facet ERC721_Diamond;

    MarketPlaceFacet marketPlaceFacet;

    string name = "Bridge Waters Associates";
    string symbol = "BWA";
    address NftAddress;

    address user1 = vm.addr(0x1);
    address user2 = vm.addr(0x2);

    function setUp() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(
            address(this),
            address(dCutFacet),
            name,
            symbol,
            NftAddress
        );
        dLoupeFacet = new DiamondLoupeFacet();
        ownerFacet = new OwnershipFacet();
        erc721Facet = new ERC721Facet();

        marketPlaceFacet = new MarketPlaceFacet(NftAddress);

        ERC721_Diamond = ERC721Facet(address(diamond));
        //build cut struct
        FacetCut[] memory cut = new FacetCut[](3);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupeFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );

        // erc721Facet
        cut[2] = (
            FacetCut({
                facetAddress: address(erc721Facet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("ERC721Facet")
            })
        );

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();
    }

    function testCreateListing() public {
        // vm.startPrank(creator1);
        switchSigner(creator1);
        //bridgeWaterNFT.mint(creator1, 2);
        bridgeWaterNFT.setApprovalForAll(address(bridgeWaters), true);

        bytes memory _signature = constructSig(
            address(bridgeWaterNFT),
            2,
            2 ether,
            2 days,
            creator1,
            privateKey1
        );
        listingInfo.signature = _signature;
        listingInfo.seller = creator1;
        listingInfo.tokenId = 2;

        currentListingId = bridgeWaters.createListing(
            listingInfo.token,
            listingInfo.tokenId,
            listingInfo.price,
            listingInfo.signature,
            listingInfo.deadline,
            listingInfo.seller,
            listingInfo.isActive = true
        );

        assertEq(listingInfo.token, address(bridgeWaterNFT));
        assertEq(listingInfo.tokenId, 2);
        assertEq(listingInfo.price, 2 ether);
        assertEq(listingInfo.signature, _signature);
        assertEq(listingInfo.deadline, 2 days);
        assertEq(listingInfo.seller, creator1);
        assertEq(listingInfo.isActive, true);
    }

    function _createListing() internal returns (uint256 _listingId) {
        // listingInfo.seller = creator1;
        _listingId = bridgeWaters.createListing(
            listingInfo.token,
            listingInfo.tokenId,
            listingInfo.price,
            listingInfo.signature,
            listingInfo.deadline,
            listingInfo.seller,
            listingInfo.isActive
        );
    }

    function testCreateListing_OnlyOwnerCanCreateListing() public {
        listingInfo.seller = spender;
        switchSigner(spender);

        vm.expectRevert(BridgeWatersMarketplace.NotOwner.selector);
        _createListing();
    }

    function testCreateListing_NotApprovedNFTForUser() public {
        switchSigner(creator1);

        vm.expectRevert(BridgeWatersMarketplace.NotApproved.selector);
        _createListing();
    }

    function testCreateListing_MinimumPriceTooLow() public {
        switchSigner(creator1);

        bridgeWaterNFT.setApprovalForAll(address(bridgeWaters), true);

        listingInfo.price = 0;

        vm.expectRevert(BridgeWatersMarketplace.MinPriceTooLow.selector);
        _createListing();
    }

    function testCreateListing_DeadlineTooSoon() public {
        switchSigner(creator1);
        //bridgeWaterNFT.mint(creator1, 2);
        bridgeWaterNFT.setApprovalForAll(address(bridgeWaters), true);

        bytes memory _signature = constructSig(
            address(bridgeWaterNFT),
            2,
            1 ether,
            2 days,
            creator1,
            privateKey1
        );
        // vm.warp(2 days);
        listingInfo.signature = _signature;
        listingInfo.seller = creator1;
        listingInfo.tokenId = 2;
        listingInfo.deadline = 0 minutes;

        vm.expectRevert(BridgeWatersMarketplace.DeadlineTooSoon.selector);
        bridgeWaters.createListing(
            listingInfo.token,
            listingInfo.tokenId,
            listingInfo.price,
            listingInfo.signature,
            listingInfo.deadline,
            listingInfo.seller,
            listingInfo.isActive
        );
    }

    function testCreateListing_MinimumDurationNotMet() public {
        switchSigner(creator1);

        bridgeWaterNFT.setApprovalForAll(address(bridgeWaters), true);

        listingInfo.deadline = 30 minutes;

        vm.expectRevert(BridgeWatersMarketplace.MinDurationNotMet.selector);
        _createListing();
    }

    function testCreateListing_InValidSignature() public {
        switchSigner(creator1);

        bridgeWaterNFT.setApprovalForAll(address(bridgeWaters), true);

        listingInfo.deadline = uint88(block.timestamp + 3 hours);
        listingInfo.seller = creator1;
        bytes memory _signature = constructSig(
            address(bridgeWaterNFT),
            2,
            3 ether,
            3 days,
            creator1,
            privateKey1
        );
        listingInfo.signature = _signature;
        vm.expectRevert(BridgeWatersMarketplace.InValidSignature.selector);
        bridgeWaters.createListing(
            listingInfo.token,
            listingInfo.tokenId,
            listingInfo.price,
            listingInfo.signature,
            listingInfo.deadline,
            listingInfo.seller,
            listingInfo.isActive
        );
    }

    // function _testCreateListing_Emitevent_ListingCreated() public {
    //  switchSigner(creator1);

    //     vm.expectEmit();

    //     emit ListingCreated(currentListingId);

    //     _createListing();
    // }

    // executeListing

    function _buyListing() internal {
        switchSigner(creator1);
        bridgeWaters.buyListing(currentListingId);
    }

    function testBuyListing_ListingDoesNotExist() public {
        testCreateListing();

        vm.expectRevert(BridgeWatersMarketplace.ListingDoesNotExist.selector);

        _buyListing();
    }

    function testBuyListing_ListingExpired() public {
        testCreateListing();

        vm.warp(1641070800);

        vm.expectRevert(BridgeWatersMarketplace.ListingExpired.selector);
        // When listing expires, the listingId becomes zero

        bridgeWaters.buyListing(0);
    }

    function testBuyListing_ListingNotActive() public {
        switchSigner(creator1);
        // bridgeWaterNFT.mint(creator1, 2);
        bridgeWaterNFT.setApprovalForAll(address(bridgeWaters), true);

        bytes memory _signature = constructSig(
            address(bridgeWaterNFT),
            2,
            2 ether,
            2 days,
            creator1,
            privateKey1
        );
        listingInfo.signature = _signature;
        listingInfo.seller = creator1;
        listingInfo.tokenId = 2;

        bridgeWaters.createListing(
            listingInfo.token,
            listingInfo.tokenId,
            listingInfo.price,
            listingInfo.signature,
            listingInfo.deadline,
            listingInfo.seller,
            listingInfo.isActive = false
        );

        // vm.warp(1641070800);

        vm.expectRevert(BridgeWatersMarketplace.ListingNotActive.selector);
        // bridgeWaters.buyListing(_currentListingId);

        _buyListing();
    }

    function testBuyListing_PriceMismatch() public {
        _createBuyListing();

        vm.expectRevert(
            abi.encodeWithSelector(
                BridgeWatersMarketplace.PriceMismatch.selector,
                listingInfo.price
            )
        );

        bridgeWaters.buyListing{value: 3 ether}(currentListingId);
    }

    function testBuyListing_PriceNotMet() public {
        _createBuyListing();

        vm.expectRevert(
            abi.encodeWithSelector(
                BridgeWatersMarketplace.PriceNotMet.selector,
                (listingInfo.price - 1 ether)
            )
        );

        bridgeWaters.buyListing{value: 1 ether}(currentListingId);
    }

    function _createBuyListing() internal {
        switchSigner(creator1);
        // bridgeWaterNFT.mint(creator1, 2);
        bridgeWaterNFT.setApprovalForAll(address(bridgeWaters), true);

        bytes memory _signature = constructSig(
            address(bridgeWaterNFT),
            2,
            2 ether,
            2 days,
            creator1,
            privateKey1
        );
        listingInfo.signature = _signature;
        listingInfo.seller = creator1;
        listingInfo.tokenId = 2;

        bridgeWaters.createListing(
            listingInfo.token,
            listingInfo.tokenId,
            listingInfo.price,
            listingInfo.signature,
            listingInfo.deadline,
            listingInfo.seller,
            listingInfo.isActive
        );
    }

    // UPDATE LISTING

    function _updateListing() internal {
        switchSigner(creator1);
        bridgeWaters.updateListing(
            currentListingId,
            3 ether,
            listingInfo.isActive
        );
    }

    function testUpdateListing_ListingDoesNotExist() public {
        switchSigner(creator1);
        // bridgeWaterNFT.mint(creator1, 2);
        bridgeWaterNFT.setApprovalForAll(address(bridgeWaters), true);

        bytes memory _signature = constructSig(
            address(bridgeWaterNFT),
            2,
            2 ether,
            2 days,
            creator1,
            privateKey1
        );
        listingInfo.signature = _signature;
        listingInfo.seller = creator1;
        listingInfo.tokenId = 2;

        currentListingId = bridgeWaters.createListing(
            listingInfo.token,
            listingInfo.tokenId,
            listingInfo.price,
            listingInfo.signature,
            listingInfo.deadline,
            listingInfo.seller,
            listingInfo.isActive
        );

        vm.expectRevert(BridgeWatersMarketplace.ListingDoesNotExist.selector);

        bridgeWaters.updateListing(currentListingId, 0, false);
    }

    function testUpdateListing_NotOwner() public {
        switchSigner(creator1);
        bridgeWaterNFT.mint(creator1, 3);
        bridgeWaterNFT.setApprovalForAll(address(bridgeWaters), true);

        bytes memory _signature = constructSig(
            address(bridgeWaterNFT),
            2,
            2 ether,
            2 days,
            creator1,
            privateKey1
        );
        listingInfo.signature = _signature;
        listingInfo.seller = creator1;
        //listingInfo.tokenId

        uint256 _currentListingId = bridgeWaters.createListing(
            listingInfo.token,
            listingInfo.tokenId,
            listingInfo.price,
            listingInfo.signature,
            listingInfo.deadline,
            listingInfo.seller,
            listingInfo.isActive
        );

        vm.startPrank(spender);

        vm.expectRevert(BridgeWatersMarketplace.NotOwner.selector);

        bridgeWaters.updateListing(_currentListingId, 1 ether, true);
    }

    function testUpdateListing() public {
        listingInfo.seller = creator1;

        switchSigner(creator1);
        //bridgeWaterNFT.mint(creator1, 2);
        bridgeWaterNFT.setApprovalForAll(address(bridgeWaters), true);

        bytes memory _signature = constructSig(
            address(bridgeWaterNFT),
            2,
            2 ether,
            2 days,
            creator1,
            privateKey1
        );
        listingInfo.signature = _signature;

        listingInfo.tokenId = 2;

        currentListingId = bridgeWaters.createListing(
            listingInfo.token,
            listingInfo.tokenId,
            listingInfo.price,
            listingInfo.signature,
            listingInfo.deadline,
            listingInfo.seller,
            listingInfo.isActive
        );

        uint256 newPrice = 3 ether;

        assertEq(
            bridgeWaterNFT.ownerOf(listingInfo.tokenId),
            address(bridgeWaters)
        );

        bridgeWaters.updateListing(
            currentListingId,
            newPrice,
            listingInfo.isActive
        );

        listingInfo = bridgeWaters.getListing(currentListingId);

        assertEq(listingInfo.price, newPrice);
        assertEq(listingInfo.isActive, true);
    }

    function testBuyListing() public {
        switchSigner(creator1);

        vm.warp(1641070800);

        listingInfo.deadline = uint88(block.timestamp + 120 minutes);

        bridgeWaterNFT.setApprovalForAll(address(bridgeWaters), true);

        listingInfo.signature = constructSig(
            listingInfo.token,
            listingInfo.tokenId,
            listingInfo.price,
            listingInfo.deadline,
            listingInfo.seller,
            privateKey1
        );

        currentListingId = bridgeWaters.createListing(
            listingInfo.token,
            listingInfo.tokenId,
            listingInfo.price,
            listingInfo.signature,
            listingInfo.deadline,
            listingInfo.seller,
            listingInfo.isActive
        );

        switchSigner(spender);
        //vm.warp(1641070800);
        bridgeWaters.buyListing{value: listingInfo.price}(currentListingId);
        assertEq(bridgeWaterNFT.ownerOf(currentListingId), spender);
    }

    function testERC721Facet_Name() public {
        assertEq(ERC721_Diamond.name(), name);
    }

    function testERC721Facet_Symbol() public {
        assertEq(ERC721_Diamond.symbol(), symbol);
    }

    function testERC721Facet_Balances() public {
        vm.prank(user1);

        uint256 tokenId = 213;
        uint256 tokenId2 = 123;

        ERC721_Diamond.mint(user1, tokenId);

        ERC721_Diamond.mint(user1, tokenId2);

        assertEq(ERC721_Diamond.balanceOf(user1), 2);
    }

    function testERC721Facet_Owner() public {
        vm.prank(user1);

        uint256 tokenId = 213;
        uint256 tokenId2 = 12345;

        ERC721_Diamond.mint(user1, tokenId);

        assertEq(ERC721_Diamond.ownerOf(tokenId), user1);

        vm.prank(user2);
        ERC721_Diamond.mint(user2, tokenId2);

        assertEq(ERC721_Diamond.ownerOf(tokenId2), user2);
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
