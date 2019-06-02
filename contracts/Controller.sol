pragma solidity ^0.5.1;

import "./token/MigrateableToken.sol";
import "./CertificateTransparency.sol";

contract ControllerSupplier {
    function createChild(address _parent) public returns (address _newController);
}

contract ControllerFactory {
    function createChild(address _parent) public returns (address _newController) {
        return address(new Controller(_parent, address(this), false));
    }
}

contract Controller{
    
    MigrateableToken public token;
    CertificateTransparency public certificateLog;
    Controller public parent;
    Controller public acceptedChild;
    Controller public rejectedChild;
    ControllerSupplier public childCreator; 
    bool isForked = false;
    mapping(uint => Vote) votes;
    mapping(uint => Cert) certs;
    uint disputeId;
    uint FORK_THRESHOLD = 10;
    uint certCount = 0;
    uint BOUNTY_THRESHOLD = 1000;
    uint MAX_ROUND = 7;
    uint MINIMUM_STAKE = 1;
    uint VOTE_PERIOD_TIME = 3 * 24 * 60 * 60;

    struct Vote {
        uint certId;
        uint accepted;
        uint rejected;
        uint voteStart;
        uint voteEnd;
        uint round;
        uint bounty;
        bool isFinalized;
        mapping(address => uint) stakedAccepted;
        mapping(address => uint) stakedRejected;
    }

    struct Cert {
        uint certId;
        uint expiry;
        string url;
        string certificate;
        address certOwner;
    }

    constructor(address _parent, address _childCreator, bool _isGenesis) public{
        if(_isGenesis){
            parent = Controller(address(0));
            token = new MigrateableToken(_parent, true);
            certificateLog = new CertificateTransparency(address(this));
        } else {
            require(_parent != address(0));
            certificateLog = new CertificateTransparency(address(this));
            parent = Controller(_parent);
            token = new MigrateableToken(address(Controller(_parent).token), false);
        }
        isForked = false;
        childCreator = ControllerSupplier(_childCreator);
    }

    function request(string memory url, string memory certificate, uint expiry, uint bounty) public returns(uint){
        require(token.balanceOf(msg.sender) >= bounty);
        require(bounty >= BOUNTY_THRESHOLD);
        require(token.transfer(address(this), bounty));
        certs[certCount] = Cert(certCount, expiry, url, certificate, msg.sender);
        votes[certCount] = Vote(certCount, 0, 0, now, now + VOTE_PERIOD_TIME, 0, bounty, false);
        certCount += 1;
        return certCount-1;
    }

    function vote(uint _id, uint _choice, uint _amount) external{
        require(now < votes[_id].voteEnd);
        require(now > votes[_id].voteStart);
        uint personalStake = votes[_id].stakedAccepted[msg.sender] + votes[_id].stakedRejected[msg.sender];
        require(personalStake + _amount > MINIMUM_STAKE);
        if(personalStake == 0){ //If nothing has been stked on this outcome yet.
            token.incrementStakes();
        }
        token.stake(_amount + personalStake, certs[_id].expiry);
        if(_choice == 0){
            // Choice 0 = accept certificate
            votes[_id].accepted += _amount;
            votes[_id].stakedAccepted[msg.sender] += _amount;
        } else if(_choice == 1){
            // Choice 1 = reject certificate
            votes[_id].rejected += _amount;
            votes[_id].stakedRejected[msg.sender] += _amount;
        } else {
            revert(); //If people don't make a deliberate correct choice, they will not stake.
        }
    }

    function finalizeVote(uint _id) external {
        require(now > votes[_id].voteEnd);
        require(!votes[_id].isFinalized);
        if(canFinalize(_id)){
            votes[_id].isFinalized = true;
            if(votes[_id].accepted > votes[_id].rejected){
                votes[_id].bounty += votes[_id].rejected;
                certificateLog.ownerSetCertificate(
                    certs[_id].certOwner,
                    keccak256(abi.encode(certs[_id].certificate)),
                    keccak256(abi.encode(certs[_id].url))
                );
            } else {
                votes[_id].bounty += votes[_id].accepted;
            }
        } else if(canFork(_id)){
            fork(_id);
        } else {
            votes[_id].round += 1;
            votes[_id].voteStart = now;
            votes[_id].voteEnd = now + VOTE_PERIOD_TIME;
        }
    }

    function withdraw(uint _id) external {
        require(votes[_id].isFinalized);
        uint staked = 0;
        uint bounty = 0;
        //If contract is forking or forked
        if(disputeId == 0){
            if(votes[_id].accepted > votes[_id].rejected){
                staked = votes[_id].stakedAccepted[msg.sender];
                bounty = votes[_id].bounty * (staked / votes[_id].accepted);
                votes[_id].stakedAccepted[msg.sender] -= staked;
                token.incrementStakes();
                token.transfer(msg.sender, bounty);
             } else {
                staked = votes[_id].stakedRejected[msg.sender];
                bounty = votes[_id].bounty * (staked / votes[_id].rejected);
                votes[_id].stakedRejected[msg.sender] -= staked;
                token.decrementStakes();
                token.transfer(msg.sender, bounty);
             }
        // If contract is forking, but not on this specific vote, let participants withdraw.
        } else if(disputeId != _id){
            staked = votes[_id].stakedRejected[msg.sender] + votes[_id].stakedAccepted[msg.sender];
            votes[_id].stakedAccepted[msg.sender] = 0;
            votes[_id].stakedRejected[msg.sender] = 0;
            if(certs[_id].certOwner == msg.sender){
                staked += votes[_id].bounty;
                votes[_id].bounty = 0;
            }
            token.transfer(msg.sender, staked);
        //If disputed certificate, force migration
        } else {
            staked = votes[_id].stakedAccepted[msg.sender];
            if(staked > 0){
                bounty = votes[_id].bounty * (staked / votes[_id].accepted);
                votes[_id].stakedAccepted[msg.sender] -= staked;
                MigrateableToken(address(acceptedChild.token)).mint(msg.sender, staked + bounty);
            }
            staked = votes[_id].stakedRejected[msg.sender];
            if(staked > 0){
                bounty = votes[_id].bounty * (staked / votes[_id].rejected);
                votes[_id].stakedRejected[msg.sender] -= staked;
                MigrateableToken(address(rejectedChild.token)).mint(msg.sender, staked + bounty);
            }
        }
    }

    function canFinalize(uint _id) public view returns (bool){
        //Can finialize if the less votes option is below the threshold.
        if(min(votes[_id].accepted, votes[_id].rejected) < roundThreshold(votes[_id].round)){
            if(now > votes[_id].voteEnd){
                return true;
            }
        }
        return false;
    }

    function canFork(uint _id) public view returns (bool){
        //If the more than the maximum roundThreshold dispusted the choice, fork.
        if(min(votes[_id].accepted, votes[_id].rejected) > roundThreshold(MAX_ROUND)){
            return true;
        }
        return false;
    }

    function fork(uint certId) public {
        require(canFork(certId));
        //1. Create new controller
        token.fork();
        acceptedChild = Controller(childCreator.createChild(address(this)));
        rejectedChild = Controller(childCreator.createChild(address(this)));
        //2. Create new accepted certificate in acceptedChild history
        
        acceptedChild.parentForceCert(
            certs[certId].certOwner,
            keccak256(abi.encode(certs[certId].certificate)),
            keccak256(abi.encode(certs[certId].url))
        );
        
        disputeId = certId;
    }
    
    function parentForceCert(address certOwner, bytes32 certificate, bytes32 url) external {
        require(msg.sender == address(parent));
        certificateLog.ownerSetCertificate(certOwner, certificate, url);
    }
    
    function min(uint a, uint b) internal pure returns (uint){
        if(a < b){
            return a;
        }
        return b;
    }

    function getBalance() public view returns (uint){
        return token.balanceOf(msg.sender);
    }
    
    function roundThreshold(uint round) public view returns (uint){
        return token.totalSupply()*FORK_THRESHOLD/100/2**(MAX_ROUND-round);
    }
}
