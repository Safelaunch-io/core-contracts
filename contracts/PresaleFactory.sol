// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./Presale.sol";

contract PresaleFactory is Ownable {
    event PresaleCreated(
        address indexed addr,
        address token,
        uint256 tokenTarget,
        address weiToken,
        uint256 weiTarget,
        uint256 minWei,
        uint256 maxWei,
        bool isPublic,
        string meta
    );

    uint256 public presalesCount;
    address[] public presales;
    mapping(address => bool) private isPresale;

    function createPresale(
        IERC20 token,
        uint256 tokenTarget,
        address weiToken,
        uint256 weiTarget,
        uint256 minWei,
        uint256 maxWei,
        bool isPublic,
        string memory meta
    ) external onlyOwner returns (address) {
        require(address(token) != address(0), "Token can't be zero address!");
        require(minWei < maxWei, "minWei should be less than maxWei!");
        require(tokenTarget > 0, "Token target can't be zero!");
        require(weiTarget > 0, "Wei target can't be zero!");
        require(minWei > 0, "minWei can't be zero!");
        require(maxWei > 0, "maxWei can't be zero!");

        Presale presale =
            new Presale(
                token,
                tokenTarget,
                weiToken,
                weiTarget,
                minWei,
                maxWei,
                isPublic
            );

        presales.push(address(presale));
        isPresale[address(presale)] = true;

        presale.transferOwnership(msg.sender);

        presalesCount = presalesCount + 1;

        emit PresaleCreated(
            address(presale),
            address(token),
            tokenTarget,
            weiToken,
            weiTarget,
            minWei,
            maxWei,
            isPublic,
            meta
        );

        return address(presale);
    }
}
