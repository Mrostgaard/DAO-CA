pragma solidity ^0.5.3;

//The minimally viable DAO.
//Has the following functionality:
// - Vote to include new member
// - Vote to kick member
// Needs the following added to interact with CT:
// - Members of DAO may activate functionality in CT contract

contract MinDAO {
    address initialOwner;
    mapping (address => bool) addressIsMember;
    mapping (uint => Proposal) proposals;
    uint numMembers;
    uint numProposals;

    struct Proposal {
        address subject;
        uint16 yays;
        uint16 nays;
        bool isKick;
        mapping(address => bool) hasVoted;
    }

    constructor() public {
        initialOwner = msg.sender;
        numMembers = 1;
        numProposals = 0;
        addressIsMember[initialOwner] = true;
    }

    modifier onlyMember(){
        require(addressIsMember[msg.sender]);
        _;
    }

    function proposeNewMember(address newMember) external onlyMember returns (uint) {
        Proposal memory prop = Proposal(newMember, 0, 0, false);
        proposals[numProposals] = prop;
        numProposals++;
        return numProposals - 1;
    }
 
    function proposeKickMember(address kickMember) external onlyMember returns (uint){
        Proposal memory prop = Proposal(kickMember, 0, 0, true);
        proposals[numProposals] = prop;
        numProposals++;
        return numProposals - 1;
    }

    function vote(uint id, bool voteYes) external onlyMember {
        require(proposals[id].subject != address(0x0));
        require(!proposals[id].hasVoted[msg.sender]);
        
        proposals[id].hasVoted[msg.sender] = true;
        if(voteYes){
            proposals[id].yays = proposals[id].yays+1;
        } else {
            proposals[id].yays = proposals[id].nays+1;
        }

        if(proposals[id].yays > numMembers / 2){
            addressIsMember[proposals[id].subject] = !proposals[id].isKick;
        }
    }
}
