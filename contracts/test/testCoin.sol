// SPDX-License-Identifier: GPL 2.0
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';


contract testCoinA is ERC20('testCoinA', 'A'){
    function getCoin(uint amount) public{
        _mint(msg.sender, amount);
    }
}
