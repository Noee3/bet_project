// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {BetFactory, Bet} from "../../src/BetFactory.sol";
import {BetToken} from "../../src/BetToken.sol";
import {Interaction} from "../../script/Interaction.s.sol";

contract IntegrationTest is Test {
    Interaction public deployment;
    BetFactory public betFactory;
    BetToken public betToken;

    uint256 INITIAL_AMOUNT = 100e18;
    uint256 BET_AMOUNT = 10e18;

    uint64 startDate;
    uint64 endDate;
    string[] positions;
    uint256 position;
    string description;

    address player1 = makeAddr("player1");
    address player2 = makeAddr("player2");
    address player3 = makeAddr("player3");

    function setUp() public {
        deployment = new Interaction();
        (betFactory, betToken) = deployment.run();

        startDate = uint64(block.timestamp);
        endDate = uint64(block.timestamp + 3 days);
        positions = ["bob", "sam", "eugene", "jack"];
        description = "Who will win ?";

        deal(address(betToken), player1, INITIAL_AMOUNT);
        vm.prank(player1);
        betToken.approve(address(betFactory), INITIAL_AMOUNT);

        deal(address(betToken), player2, INITIAL_AMOUNT);
        deal(address(betToken), player3, INITIAL_AMOUNT);

        assertEq(betFactory.getToken(), address(betToken));
    }

    function test_betLifeCycle() public {
        //creation and first join by creator player1
        uint256 positionPlayer1 = 0; //bob

        vm.prank(player1);
        Bet newBet = betFactory.createBet(
            startDate, endDate, positions, positionPlayer1, BET_AMOUNT, address(betToken), description
        );

        //join by player2;
        uint256 positionPlayer2 = 1; //sam
        vm.startPrank(player2);
        betToken.approve(address(newBet), INITIAL_AMOUNT);
        newBet.join(BET_AMOUNT, positionPlayer2);
        vm.stopPrank();

        //join by player3;
        uint256 positionPlayer3 = 2; //eugene
        vm.startPrank(player3);
        betToken.approve(address(newBet), INITIAL_AMOUNT);
        newBet.join(BET_AMOUNT, positionPlayer3);
        vm.stopPrank();

        //time pass
        vm.warp(endDate + 1 days);
        vm.roll(block.number + 1);

        //creator player1 resolve the bet
        vm.prank(player1);
        uint256 winningPosition = 1; //sam!
        newBet.resolve(winningPosition);

        //Winner claim his gain
        vm.prank(player2);
        newBet.claim();

        assertEq(betToken.balanceOf(address(newBet)), 0);
    }
}
