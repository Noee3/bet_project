// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {IBet, BetFactory, Bet} from "../../src/BetFactory.sol";
import {MockERC20} from "forge-std/mocks/mockERC20.sol";

contract BetUnitTest is Test {
    BetFactory public betFactory;
    Bet public bet;

    uint256 MAX_POSITION = 4;
    uint256 INITIAL_AMOUNT = 100e18;
    uint256 BET_AMOUNT = 10e18;
    uint256 JOIN_POSITION = 2;
    uint256 STATE_LENGTH = 4;
    string DESCRIPTION = "Who will win?";

    address owner = makeAddr("owner");
    address player1 = makeAddr("player1");
    address player2 = makeAddr("player2");

    uint64 startDate;
    uint64 endDate;
    string[] positions;
    uint256 position;
    MockERC20 tokenIn;

    function setUp() public {
        vm.startPrank(owner);
        tokenIn = new MockERC20();
        betFactory = new BetFactory(address(tokenIn), MAX_POSITION);
        vm.stopPrank();

        startDate = uint64(block.timestamp);
        endDate = uint64(block.timestamp + 3 days);
        positions = ["bob", "sam", "eugene", "jack"];

        deal(address(tokenIn), player1, INITIAL_AMOUNT);
        deal(address(tokenIn), player2, INITIAL_AMOUNT);

        vm.startPrank(player1);
        MockERC20(tokenIn).approve(address(betFactory), INITIAL_AMOUNT);
        bet = betFactory.createBet(startDate, endDate, positions, position, BET_AMOUNT, address(tokenIn), DESCRIPTION);
        MockERC20(tokenIn).approve(address(bet), INITIAL_AMOUNT);
        vm.stopPrank();

        vm.prank(player2);
        MockERC20(tokenIn).approve(address(bet), INITIAL_AMOUNT);

        assertEq(bet.getBetAmount(player1, position), BET_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                                 CANCEL
    //////////////////////////////////////////////////////////////*/

    function test_cancel() public {
        vm.prank(player1);

        vm.expectEmit(true, true, true, true, address(bet));
        emit IBet.Canceled(address(bet), uint64(block.timestamp), IBet.BetState.canceled, BET_AMOUNT);

        bet.cancel();
        uint256 balanceAfter = MockERC20(tokenIn).balanceOf(player1);

        assertEq(INITIAL_AMOUNT, balanceAfter);
        assertEq(uint8(bet.getState()), uint8(IBet.BetState.canceled));
    }

    function test_revertWhen_cancelWhenEnded() public {
        vm.startPrank(player1);
        vm.warp(endDate + 1 days);
        vm.roll(block.timestamp + 3);

        vm.expectRevert(abi.encodeWithSelector(IBet.Bet__InvalidState.selector, IBet.BetState.ended));
        bet.cancel();
        vm.stopPrank();
    }

    function test_revertWhen_cancelWhenResolved() public {
        vm.startPrank(player1);
        vm.warp(endDate + 1 days);
        vm.roll(block.timestamp + 3);

        bet.resolve(JOIN_POSITION);

        vm.expectRevert(abi.encodeWithSelector(IBet.Bet__InvalidState.selector, IBet.BetState.resolved));
        bet.cancel();
        vm.stopPrank();
    }

    function test_revertWhen_cancelCountGreaterThanZero() public {
        vm.prank(player2);
        bet.join(BET_AMOUNT, JOIN_POSITION);

        vm.startPrank(player1);
        vm.expectRevert(IBet.Bet__ParticipantsIn.selector);
        bet.cancel();
    }

    /*//////////////////////////////////////////////////////////////
                                RESOLVE
    //////////////////////////////////////////////////////////////*/

    function _resolve(uint256 _position) private {
        vm.startPrank(player1);
        vm.warp(endDate + 1 days);
        vm.roll(block.timestamp + 3);

        vm.expectEmit(true, true, true, true, address(bet));
        emit IBet.Resolved(address(bet), uint64(block.timestamp), IBet.BetState.resolved, _position);
        bet.resolve(_position);
        vm.stopPrank();

        assertEq(bet.getWonPosition(), _position);
        assertEq(uint8(bet.getState()), uint8(IBet.BetState.resolved));
    }

    function test_resolve() public {
        _resolve(JOIN_POSITION);
    }

    function test_revertWhen_resolveInvalidState() public {
        vm.startPrank(player1);

        vm.expectRevert(abi.encodeWithSelector(IBet.Bet__InvalidState.selector, IBet.BetState.started));
        bet.resolve(JOIN_POSITION);
    }

    function test_revertWhen_resolveInvalidPosition() public {
        uint256 exceedPosition = positions.length + 1;
        vm.startPrank(player1);
        vm.warp(endDate + 1 days);
        vm.roll(block.timestamp + 3);

        vm.expectRevert(abi.encodeWithSelector(IBet.Bet__PositionInvalid.selector, exceedPosition, positions.length));
        bet.resolve(exceedPosition);
    }

    /*//////////////////////////////////////////////////////////////
                                  JOIN
    //////////////////////////////////////////////////////////////*/

    function _joinSolo(uint256 _position, address player) private {
        uint256 balanceBefore = MockERC20(tokenIn).balanceOf(player);
        uint256 betAmountBefore = bet.getBetAmount(player, _position);
        uint256 balancePoolBefore = bet.getPool(_position);

        vm.startPrank(player);
        vm.expectEmit(true, true, true, true, address(bet));

        emit IBet.Joined(address(bet), player, _position, BET_AMOUNT);
        bet.join(BET_AMOUNT, _position);
        vm.stopPrank();

        uint256 balanceAfter = MockERC20(tokenIn).balanceOf(player);
        uint256 betAmountAfter = bet.getBetAmount(player, _position);
        uint256 balancePoolAfter = bet.getPool(_position);

        assertEq(balanceBefore, balanceAfter + BET_AMOUNT);
        assertEq(betAmountBefore, betAmountAfter - BET_AMOUNT);
        assertEq(balancePoolBefore, balancePoolAfter - BET_AMOUNT);
    }

    function test_joinSolo() public {
        _joinSolo(JOIN_POSITION, player2);
        assertEq(bet.getCount(), 1);
    }

    function test_joinMultiSolo() public {
        uint256 length = positions.length;

        for (uint256 i; i < length; ++i) {
            _joinSolo(i, player2);
        }
        assertEq(bet.getCount(), 1);
    }

    function test_joinMulti() public {
        uint256 length = positions.length;

        for (uint256 i; i < length; ++i) {
            _joinSolo(i, player2);
        }

        for (uint256 i; i < length; ++i) {
            _joinSolo(i, player1);
        }

        assertEq(bet.getCount(), 2);
    }

    function test_revertWhen_joinInInvalidState() public {
        vm.warp(startDate - 1 seconds);
        vm.roll(block.number - 1);
        vm.prank(player2);
        vm.expectRevert(abi.encodeWithSelector(IBet.Bet__InvalidState.selector, IBet.BetState.waiting));
        bet.join(BET_AMOUNT, JOIN_POSITION);
    }

    function test_revertWhen_joinWithAmountZero() public {
        vm.prank(player2);
        vm.expectRevert(IBet.Bet__AmountCantBeZero.selector);
        bet.join(0, JOIN_POSITION);
    }

    function test_revertWhen_joinInvalidPosition() public {
        uint256 joinPosition = positions.length + 1;
        vm.prank(player2);
        vm.expectRevert(abi.encodeWithSelector(IBet.Bet__PositionInvalid.selector, joinPosition, positions.length));
        bet.join(BET_AMOUNT, joinPosition);
    }

    /*//////////////////////////////////////////////////////////////
                                 CLAIM
    //////////////////////////////////////////////////////////////*/

    function test_claimOnlyOnePlayer() public {
        uint256 balancePlayer2Before = MockERC20(tokenIn).balanceOf(player2);
        uint256 balancePlayer1Before = MockERC20(tokenIn).balanceOf(player1);
        uint256 balanceBetBefore = MockERC20(tokenIn).balanceOf(address(bet));

        _joinSolo(JOIN_POSITION, player2);
        _resolve(JOIN_POSITION);

        vm.startPrank(player2);
        uint256 prev_amount = bet.getPotentialWin(JOIN_POSITION);
        vm.expectEmit(true, true, true, false, address(bet));
        emit IBet.Claimed(address(bet), player2, prev_amount);

        uint256 amount = bet.claim();
        vm.stopPrank();

        uint256 balancePlayer2After = MockERC20(tokenIn).balanceOf(player2);
        uint256 balancePlayer1After = MockERC20(tokenIn).balanceOf(player1);
        uint256 balanceBetAfter = MockERC20(tokenIn).balanceOf(address(bet));
        //player1 creator bet on pos 0;
        assertEq(amount, prev_amount);
        assertEq(amount, BET_AMOUNT * 2);
        assertEq(balancePlayer2After, balancePlayer2Before + BET_AMOUNT);
        assertEq(balancePlayer1After, balancePlayer1Before);
        assertEq(balanceBetBefore, balanceBetAfter + BET_AMOUNT);
        assertEq(bet.getWonPosition(), JOIN_POSITION);
    }

    function test_claimMultiPlayer() public {
        //join all position with bet amount;

        uint256 length = positions.length;

        for (uint256 i; i < length; ++i) {
            _joinSolo(i, player2);
        }

        for (uint256 i; i < length; ++i) {
            _joinSolo(i, player1);
        }

        _resolve(JOIN_POSITION);

        uint256 contractBalanceBefore = MockERC20(tokenIn).balanceOf(address(bet));

        //PLAYER 1
        uint256 totalAmount1 = MockERC20(tokenIn).balanceOf(address(bet));
        uint256 amountWinningPool1 = bet.getPool(JOIN_POSITION);

        uint256 betAmountPlayer1 = bet.getBetAmount(player1, JOIN_POSITION);
        uint256 player1Win = (betAmountPlayer1 * totalAmount1) / amountWinningPool1;

        vm.prank(player1);
        uint256 amount1 = bet.claim();

        //PLAYER 2
        uint256 totalAmount2 = MockERC20(tokenIn).balanceOf(address(bet));
        uint256 amountWinningPool2 = bet.getPool(JOIN_POSITION);

        uint256 betAmountPlayer2 = bet.getBetAmount(player2, JOIN_POSITION);
        uint256 player2Win = (betAmountPlayer2 * totalAmount2) / amountWinningPool2;

        vm.prank(player2);
        uint256 amount2 = bet.claim();

        uint256 contractBalanceAfter = MockERC20(tokenIn).balanceOf(address(bet));

        assertEq(amount2, player2Win);
        assertEq(amount1, player1Win);
        assertEq(contractBalanceBefore - (amount1 + amount2), contractBalanceAfter);
        assertEq(bet.getWonPosition(), JOIN_POSITION);
    }

    function test_nothingToClaim() public {
        _joinSolo(0, player2);
        _resolve(JOIN_POSITION);

        vm.startPrank(player2);
        uint256 prev_amount = bet.getPotentialWin(JOIN_POSITION);
        uint256 amount = bet.claim();
        vm.stopPrank();

        assertEq(prev_amount + amount, 0);
        assertEq(bet.getWonPosition(), JOIN_POSITION);
    }

    /*//////////////////////////////////////////////////////////////
                                 GETTERS
    //////////////////////////////////////////////////////////////*/

    function test_getFactory() public view {
        assertEq(bet.getFactory(), address(betFactory));
    }

    function test_getToken() public view {
        assertEq(bet.getToken(), address(tokenIn));
    }

    function test_getCreator() public view {
        assertEq(bet.getCreator(), player1);
    }

    function test_getStartDate() public view {
        assertEq(bet.getStartDate(), startDate);
    }

    function test_getEndDate() public view {
        assertEq(bet.getEndDate(), endDate);
    }

    function test_getPosition() public view {
        assertEq(bet.getPosition(1), positions[1]);
    }

    function test_getPool() public view {
        assertEq(bet.getPool(0), 0);
    }
}
