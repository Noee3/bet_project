// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Bet} from "../Bet.sol";

interface IBetFactory {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error BetFactory__TokensCantBeEmpty();
    error BetFactory__AddressCantBeZero();
    error BetFactory__PositionCantBeZero();
    error BetFactory__PositionExceeded(uint256 maxPosition, uint256 length);
    error BetFactory__PositionsMustBeGreater(uint256 length);
    error BetFactory__DateMustBeGreaterOrEqualNow(uint64 date);
    error BetFactory__EndDateBeforeStartDate(uint64 startDate, uint64 endDate);
    error BetFactory__PositionInvalid(uint256 position, uint256 length);

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event CreatedBet(
        address indexed betAddress, address indexed creator, uint256 position, uint256 betAmount, address tokenIn
    );

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createBet(
        uint64 startDate,
        uint64 endDate,
        string[] calldata positions,
        uint256 position,
        uint256 betAmount,
        address tokenIn,
        string calldata description
    ) external returns (Bet);

    function getToken() external view returns (address);

    function getMaxPosition() external view returns (uint256);

    function getBets(uint256 index) external view returns (address);

    function getBetCreator(address bet) external view returns (address);

    function getBetCount() external view returns (uint256);
}
