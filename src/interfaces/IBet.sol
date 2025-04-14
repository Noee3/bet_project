// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IBet {
    /*//////////////////////////////////////////////////////////////
                                  DATA
    //////////////////////////////////////////////////////////////*/

    enum BetState {
        waiting,
        started,
        ended,
        resolved,
        canceled
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Bet__AddressCantBeZero(address addr);
    error Bet__NotBetCreator();
    error Bet__NotFactory();
    error Bet__NotStarted();
    error Bet__InvalidState(BetState bet);
    error Bet__ParticipantsIn();
    error Bet__Canceled();
    error Bet__AmountCantBeZero();
    error Bet__PositionInvalid(uint256 position, uint256 length);
    error Bet__NotParticipating();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Canceled(address indexed bet, uint64 indexed date, BetState state, uint256 refund);
    event Resolved(address indexed bet, uint64 indexed date, BetState state, uint256 position);
    event Claimed(address indexed bet, address indexed user, uint256 amount);
    event Joined(address indexed bet, address indexed user, uint256 position, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function cancel() external;
    function resolve(uint256 position) external;
    function join(uint256 amount, uint256 position) external;
    function claim() external returns (uint256 amount);

    function getFactory() external view returns (address);
    function getToken() external view returns (address);
    function getCreator() external view returns (address);
    function getStartDate() external view returns (uint64);
    function getEndDate() external view returns (uint64);
    function getPosition(uint256 index) external view returns (string memory);
    function getPool(uint256 index) external view returns (uint256);
    function getState() external view returns (BetState);
    function getCount() external view returns (uint256);
    function getWonPosition() external view returns (uint256);
    function getBetAmount(address player, uint256 position) external view returns (uint256);
    function getPotentialWin(uint256 position) external view returns (uint256);
}
