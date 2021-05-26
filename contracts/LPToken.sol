pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LPToken is ERC20("LPToken", "LPT") {
    constructor() {
        _mint(msg.sender, 20000000 * 10**18);
    }
}
