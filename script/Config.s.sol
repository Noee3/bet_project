// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {MockERC20} from "forge-std/mocks/mockERC20.sol";
import {BetTokenScript} from "../script/BetToken.s.sol";
import {stdJson} from "forge-std/StdJson.sol";

contract Config {
    /*//////////////////////////////////////////////////////////////
                                  TYPE
    //////////////////////////////////////////////////////////////*/

    struct NetworkConfig {
        uint256 maxPosition;
        string name;
        string symbol;
        uint256 initialSupply;
    }

    /*//////////////////////////////////////////////////////////////
                            STATES VARIABLES
    //////////////////////////////////////////////////////////////*/

    NetworkConfig internal activeNetworkConfig;
    // Chain internal chain;
    uint256 MAX_POSITION = 4;
    string constant NAME = "BetToken";
    string constant SYMBOL = "BTK";
    uint256 constant INITIAL_SUPPLY = 1000e18;
    uint8 constant DECIMALS = 18;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier initConfig() {
        _initConfig();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _initConfig() internal virtual {
        activeNetworkConfig = NetworkConfig(MAX_POSITION, NAME, SYMBOL, INITIAL_SUPPLY);
    }
}
