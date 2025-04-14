// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {BetFactory} from "../src/BetFactory.sol";

contract BetFactoryScript is Script {
    error BetFactoryScript__TokenAddressZero();

    BetFactory betFactory;

    function run(address _token, uint256 _maxPosition) public returns (BetFactory) {
        vm.startBroadcast();
        _deploy(_token, _maxPosition);
        vm.stopBroadcast();
        return betFactory;
    }

    function _deploy(address _token, uint256 _maxPosition) private {
        if (_token == address(0)) {
            revert BetFactoryScript__TokenAddressZero();
        }
        betFactory = new BetFactory(_token, _maxPosition);
    }
}
