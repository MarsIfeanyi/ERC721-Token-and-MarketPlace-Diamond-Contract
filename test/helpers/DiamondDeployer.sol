// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../contracts/interfaces/IDiamondCut.sol";
import "../../contracts/facets/DiamondCutFacet.sol";
import "../../contracts/facets/DiamondLoupeFacet.sol";
import "../../contracts/facets/OwnershipFacet.sol";
import "../../contracts/Diamond.sol";
import "../../contracts/facets/ERC721Facet.sol";
import "../../contracts/facets/MarketPlaceFacet.sol";

import "./DiamondUtils.sol";

contract DiamondDeployer is DiamondUtils, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;

    ERC721Facet erc721Facet;
    ERC721Facet ERC721_Diamond;

    MarketplaceFacet marketPlaceFacet;
    MarketplaceFacet Marketplace_Diamond;

    string name = "Bridge Waters MarketplaceFacet";
    string symbol = "BWM";

    address user1 = vm.addr(0x1);
    address user2 = vm.addr(0x2);

    address creator1;
    address creator2;
    address spender;

    uint256 privateKey1;
    uint256 privateKey2;
    uint256 privateKey3;

    uint256 currentListingId;

    address NftAddress2;

    uint256 price;

    uint256 deadline;
    address seller;
    bool isActive;

    // diaStorage().listingsInfo[sListingId()].token = _token;

    function setUp() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(
            address(this),
            address(dCutFacet),
            name,
            symbol,
            NftAddress2
        );
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();

        erc721Facet = new ERC721Facet();

        marketPlaceFacet = new MarketplaceFacet();

        ERC721_Diamond = ERC721Facet(address(diamond));
        Marketplace_Diamond = MarketplaceFacet(address(diamond));

        (creator1, privateKey1) = mkaddr("CREATOR");
        (creator2, privateKey2) = mkaddr("CREATOR2");
        (spender, privateKey3) = mkaddr("SPENDER");

        // erc721Facet.mint(creator1, 1045);

        currentListingId = marketPlaceFacet.getListingId();

        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](4);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );

        cut[2] = (
            FacetCut({
                facetAddress: address(erc721Facet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("ERC721Facet")
            })
        );

        cut[3] = (
            FacetCut({
                facetAddress: address(marketPlaceFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("MarketplaceFacet")
            })
        );

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external virtual override {}

    function mkaddr(
        string memory s_name
    ) public returns (address addr, uint256 privateKey) {
        privateKey = uint256(keccak256(abi.encodePacked(s_name)));
        addr = vm.addr(privateKey);
        vm.label(addr, s_name);
    }

    function switchSigner(address _newSigner) public {
        vm.startPrank(_newSigner);
        vm.deal(_newSigner, 3 ether);
        vm.label(_newSigner, "USER");
    }

    // function mark() {

    // }
}
