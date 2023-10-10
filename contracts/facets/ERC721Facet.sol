// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

//import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
// import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

import {Strings} from "../libraries/Strings.sol";
import {Address} from "../libraries/Address.sol";

contract ERC721Facet {
    // A for B Pattern
    using Address for address;
    using Strings for uint256;

    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );

    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool indexed isApproved
    );

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    function name() external view returns (string memory) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.name;
    }

    function symbol() external view returns (string memory) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.symbol;
    }

    function balanceOf(address _owner) external view returns (uint256) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(_owner != address(0), "ERC721: Not a Valid Address");

        return ds.balances[_owner];
    }

    function ownerOf(uint256 _tokenId) external view returns (address) {
        address owner = _ownerOf(_tokenId);

        require(owner != address(0), "ERC721: Not a Valid Address");

        return owner;
    }

    function _ownerOf(uint256 tokenId) internal view returns (address) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.owners[tokenId];
    }

    function tokenURI(uint256 _tokenId) public view returns (string memory) {
        _requireMinted(_tokenId);

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, _tokenId.toString()))
                : ""; // Tenary Operation
    }

    function _baseURI() internal pure virtual returns (string memory) {
        return "";
    }

    function _requireMinted(uint256 _tokenId) internal view {
        require(_exists(_tokenId), "ERC721: Invalid token ID");
    }

    function _exists(uint256 _tokenId) internal view virtual returns (bool) {
        return _ownerOf(_tokenId) != address(0);
    }

    function approve(address to, uint256 _tokenId) public {
        address owner = _ownerOf(_tokenId);

        require(to != owner, "ERC721: approval to current owner");

        require(
            msg.sender == owner || isApprovedForAll(owner, msg.sender),
            "ERC721: approve caller is not token owner or approved for all"
        );

        _approve(to, _tokenId);
    }

    function _approve(address to, uint256 _tokenId) internal virtual {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.tokenApproval[_tokenId] = to;
        emit Approval(_ownerOf(_tokenId), to, _tokenId);
    }

    function isApprovedForAll(
        address owner,
        address operator
    ) public view returns (bool) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.operatorApprovals[owner][operator];
    }

    function getApproved(uint256 _tokenId) public view returns (address) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        _requireMinted(_tokenId);

        return ds.tokenApproval[_tokenId];
    }

    function setApprovalForAll(address _operator, bool isApproved) public {
        _setApprovalForAll(msg.sender, _operator, isApproved);
    }

    function _setApprovalForAll(
        address _owner,
        address _operator,
        bool _isApproved
    ) internal virtual {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(_owner != _operator, "ERC721: approve to caller");
        // Updates the mapping
        ds.operatorApprovals[_owner][_operator] = _isApproved; // bool false

        emit ApprovalForAll(_owner, _operator, _isApproved);
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) public {
        require(
            _isApprovedOrOwner(msg.sender, _tokenId),
            "ERC721: caller is not token owner or approved"
        );

        _transfer(_from, _to, _tokenId);
    }

    function _isApprovedOrOwner(
        address _spender,
        uint256 _tokenId
    ) internal view returns (bool) {
        // gets the owner
        address owner = _ownerOf(_tokenId);
        // checks that the spender is the owner or an approved spender
        return (_spender == owner ||
            isApprovedForAll(owner, _spender) ||
            getApproved(_tokenId) == _spender);
    }

    function _transfer(address _from, address _to, uint256 _tokenId) internal {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(
            _ownerOf(_tokenId) == _from,
            "ERC721: transfer from incorrect owner"
        );
        require(_to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(_from, _to, _tokenId, 1);

        // Check that tokenId was not transferred by `_beforeTokenTransfer` hook
        require(
            _ownerOf(_tokenId) == _from,
            "ERC721: transfer from incorrect owner"
        );

        // Clear approvals from the previous owner
        delete ds.tokenApproval[_tokenId];

        unchecked {
            // unchecked, not perform arithmetic overflow and underflow checks,
            // thus arithmetic operations do not revert on underflow or overflow.

            ds.balances[_from] -= 1;
            ds.balances[_to] += 1;
        }
        // Update mapping... mapping(uint256 tokenID => address owner) private owner;
        ds.owners[_tokenId] = _to;

        emit Transfer(_from, _to, _tokenId);

        _afterTokenTransfer(_from, _to, _tokenId, 1);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal {}

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public {
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "ERC721: caller is not token owner or approved"
        );
        _safeTransfer(from, to, tokenId, data);
    }

    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(
            _checkOnERC721Received(from, to, tokenId, data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.isContract()) {
            try
                IERC721Receiver(to).onERC721Received(
                    msg.sender,
                    from,
                    tokenId,
                    data
                )
            returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert(
                        "ERC721: transfer to non ERC721Receiver implementer"
                    );
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    function _safeMint(address to, uint256 tokenId) internal {
        _safeMint(to, tokenId, "");
    }

    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function _mint(address to, uint256 tokenId) internal {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(to != address(0), "ERC721: mint to the zero address");
        // you can't mint with the tokenId that already exist.
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId, 1);

        // Check that tokenId was not minted by `_beforeTokenTransfer` hook
        require(!_exists(tokenId), "ERC721: token already minted");

        unchecked {
            ds.balances[to] += 1;
        }

        ds.owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId, 1);
    }

    function _burn(uint256 tokenId) internal virtual {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        address owner = _ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId, 1);

        owner = _ownerOf(tokenId);

        // Clear approvals
        delete ds.tokenApproval[tokenId];

        unchecked {
            ds.balances[owner] -= 1;
        }
        delete ds.owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId, 1);
    }
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}
