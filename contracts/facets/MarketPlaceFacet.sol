// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import {LibDiamond} from "../libraries/LibDiamond.sol";

import {IERC721} from "../interfaces/IERC721.sol";

contract MarketplaceFacet {
    /* ERRORS */
    error NotOwner();
    error NotApproved();
    error MinPriceTooLow();
    error DeadlineTooSoon();
    error MinDurationNotMet();
    error InValidSignature();
    error ListingDoesNotExist();
    error ListingNotActive();
    error PriceNotMet(int256 difference);
    error ListingExpired();
    error PriceMismatch(uint256 originalPrice);

    /* EVENTS */
    event ListingCreated(uint256 indexed listingId);
    event ListingExecuted(uint256 indexed listingId);
    event ListingEdited(uint256 indexed listingId);

    function diaStorage()
        internal
        pure
        returns (LibDiamond.DiamondStorage storage)
    {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        return ds;
    }

    function sListingId() internal view returns (uint256) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        return ds.listingId;
    }

    // diaStorage().lig [ds.]

    function createListing(
        address _token,
        uint256 _tokenId,
        uint256 _price,
        uint256 _deadline,
        address _seller,
        bool _isActive
    ) public returns (uint256 s_listingId) {
        if (IERC721(_token).ownerOf(_tokenId) != msg.sender) revert NotOwner();
        if (!IERC721(_token).isApprovedForAll(msg.sender, address(this)))
            revert NotApproved();
        if (_price < 0.01 ether) revert MinPriceTooLow();
        // check if deadline is lessthan currentTime
        if (block.timestamp + _deadline <= block.timestamp)
            revert DeadlineTooSoon();
        // check if deadline is lessthan 60 minutes
        if (_deadline - block.timestamp < 60 minutes)
            revert MinDurationNotMet();

        // transfer the NFT from owner to marketplace
        IERC721(_token).transferFrom(msg.sender, address(this), _tokenId);

        // append to Storage

        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        s_listingId = ds.listingId;

        LibDiamond.ListingInfo storage listing = ds.listingsInfo[s_listingId];

        listing.token = _token;
        listing.tokenId = _tokenId;
        listing.price = _price;
        listing.deadline = _deadline;
        listing.seller = _seller;
        listing.isActive = _isActive;

        ds.listingId++;

        // Emit event
        emit ListingCreated(s_listingId);
    }

    function buyListing(uint256 _listingId) public payable {
        if (_listingId >= diaStorage().listingId) revert ListingDoesNotExist();

        //  ListingInfo storage listing = listingsInfo[_listingId];

        // Order storage _order = ds().orders[_orderId];

        // libDiamond.ListingInfo storage listing = diaStorage().listingsInfo[_listingId];
        LibDiamond.ListingInfo storage listing = LibDiamond
            .diamondStorage()
            .listingsInfo[_listingId];

        // checks if deadline is lessthan the currentTime
        if (listing.deadline < block.timestamp) revert ListingExpired();

        if (!listing.isActive) revert ListingNotActive();

        if (listing.price < msg.value) revert PriceMismatch(listing.price);

        if (listing.price != msg.value)
            revert PriceNotMet(int256(listing.price) - int256(msg.value));

        // Update state

        listing.isActive = false;

        // transfer
        IERC721(listing.token).transferFrom(
            listing.seller,
            msg.sender,
            listing.tokenId
        );

        // transfer eth
        payable(listing.seller).transfer(listing.price);

        // Update storage
        emit ListingExecuted(_listingId);
    }

    function updateListing(
        uint256 _listingId,
        uint256 _newPrice,
        bool _isActive
    ) public {
        // ListingInfo storage listing = diaStorage().listingsInfo[_listingId];
        LibDiamond.ListingInfo storage listing = LibDiamond
            .diamondStorage()
            .listingsInfo[_listingId];

        if (_listingId > diaStorage().listingId) revert ListingDoesNotExist();

        // ListingInfo storage listing = listingsInfo[_listingId];

        if (listing.seller != msg.sender) revert NotOwner();

        listing.price = _newPrice;
        listing.isActive = _isActive;

        emit ListingEdited(_listingId);
    }

    // add getter for listing
    function getListing(
        uint256 _listingId
    ) public view returns (LibDiamond.ListingInfo memory listingInfo) {
        listingInfo = diaStorage().listingsInfo[_listingId];
    }

    // Getter Functions

    function getToken() external view returns (address s_Token) {
        s_Token = diaStorage().listingsInfo[sListingId()].token;
    }

    function getTokenId() external view returns (uint256 s_TokenId) {
        s_TokenId = diaStorage().listingsInfo[sListingId()].tokenId;
    }

    function getPrice() external view returns (uint256 s_Price) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        LibDiamond.ListingInfo storage listing = ds.listingsInfo[sListingId()];

        s_Price = listing.price;
    }

    function getDeadline() external view returns (uint256 s_Deadline) {
        s_Deadline = diaStorage().listingsInfo[sListingId()].deadline;
    }

    function getSeller() external view returns (address s_Seller) {
        s_Seller = diaStorage().listingsInfo[sListingId()].seller;
    }

    function getIsActive() external view returns (bool s_IsActive) {
        s_IsActive = diaStorage().listingsInfo[sListingId()].isActive;
    }

    function getListingId() external view returns (uint256 s_ListingId) {
        s_ListingId = diaStorage().listingId;
    }
}
