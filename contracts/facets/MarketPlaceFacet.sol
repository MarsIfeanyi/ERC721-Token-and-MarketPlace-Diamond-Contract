// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

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
        return LibDiamond.diamondStorage();
    }

    function sListingId() internal view returns (uint256) {
        return LibDiamond.diamondStorage().listingId;
    }

    // diaStorage().lig [ds.]

    function createListing(
        address _token,
        uint256 _tokenId,
        uint256 _price,
        uint256 _deadline,
        address _seller,
        bool _isActive
    ) public returns (uint256 _listingId) {
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
        // ListingInfo storage newListingInfo = listingsInfo[listingId];

        // diaStorage().

        diaStorage().listingsInfo[sListingId()].token = _token;
        diaStorage().listingsInfo[sListingId()].tokenId = _tokenId;
        diaStorage().listingsInfo[sListingId()].price = _price;
        diaStorage().listingsInfo[sListingId()].deadline = _deadline;
        diaStorage().listingsInfo[sListingId()].seller = _seller;
        diaStorage().listingsInfo[sListingId()].isActive = _isActive;

        _listingId = diaStorage().listingId;
        diaStorage().listingId++;

        // Emit event
        emit ListingCreated(diaStorage().listingId);

        return diaStorage().listingId;
    }

    function buyListing(uint256 _listingId) public payable {
        if (_listingId >= diaStorage().listingId) revert ListingDoesNotExist();

        //  ListingInfo storage listing = listingsInfo[_listingId];

        diaStorage().listingsInfo[sListingId()];

        // checks if deadline is lessthan the currentTime
        if (diaStorage().listingsInfo[sListingId()].deadline < block.timestamp)
            revert ListingExpired();

        if (!diaStorage().listingsInfo[sListingId()].isActive)
            revert ListingNotActive();

        if (diaStorage().listingsInfo[sListingId()].price < msg.value)
            revert PriceMismatch(diaStorage().listingsInfo[sListingId()].price);

        if (diaStorage().listingsInfo[sListingId()].price != msg.value)
            revert PriceNotMet(
                int256(diaStorage().listingsInfo[sListingId()].price) -
                    int256(msg.value)
            );

        // Update state

        diaStorage().listingsInfo[sListingId()].isActive = false;

        // transfer
        IERC721(diaStorage().listingsInfo[sListingId()].token).transferFrom(
            diaStorage().listingsInfo[sListingId()].seller,
            msg.sender,
            diaStorage().listingsInfo[sListingId()].tokenId
        );

        // transfer eth
        payable(diaStorage().listingsInfo[sListingId()].seller).transfer(
            diaStorage().listingsInfo[sListingId()].price
        );

        // Update storage
        emit ListingExecuted(_listingId);
    }

    function updateListing(
        uint256 _listingId,
        uint256 _newPrice,
        bool _isActive
    ) public {
        // require(_listingId > listingId, "Higher Higher");

        if (_listingId > diaStorage().listingId) revert ListingDoesNotExist();

        // ListingInfo storage listing = listingsInfo[_listingId];

        if (diaStorage().listingsInfo[sListingId()].seller != msg.sender)
            revert NotOwner();

        diaStorage().listingsInfo[sListingId()].price = _newPrice;
        diaStorage().listingsInfo[sListingId()].isActive = _isActive;

        emit ListingEdited(_listingId);
    }

    // add getter for listing
    function getListing(
        uint256 _listingId
    ) public view returns (LibDiamond.ListingInfo memory) {
        // if (_listingId >= listingId)
        return diaStorage().listingsInfo[_listingId];
    }
}
