pragma solidity ^0.5.1;

import "./StakeableToken.sol";

contract MigrateableToken is StakeableToken {
   
    address parent;
    address owner;
    bool isForked;
    bool isGenesis;

    constructor(address _parent, bool _isGenesis) public{
        owner = msg.sender;
        if(_isGenesis){
            parent = address(0);
            isGenesis = _isGenesis;
            mint(_parent, 10*10**12);
            mint(msg.sender, 10*10**13);
        } else {
            parent = _parent;
        }
        isForked = false;
    }

    function transfer(address _to, uint256 _value) public returns (bool){
        require(!isForked);
        return super.transfer(_to, _value);
    }

    function mint(address migrater, uint amount) public{
        //require(msg.sender == parent);
        totalSupply_ += amount;
        balances[migrater] += amount;
    }

    function migrate(MigrateableToken child, uint amount) external{
        //Call mint on child and burn tokens
        super.burn(amount);
        child.mint(msg.sender, amount);
    }
}

