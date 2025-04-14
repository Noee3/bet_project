// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {BetToken} from "../src/BetToken.sol";

contract BetTokenScript is Script {
    BetToken betToken;

    function run(string memory _name, string memory _symbol, uint256 _initialSupply) public returns (BetToken) {
        vm.startBroadcast();
        _deploy(_name, _symbol, _initialSupply);
        vm.stopBroadcast();
        return betToken;
    }

    function _deploy(string memory _name, string memory _symbol, uint256 _initialSupply) private {
        betToken = new BetToken(_name, _symbol, _initialSupply);
    }
}
