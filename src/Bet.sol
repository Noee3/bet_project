// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBet} from "./interfaces/IBet.sol";
import {IBetFactory} from "./interfaces/IBetFactory.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title BetContract
 * @author No3
 * @notice This contract is used to create a bet, join a bet, cancel a bet, resolve a bet and claim rewards
 */
contract Bet is IBet {
    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/

    using SafeERC20 for IERC20;
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                            STATES VARIABLES
    //////////////////////////////////////////////////////////////*/

    address private immutable i_factory;
    address private immutable i_creator;
    address private immutable i_token;
    uint64 private i_startDate;
    uint64 private i_endDate;
    string private i_description;
    uint256 private s_wonPosition;
    string[] private s_positions;
    uint256[] private s_pools;
    BetState private s_state;
    uint256 private s_count;
    mapping(address players => bool counted) private s_players;
    mapping(address players => mapping(uint256 position => uint256 amount)) private s_betAmount;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allow only the bet owner  to modify state of the bet
     */
    modifier onlyBetCreator() {
        if (msg.sender != i_creator) {
            revert Bet__NotBetCreator();
        }
        _;
    }

    /**
     * @notice Update the bet state in join, cancel, resolve and claim
     */
    modifier updateState() {
        if (s_state != BetState.canceled) {
            if (block.timestamp >= i_startDate && block.timestamp < i_endDate && s_state != BetState.started) {
                s_state = BetState.started;
            } else if (block.timestamp >= i_endDate && s_state != BetState.ended && s_state != BetState.resolved) {
                s_state = BetState.ended;
            }
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     *
     * @param creator Address of the creator
     * @param positions The array containing the positions to bet on
     * @param startDate The date on which the bet begins
     * @param endDate The date on which the bet ends
     * @param position The array containing the positions to bet on
     * @param amount Bet amount to place
     * @param token Token to use
     * @param description Bet description
     */
    constructor(
        address creator,
        string[] memory positions,
        uint64 startDate,
        uint64 endDate,
        uint256 position,
        uint256 amount,
        address token,
        string memory description
    ) {
        if (creator == address(0)) {
            revert Bet__AddressCantBeZero(creator);
        }

        i_factory = msg.sender;
        i_creator = creator;
        i_startDate = startDate;
        i_endDate = endDate;
        i_token = token;
        i_description = description;
        s_positions = positions;
        s_betAmount[creator][position] = amount;
        s_pools = new uint256[](positions.length);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Cancel the bet if there's no players and refund the creator
     */
    function cancel() external override updateState onlyBetCreator {
        if (s_state != BetState.started && s_state != BetState.waiting) {
            revert Bet__InvalidState(s_state);
        }

        if (s_count > 0) {
            revert Bet__ParticipantsIn();
        }

        s_state = BetState.canceled;

        uint256 amountToRefund = IERC20(i_token).balanceOf(address(this));
        IERC20(i_token).safeTransfer(i_creator, IERC20(i_token).balanceOf(address(this)));

        emit Canceled(address(this), uint64(block.timestamp), BetState.canceled, amountToRefund);
    }

    /**
     * @notice Resolve the bet and allow winners to claim
     * @param position Position that won
     */
    function resolve(uint256 position) external override updateState onlyBetCreator {
        if (s_state != BetState.ended) {
            revert Bet__InvalidState(s_state);
        }

        if (position > s_positions.length) {
            revert Bet__PositionInvalid(position, s_positions.length);
        }

        s_wonPosition = position;
        s_state = BetState.resolved;

        emit Resolved(address(this), uint64(block.timestamp), BetState.resolved, position);
    }

    /**
     * @notice Join the bet
     * @param amount Amount to bet
     * @param position Position to bet on
     */
    function join(uint256 amount, uint256 position) external override updateState {
        if (s_state != BetState.started) {
            revert Bet__InvalidState(s_state);
        }

        if (amount == 0) {
            revert Bet__AmountCantBeZero();
        }

        if (position > s_positions.length) {
            revert Bet__PositionInvalid(position, s_positions.length);
        }

        if (!s_players[msg.sender]) {
            s_players[msg.sender] = true;
            s_count++;
        }

        s_betAmount[msg.sender][position] += amount;
        s_pools[position] += amount;

        IERC20(i_token).safeTransferFrom(msg.sender, address(this), amount);

        emit Joined(address(this), msg.sender, position, amount);
    }

    /**
     * @notice User claims his rewards, the contract allow only one position to win, the other positions lose
     * @dev Computing the amount to claim : (userBet * totalPoolAmount) / wonPoolAmount;
     */
    function claim() external override updateState returns (uint256 amount) {
        if (!s_players[msg.sender]) {
            revert Bet__NotParticipating();
        }

        if (s_state != BetState.resolved) {
            revert Bet__InvalidState(s_state);
        }

        if (s_betAmount[msg.sender][s_wonPosition] == 0) {
            amount = 0;
        } else {
            amount = _computingWinAmount(s_wonPosition);
            s_betAmount[msg.sender][s_wonPosition] = 0;

            IERC20(i_token).safeTransfer(msg.sender, amount);
            emit Claimed(address(this), msg.sender, amount);
        }
    }

    /**
     * @notice Get the factory address
     * @return Factory address
     */
    function getFactory() external view override returns (address) {
        return i_factory;
    }

    /**
     * @notice Get the token address
     * @return Token address
     */
    function getToken() external view override returns (address) {
        return i_token;
    }

    /**
     * @notice Get the creator address
     * @return Creator address
     */
    function getCreator() external view override returns (address) {
        return i_creator;
    }

    /**
     * @notice Get the start date
     * @return Start date
     */
    function getStartDate() external view override returns (uint64) {
        return i_startDate;
    }

    /**
     * @notice Get the end date
     * @return End date
     */
    function getEndDate() external view override returns (uint64) {
        return i_endDate;
    }

    /**
     * @notice Get the positions
     * @return Positions
     */
    function getPosition(uint256 index) external view override returns (string memory) {
        return s_positions[index];
    }

    /**
     * @notice Get the pool
     * @param index Index of the pool
     * @return Pool amount
     */
    function getPool(uint256 index) external view override returns (uint256) {
        return s_pools[index];
    }

    /**
     * @notice Get the state
     * @return State
     */
    function getState() external view override returns (BetState) {
        return s_state;
    }

    /**
     * @notice Get the count of players
     * @return Count of players
     */
    function getCount() external view override returns (uint256) {
        return s_count;
    }

    /**
     * @notice Get the won position
     * @return The won position
     */
    function getWonPosition() external view override returns (uint256) {
        return s_wonPosition;
    }

    /**
     * @notice Get the bet amount for a player
     * @param player Player address
     * @param position Position to get bet amount
     * @return Bet amount
     */
    function getBetAmount(address player, uint256 position) external view override returns (uint256) {
        return s_betAmount[player][position];
    }

    /**
     * @notice Get the potential amount to win for a position
     * @param position Position to calcul winning amount
     */
    function getPotentialWin(uint256 position) external view override returns (uint256) {
        return _computingWinAmount(position);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Compute the amount to win
     * @dev Computing the amount to claim : (userBet * totalPoolAmount) / wonPoolAmount;
     * @param winningPosition Position to calcul winning amount
     * @return Amount to win
     */
    function _computingWinAmount(uint256 winningPosition) private view returns (uint256) {
        uint256 betAmount = s_betAmount[msg.sender][winningPosition];
        uint256 winTotalAmount = s_pools[winningPosition];
        uint256 totalAmount = IERC20(i_token).balanceOf(address(this));

        if (betAmount == 0 || winTotalAmount == 0 || totalAmount == 0) {
            return 0;
        }

        return betAmount.mulDiv(totalAmount, winTotalAmount);
    }
}
