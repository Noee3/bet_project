// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {IBetFactory, BetFactory, Bet} from "../../src/BetFactory.sol";
import {MockERC20} from "forge-std/mocks/mockERC20.sol";

contract BetFactoryUnitTest is Test {
    BetFactory public betFactory;

    uint256 MAX_POSITION = 4;
    uint256 INITIAL_AMOUNT = 100e18;
    uint256 BET_AMOUNT = 10e18;
    string DESCRIPTION = "Who will win?";

    address player1 = makeAddr("player1");

    uint64 startDate;
    uint64 endDate;
    string[] positions;
    uint256 position;
    MockERC20 tokenIn;

    modifier betParams() {
        _;
        startDate = uint64(block.timestamp);
        endDate = uint64(block.timestamp + 3 days);
        positions = ["bob", "sam", "eugene", "jack"];
        deal(address(tokenIn), player1, INITIAL_AMOUNT);
        vm.prank(player1);
        MockERC20(tokenIn).approve(address(betFactory), BET_AMOUNT);
    }

    function setUp() public betParams {
        tokenIn = new MockERC20();
        betFactory = new BetFactory(address(tokenIn), MAX_POSITION);
    }

    function test_newFactory() public view {
        assertEq(betFactory.getMaxPosition(), MAX_POSITION);
        assertEq(betFactory.getToken(), address(tokenIn));
        assertEq(betFactory.owner(), address(this));
    }

    function test_revertWhen_deployWithTokenZero() public {
        vm.expectRevert(IBetFactory.BetFactory__AddressCantBeZero.selector);
        new BetFactory(address(0), MAX_POSITION);
    }

    function test_revertWhen_maxPositionZero() public {
        vm.expectRevert(IBetFactory.BetFactory__PositionCantBeZero.selector);
        new BetFactory(address(1), 0);
    }

    function test_createBet() public {
        uint256 balanceBeforePlayer = tokenIn.balanceOf(player1);

        vm.prank(player1);
        Bet newBet =
            betFactory.createBet(startDate, endDate, positions, position, BET_AMOUNT, address(tokenIn), DESCRIPTION);

        uint256 balanceAfterPlayer = tokenIn.balanceOf(player1);

        assertEq(newBet.getCreator(), player1);
        assertEq(newBet.getFactory(), address(betFactory));
        assertEq(newBet.getBetAmount(player1, position), BET_AMOUNT);
        assertEq(balanceBeforePlayer, balanceAfterPlayer + BET_AMOUNT);
        assertEq(tokenIn.balanceOf(address(newBet)), BET_AMOUNT);
        assertEq(betFactory.getBetCount(), 1);
        assertEq(betFactory.getBetCreator(address(newBet)), player1);
        assertEq(betFactory.getBets(0), address(newBet));
    }

    function test_revertWhen_createBetInPast() public {
        startDate = uint64(block.timestamp) - uint64(1 seconds);
        vm.prank(player1);
        vm.expectRevert(abi.encodeWithSelector(IBetFactory.BetFactory__DateMustBeGreaterOrEqualNow.selector, startDate));
        betFactory.createBet(startDate, endDate, positions, position, BET_AMOUNT, address(tokenIn), DESCRIPTION);
    }

    function test_revertWhen_endDateLowerThanStartDate() public {
        endDate = startDate - 1 seconds;
        vm.prank(player1);

        vm.expectRevert(
            abi.encodeWithSelector(IBetFactory.BetFactory__EndDateBeforeStartDate.selector, startDate, endDate)
        );
        betFactory.createBet(startDate, endDate, positions, position, BET_AMOUNT, address(tokenIn), DESCRIPTION);
    }

    function test_revertWhen_positionLengthLesserOrEqualThanTwo() public {
        positions = ["", ""];
        vm.prank(player1);

        vm.expectRevert(
            abi.encodeWithSelector(IBetFactory.BetFactory__PositionsMustBeGreater.selector, positions.length)
        );
        betFactory.createBet(startDate, endDate, positions, position, BET_AMOUNT, address(tokenIn), DESCRIPTION);
    }

    function test_revertWhen_positionLengthOutOfBound() public {
        positions = ["", "", "", "", ""];
        vm.prank(player1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IBetFactory.BetFactory__PositionExceeded.selector, betFactory.getMaxPosition(), positions.length
            )
        );
        betFactory.createBet(startDate, endDate, positions, position, BET_AMOUNT, address(tokenIn), DESCRIPTION);
    }

    function test_revertWhen_positionOutOfBound() public {
        position = positions.length + 1;
        vm.prank(player1);

        vm.expectRevert(
            abi.encodeWithSelector(IBetFactory.BetFactory__PositionInvalid.selector, position, positions.length)
        );
        betFactory.createBet(startDate, endDate, positions, position, BET_AMOUNT, address(tokenIn), DESCRIPTION);
    }

    function test_getMaxPosition() public view {
        uint256 maxPosition = betFactory.getMaxPosition();
        assertEq(maxPosition, MAX_POSITION);
    }
}
