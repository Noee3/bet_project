// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBetFactory} from "./interfaces/IBetFactory.sol";
import {Bet, IBet} from "./Bet.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title BetFactory
 * @author No3
 * @notice This contract allow users to create bets
 */
contract BetFactory is IBetFactory, Ownable {
    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/

    using SafeERC20 for IERC20;
    /*//////////////////////////////////////////////////////////////
                            STATES VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 private immutable i_maxPosition;
    address[] private s_bets;
    address private token;
    mapping(address bet => address creator) private s_betCreator;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _token, uint256 maxPosition) Ownable(msg.sender) {
        if (_token == address(0)) {
            revert BetFactory__AddressCantBeZero();
        }

        if (maxPosition == 0) {
            revert BetFactory__PositionCantBeZero();
        }

        i_maxPosition = maxPosition;
        token = _token;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @param startDate The date on which the bet begins
     * @param endDate The date on which the bet ends
     * @param positions The array containing the positions to bet on
     * @param position The position to place bet amount
     * @param betAmount Bet amount to place
     * @param tokenIn Token to use
     */
    function createBet(
        uint64 startDate,
        uint64 endDate,
        string[] calldata positions,
        uint256 position,
        uint256 betAmount,
        address tokenIn,
        string calldata description
    ) external override returns (Bet newBet) {
        if (startDate < block.timestamp) {
            revert BetFactory__DateMustBeGreaterOrEqualNow(startDate);
        }

        if (endDate < startDate) {
            revert BetFactory__EndDateBeforeStartDate(startDate, endDate);
        }

        if (positions.length <= 2) {
            revert BetFactory__PositionsMustBeGreater(positions.length);
        }

        if (positions.length > i_maxPosition) {
            revert BetFactory__PositionExceeded(i_maxPosition, positions.length);
        }

        if (position > positions.length) {
            revert BetFactory__PositionInvalid(position, positions.length);
        }

        newBet = new Bet{salt: bytes32(keccak256(abi.encodePacked(address(this), s_bets.length)))}(
            msg.sender, positions, startDate, endDate, position, betAmount, tokenIn, description
        );

        s_bets.push(address(newBet));
        s_betCreator[address(newBet)] = msg.sender;

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(newBet), betAmount);

        emit CreatedBet(address(newBet), msg.sender, position, betAmount, tokenIn);
    }

    /**
     * @notice Get the token
     * @return Address of the token
     */
    function getToken() external view override returns (address) {
        return token;
    }

    /**
     * @notice Get the maximum position
     * @return uint256 The maximum position
     */
    function getMaxPosition() external view override returns (uint256) {
        return i_maxPosition;
    }

    /**
     * @notice Get the bets created
     * @return address[] The array of bets created
     */
    function getBets(uint256 index) external view override returns (address) {
        return s_bets[index];
    }

    /**
     * @notice Get the bet creator
     * @param bet The address of the bet
     * @return address The address of the bet creator
     */
    function getBetCreator(address bet) external view override returns (address) {
        return s_betCreator[bet];
    }

    /**
     * @notice Get the number of bets created
     * @return uint256 The number of bets created
     */
    function getBetCount() external view override returns (uint256) {
        return s_bets.length;
    }
}
