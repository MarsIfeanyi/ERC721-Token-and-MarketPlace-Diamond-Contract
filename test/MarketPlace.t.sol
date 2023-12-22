// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";

import "./helpers/DiamondUtils.sol";

import "./helpers/DiamondDeployer.sol";

contract MarketPlaceFacetTest is DiamondDeployer {
    function testCreateListing() public {
        uint256 _tokenID = 888;

        ERC721_Diamond.mint(user1, _tokenID);

        switchSigner(user1);

        ERC721_Diamond.setApprovalForAll(address(diamond), true);

        address NftAddress = address(ERC721_Diamond);

        uint256 _price = 2 ether;
        uint256 _deadline = 2 days;
        address _seller = user1;
        bool _isActive = true;

        currentListingId = Marketplace_Diamond.createListing(
            NftAddress,
            _tokenID,
            _price,
            _deadline,
            _seller,
            _isActive
        );

        LibDiamond.ListingInfo memory listingInfo = Marketplace_Diamond
            .getListing(currentListingId);

        assertEq(listingInfo.token, NftAddress);
        assertEq(listingInfo.tokenId, _tokenID);

        console2.logUint(listingInfo.tokenId);
        assertEq(listingInfo.price, _price);

        assertEq(listingInfo.deadline, _deadline);
        console2.logUint(listingInfo.deadline);

        assertEq(listingInfo.seller, user1);
        assertEq(listingInfo.isActive, true);
    }

    function _createListing() internal returns (uint256 _listingId) {
        _listingId = Marketplace_Diamond.getListingId();

        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        LibDiamond.ListingInfo storage listingInfo = ds.listingsInfo[
            _listingId
        ];

        Marketplace_Diamond.createListing(
            listingInfo.token,
            listingInfo.tokenId,
            listingInfo.price,
            listingInfo.deadline,
            listingInfo.seller,
            listingInfo.isActive
        );
    }

    function testCreateListing_OnlyOwnerCanCreateListing() public {
        uint256 _tokenID = 888;

        ERC721_Diamond.mint(user1, _tokenID);

        ERC721_Diamond.setApprovalForAll(address(diamond), true);

        switchSigner(user2);

        vm.expectRevert(MarketplaceFacet.NotOwner.selector);

        address NftAddress = address(ERC721_Diamond);

        uint256 _price = 2 ether;
        uint256 _deadline = 2 days;
        address _seller = user1;
        bool _isActive = true;

        Marketplace_Diamond.createListing(
            NftAddress,
            _tokenID,
            _price,
            _deadline,
            _seller,
            _isActive
        );
    }

    function testCreateListing_NotApprovedNFTForUser() public {
        uint256 _tokenID = 1000;

        address NftAddress = address(ERC721_Diamond);

        uint256 _price = 2 ether;
        uint256 _deadline = 2 days;
        address _seller = user1;
        bool _isActive = true;

        ERC721_Diamond.mint(user1, _tokenID);

        switchSigner(user1);

        ERC721_Diamond.setApprovalForAll(address(diamond), false);

        vm.expectRevert(MarketplaceFacet.NotApproved.selector);

        Marketplace_Diamond.createListing(
            NftAddress,
            _tokenID,
            _price,
            _deadline,
            _seller,
            _isActive
        );
    }

    function testCreateListing_MinimumPriceTooLow() public {
        switchSigner(user1);

        uint256 _tokenID = 1000;

        address NftAddress = address(ERC721_Diamond);

        uint256 _price = 0 ether;
        uint256 _deadline = 2 days;
        address _seller = user1;
        bool _isActive;

        ERC721_Diamond.mint(user1, _tokenID);

        ERC721_Diamond.setApprovalForAll(address(diamond), true);

        vm.expectRevert(MarketplaceFacet.MinPriceTooLow.selector);

        Marketplace_Diamond.createListing(
            NftAddress,
            _tokenID,
            _price,
            _deadline,
            _seller,
            _isActive
        );
    }

    function testCreateListing_DeadlineTooSoon() public {
        switchSigner(user1);

        address NftAddress = address(ERC721_Diamond);

        uint256 _price = 2 ether;
        uint256 _deadline = 0 minutes;
        address _seller = user1;

        uint256 _tokenID = 1000;
        bool _isActive = true;

        ERC721_Diamond.mint(user1, _tokenID);

        ERC721_Diamond.setApprovalForAll(address(diamond), true);

        vm.expectRevert(MarketplaceFacet.DeadlineTooSoon.selector);

        Marketplace_Diamond.createListing(
            NftAddress,
            _tokenID,
            _price,
            _deadline,
            _seller,
            _isActive
        );
    }

    function testCreateListing_MinimumDurationNotMet() public {
        switchSigner(user1);
        address NftAddress = address(ERC721_Diamond);

        uint256 _price = 2 ether;
        uint256 _deadline = 30 minutes;
        address _seller = user1;

        uint256 _tokenID = 1000;
        bool _isActive;

        ERC721_Diamond.mint(user1, _tokenID);

        ERC721_Diamond.setApprovalForAll(address(diamond), true);

        vm.expectRevert(MarketplaceFacet.MinDurationNotMet.selector);

        Marketplace_Diamond.createListing(
            NftAddress,
            _tokenID,
            _price,
            _deadline,
            _seller,
            _isActive
        );

        uint _listingId = Marketplace_Diamond.getListingId();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        ds.listingsInfo[_listingId];

        uint256 s_deadline = Marketplace_Diamond.getDeadline();

        assertEq(ds.listingsInfo[_listingId].deadline, s_deadline);
    }

    function testBuyListing_ListingDoesNotExist() public {
        testCreateListing();

        vm.expectRevert(MarketplaceFacet.ListingDoesNotExist.selector);

        Marketplace_Diamond.buyListing(3);
    }

    function _buyListing() internal {
        switchSigner(user1);
        uint256 _currentListingId = Marketplace_Diamond.getListingId();

        Marketplace_Diamond.buyListing(_currentListingId);
    }

    function testBuyListing_ListingExpired() public {
        testCreateListing();

        vm.warp(1641070800);

        vm.expectRevert(MarketplaceFacet.ListingExpired.selector);
        // When listing expires, the listingId becomes zero

        Marketplace_Diamond.buyListing(0);
    }

    function testBuyListing_ListingNotActive() public {
        switchSigner(user1);

        uint256 _tokenID = 1000;

        ERC721_Diamond.mint(user1, _tokenID);

        ERC721_Diamond.setApprovalForAll(address(diamond), true);

        uint256 _listingId = Marketplace_Diamond.getListingId();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        LibDiamond.ListingInfo storage listingInfo = ds.listingsInfo[
            _listingId
        ];

        address NftAddress = address(ERC721_Diamond);

        listingInfo.seller = user1;
        listingInfo.tokenId = _tokenID;

        uint256 currentId = Marketplace_Diamond.createListing(
            listingInfo.token = NftAddress,
            listingInfo.tokenId = _tokenID,
            listingInfo.price = 2 ether,
            listingInfo.deadline = 2 days,
            listingInfo.seller = user1,
            listingInfo.isActive = false
        );

        vm.expectRevert(MarketplaceFacet.ListingNotActive.selector);

        Marketplace_Diamond.buyListing(currentId);
    }

    function _createBuyListing() internal {
        uint256 _tokenID = 999;

        ERC721_Diamond.mint(user1, _tokenID);
        switchSigner(user1);

        ERC721_Diamond.setApprovalForAll(address(diamond), true);

        uint256 _listingId = Marketplace_Diamond.getListingId();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        LibDiamond.ListingInfo storage listingInfo = ds.listingsInfo[
            _listingId
        ];

        address NftAddress = address(ERC721_Diamond);

        Marketplace_Diamond.createListing(
            listingInfo.token = NftAddress,
            listingInfo.tokenId = _tokenID,
            listingInfo.price = 2 ether,
            listingInfo.deadline = 2 days,
            listingInfo.seller = user1,
            listingInfo.isActive = true
        );
    }

    function testBuyListing_PriceMismatch() public {
        uint256 _tokenID = 999;

        ERC721_Diamond.mint(user1, _tokenID);
        switchSigner(user1);

        ERC721_Diamond.setApprovalForAll(address(diamond), true);

        uint256 _listingId = Marketplace_Diamond.getListingId();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        LibDiamond.ListingInfo storage listingInfo = ds.listingsInfo[
            _listingId
        ];

        address NftAddress = address(ERC721_Diamond);

        uint _currentListingId = Marketplace_Diamond.createListing(
            listingInfo.token = NftAddress,
            listingInfo.tokenId = _tokenID,
            listingInfo.price = 2 ether,
            listingInfo.deadline = 2 days,
            listingInfo.seller = user1,
            listingInfo.isActive = true
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                MarketplaceFacet.PriceMismatch.selector,
                listingInfo.price
            )
        );

        Marketplace_Diamond.buyListing{value: 3 ether}(_currentListingId);
    }

    function testBuyListing_PriceNotMet() public {
        uint256 _tokenID = 777;

        ERC721_Diamond.mint(user1, _tokenID);
        switchSigner(user1);

        ERC721_Diamond.setApprovalForAll(address(diamond), true);

        uint256 _listingId = Marketplace_Diamond.getListingId();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        LibDiamond.ListingInfo storage listingInfo = ds.listingsInfo[
            _listingId
        ];

        address NftAddress = address(ERC721_Diamond);

        uint _currentListingId = Marketplace_Diamond.createListing(
            listingInfo.token = NftAddress,
            listingInfo.tokenId = _tokenID,
            listingInfo.price = 2 ether,
            listingInfo.deadline = 2 days,
            listingInfo.seller = user1,
            listingInfo.isActive = true
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                MarketplaceFacet.PriceNotMet.selector,
                (listingInfo.price - 1 ether)
            )
        );

        Marketplace_Diamond.buyListing{value: 1 ether}(currentListingId);
    }

    // UPDATE LISTING

    // function _updateListing() internal {
    //     switchSigner(creator1);
    //     bridgeWaters.updateListing(
    //         currentListingId,
    //         3 ether,
    //         listingInfo.isActive
    //     );
    // }

    // function testUpdateListing_ListingDoesNotExist() public {
    //     switchSigner(creator1);
    //     // bridgeWaterNFT.mint(creator1, 2);
    //     bridgeWaterNFT.setApprovalForAll(address(bridgeWaters), true);

    //     listingInfo.seller = creator1;
    //     listingInfo.tokenId = 2;

    //     currentListingId = bridgeWaters.createListing(
    //         listingInfo.token,
    //         listingInfo.tokenId,
    //         listingInfo.price,

    //         listingInfo.deadline,
    //         listingInfo.seller,
    //         listingInfo.isActive
    //     );

    //     vm.expectRevert(BridgeWatersMarketplace.ListingDoesNotExist.selector);

    //     bridgeWaters.updateListing(currentListingId, 0, false);
    // }

    // function testUpdateListing_NotOwner() public {
    //     switchSigner(creator1);
    //     bridgeWaterNFT.mint(creator1, 3);
    //     bridgeWaterNFT.setApprovalForAll(address(bridgeWaters), true);

    //     listingInfo.seller = creator1;
    //     //listingInfo.tokenId

    //     uint256 _currentListingId = bridgeWaters.createListing(
    //         listingInfo.token,
    //         listingInfo.tokenId,
    //         listingInfo.price,

    //         listingInfo.deadline,
    //         listingInfo.seller,
    //         listingInfo.isActive
    //     );

    //     vm.startPrank(spender);

    //     vm.expectRevert(BridgeWatersMarketplace.NotOwner.selector);

    //     bridgeWaters.updateListing(_currentListingId, 1 ether, true);
    // }

    // function testUpdateListing() public {
    //     listingInfo.seller = creator1;

    //     switchSigner(creator1);
    //     //bridgeWaterNFT.mint(creator1, 2);
    //     bridgeWaterNFT.setApprovalForAll(address(bridgeWaters), true);

    //     listingInfo.tokenId = 2;

    //     currentListingId = bridgeWaters.createListing(
    //         listingInfo.token,
    //         listingInfo.tokenId,
    //         listingInfo.price,

    //         listingInfo.deadline,
    //         listingInfo.seller,
    //         listingInfo.isActive
    //     );

    //     uint256 newPrice = 3 ether;

    //     assertEq(
    //         bridgeWaterNFT.ownerOf(listingInfo.tokenId),
    //         address(bridgeWaters)
    //     );

    //     bridgeWaters.updateListing(
    //         currentListingId,
    //         newPrice,
    //         listingInfo.isActive
    //     );

    //     listingInfo = bridgeWaters.getListing(currentListingId);

    //     assertEq(listingInfo.price, newPrice);
    //     assertEq(listingInfo.isActive, true);
    // }

    // function testBuyListing() public {
    //     switchSigner(creator1);

    //     vm.warp(1641070800);

    //     listingInfo.deadline = uint88(block.timestamp + 120 minutes);

    //     bridgeWaterNFT.setApprovalForAll(address(bridgeWaters), true);

    //     currentListingId = bridgeWaters.createListing(
    //         listingInfo.token,
    //         listingInfo.tokenId,
    //         listingInfo.price,

    //         listingInfo.deadline,
    //         listingInfo.seller,
    //         listingInfo.isActive
    //     );

    //     switchSigner(spender);
    //     //vm.warp(1641070800);
    //     bridgeWaters.buyListing{value: listingInfo.price}(currentListingId);
    //     assertEq(bridgeWaterNFT.ownerOf(currentListingId), spender);
    // }

    // function testERC721Facet_Name() public {
    //     assertEq(ERC721_Diamond.name(), name);
    // }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
