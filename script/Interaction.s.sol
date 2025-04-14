// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Config} from "./Config.s.sol";
import {BetFactoryScript, BetFactory} from "./BetFactory.s.sol";
import {BetTokenScript, BetToken} from "./BetToken.s.sol";

contract Interaction is Script, Config {
    BetTokenScript public betTokenScript;
    BetFactoryScript public betFactoryScript;
    BetToken public betToken;
    BetFactory public betFactory;

    function run() public initConfig returns (BetFactory, BetToken) {
        _deploy();
        return (betFactory, betToken);
    }

    /**
     * @notice Deploy each contract
     */
    function _deploy() private {
        betToken = new BetToken(activeNetworkConfig.name, activeNetworkConfig.symbol, activeNetworkConfig.initialSupply);
        betFactory = new BetFactory(address(betToken), activeNetworkConfig.maxPosition);
    }
}
