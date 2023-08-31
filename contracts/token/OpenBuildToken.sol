// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract OpenBuildToken is ERC20 {
    constructor(address initialAccount) ERC20("OPENBUILD", "OBT") {
        _mint(initialAccount, 10 * 10 ** 8 * 10 ** 18);
    }
}
