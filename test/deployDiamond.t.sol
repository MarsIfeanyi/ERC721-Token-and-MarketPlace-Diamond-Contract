// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/ERC721Facet.sol";
import "./helpers/DiamondUtils.sol";

contract DiamondDeployer is DiamondUtils, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupeFacet;
    OwnershipFacet ownerFacet;
    ERC721Facet erc721Facet;

    string name = "MarsEnergy";
    string symbol = "Mars";
    uint8 public immutable decimals = 18;

    address user1 = vm.addr(0x1);
    address user2 = vm.addr(0x2);

    function setUp() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet), name, symbol);
        dLoupeFacet = new DiamondLoupeFacet();
        ownerFacet = new OwnershipFacet();
        erc721Facet = new ERC721Facet();

        //upgrade diamond with facets

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

    function testerc721Facet_Name() public {
        // binding the contract type and the diamond address...This is like binding the ABI to an address, becuase the Diamond itself does not contain the function, name(). its only the erc721Facet that contains the function name(),but you are not calling name on the facet, you are calling it on the Diamond Hint: erc721Facet contains the ABI, while Diamond contains the storage.

        assertEq(ERC721Facet(address(diamond)).name(), name);

        // Hint: Since you have moved the storage from the erc721Facet the DiamondStorage() struct, and there is no visibility in struct you will have to write the getter function for each of the stroage variable
    }

    function testerc721Facet_Symbol() public {
        assertEq(ERC721Facet(address(diamond)).symbol(), symbol);
    }

    function testerc721Facet_Transfer() public {
        vm.startPrank(user1);

        uint256 mintAmout = 10000e18;
        uint256 transferAmount = 50e18;
        uint256 balanceAfterTransfer = mintAmout - transferAmount;

        ERC721Facet(address(diamond)).mint(user1, mintAmout);

        erc721Facet(address(diamond)).transfer(user2, transferAmount);

        assertEq(
            erc721Facet(address(diamond)).balanceOf(user1),
            balanceAfterTransfer
        );
        assertEq(
            erc721Facet(address(diamond)).balanceOf(user2),
            transferAmount
        );
    }

    function testerc721Facet_TotalSupply() public {
        vm.prank(user1);

        uint256 mintAmount = 2000e18;
        erc721Facet(address(diamond)).mint(user1, mintAmount);

        assertEq(erc721Facet(address(diamond)).totalSupply(), mintAmount);
    }

    function testerc721Facet_Mint() public {
        uint256 mintAmount = 5000e18;
        erc721Facet(address(diamond)).mint(user1, mintAmount);
        assertEq(
            erc721Facet(address(diamond)).totalSupply(),
            erc721Facet(address(diamond)).balanceOf(user1)
        );
    }

    function testerc721Facet_Burn() public {
        uint256 mintAmount = 5000e18;
        uint256 burnAmount = 200e18;
        uint256 currentBalance = mintAmount - burnAmount;

        testerc721Facet_Mint();
        assertEq(erc721Facet(address(diamond)).totalSupply(), mintAmount);

        erc721Facet(address(diamond)).burn(user1, burnAmount);

        assertEq(
            erc721Facet(address(diamond)).balanceOf(user1),
            currentBalance
        );
    }

    function testerc721Facet_Allowance() public {
        vm.prank(user1);

        uint256 approvalAmount = 5000;
        erc721Facet(address(diamond)).approve(user2, approvalAmount);

        assertEq(
            erc721Facet(address(diamond)).allowance(user1, user2),
            approvalAmount
        );
    }

    function testerc721Facet_Approve() public {
        vm.prank(user1);

        uint256 approvedAmount = 50000;

        assertTrue(
            erc721Facet(address(diamond)).approve(user2, approvedAmount)
        );

        assertEq(
            erc721Facet(address(diamond)).allowance(user1, user2),
            approvedAmount
        );
    }

    function testerc721Facet_TransferFrom() public {
        testerc721Facet_Mint();
        vm.prank(user1);
        uint256 mintAmount = 5000e18;
        uint256 approvalAmount = 500e18;
        uint256 transferAmount = 5e18;
        uint256 balanceAferTransfer = mintAmount - transferAmount;
        uint256 currentApproval = approvalAmount - transferAmount;

        erc721Facet(address(diamond)).approve(address(this), approvalAmount);
        assertTrue(
            erc721Facet(address(diamond)).transferFrom(
                user1,
                user2,
                transferAmount
            )
        );
        assertEq(
            erc721Facet(address(diamond)).allowance(user1, address(this)),
            currentApproval
        );

        assertEq(
            erc721Facet(address(diamond)).balanceOf(user1),
            balanceAferTransfer
        );

        assertEq(
            erc721Facet(address(diamond)).balanceOf(user2),
            transferAmount
        );
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
