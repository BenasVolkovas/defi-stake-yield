// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract TokenFarm is Ownable {
    address[] public allowedTokens;
    address[] public stakers;
    mapping(address => mapping(address => uint256)) public stakingBalance;
    mapping(address => uint256) public uniqueTokensStaked;
    mapping(address => address) public tokenToPriceFeed;
    IERC20 public dappToken;

    constructor(address _dappTokenAddress) public {
        dappToken = IERC20(_dappTokenAddress);
    }

    function setPriceFeedContract(address _token, address _priceFeed)
        public
        onlyOwner
    {
        tokenToPriceFeed[_token] = _priceFeed;
    }

    function tokenIsAllowed(address _token) public returns (bool) {
        for (uint256 index = 0; index < allowedTokens.length; index++) {
            if (allowedTokens[index] == _token) {
                return true;
            }
        }
        return false;
    }

    function addAllowedToken(address _token) public onlyOwner {
        allowedTokens.push(_token);
    }

    function updateUniqueTokensStaked(address _user, address _token) internal {
        if (stakingBalance[_token][_user] <= 0) {
            uniqueTokensStaked[_user] += 1;
        }
    }

    // stake tokens
    function stakeTokens(uint256 _amount, address _token) public {
        require(_amount > 0, "Amount must be more than 0");
        require(tokenIsAllowed(_token), "Token is currently not allowed");

        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        updateUniqueTokensStaked(msg.sender, _token);
        stakingBalance[_token][msg.sender] += _amount;

        if (uniqueTokensStaked[msg.sender] == 1) {
            stakers.push(msg.sender);
        }
    }

    function getUserTotalValue(address _user) public view returns (uint256) {
        require(uniqueTokensStaked[_user] > 0, "No tokens staked!");
        uint256 totalValue = 0;

        for (uint256 index = 0; index < allowedTokens.length; index++) {
            totalValue += getUserSingleTokenValue(_user, allowedTokens[index]);
        }

        return totalValue;
    }

    function getUserSingleTokenValue(address _user, address _token)
        public
        view
        returns (uint256)
    {
        if (uniqueTokensStaked[_user] <= 0) {
            return 0;
        }

        // get price of the token
        (uint256 price, uint256 decimals) = getTokenValue(_token);

        return ((stakingBalance[_token][_user] * price) / (10**decimals));
    }

    function getTokenValue(address _token)
        public
        view
        returns (uint256, uint256)
    {
        address priceFeedAddress = tokenToPriceFeed[_token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            priceFeedAddress
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint256 decimals = uint256(priceFeed.decimals());
        return (uint256(price), decimals);
    }

    // issue tokens
    function issueTokens() public onlyOwner {
        for (uint256 index = 0; index < stakers.length; index++) {
            address recipient = stakers[index];
            uint256 userTotalValue = getUserTotalValue(recipient);
            dappToken.transfer(recipient, userTotalValue);
        }
    }

    // unstake tokens
    function unstakeTokens(address _token) public {
        uint256 balance = stakingBalance[_token][msg.sender];
        require(balance > 0, "Staking balance cannot be 0");
        stakingBalance[_token][msg.sender] = 0;
        uniqueTokensStaked[msg.sender] -= 1;
        IERC20(_token).transfer(msg.sender, balance);
    }
}
