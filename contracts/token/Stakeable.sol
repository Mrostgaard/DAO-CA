pragma solidity ^0.5.1;

import "./BurnableToken.sol";

contract StakeableToken is BurnableToken {

    mapping(address => uint) public staked;
    mapping(address => uint) public release;
    mapping(address => uint) public activeStakes;
    address controller;

    function stake(uint amount, uint release_time) external{
        uint current_balance = this.balanceOf(msg.sender);
        require(current_balance + staked[msg.sender] >= amount);
        if(amount > current_balance){
            staked[msg.sender] += amount - current_balance;
            balances[msg.sender] -= amount - staked[msg.sender];
        }
        if(release[msg.sender] < release_time){
            release[msg.sender] = release_time;
        }
    }

    function withdraw(uint amount) public returns(bool){
        require(staked[msg.sender] > amount);
        require(release[msg.sender] < now);
        require(activeStakes[msg.sender] == 0);
        staked[msg.sender] = staked[msg.sender] - amount;
        balances[msg.sender] += amount;
    }
    
    function incrementStakes() public{
        activeStakes[msg.sender] += 1;
    }
    function decrementStakes() public{
        activeStakes[msg.sender] -= 1;
    }

    function amountStaked(address staker) public view returns (uint){
        return staked[staker];
    }
    function releaseTime(address staker) public view returns (uint){
        return release[staker];
    }
}
