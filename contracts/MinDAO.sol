pragma solidity 0.5.3;

//The minimally viable DAO.
//Has the following functionality:
// - Vote to include new member
// - Vote to kick member
// Needs the following added to interact with CT:
// - Members of DAO may activate functionality in CT contract

contract MinDAO {
    address initialOwner;
    mapping (address => bool) isMember;
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

    MinDAO() {
        initialOwner = msg.sender();
        numMembers = 1;
        numProposals = 0;
        isMember.set(initialOwner, true);
    }

    function proposeNewMember(address newMember) return (uint){
        Proposal prop = Proposal(newMember, 0, 0, new mapping(address => bool), false);
        proposals.set(numProposals, prop);
        numProposals++;
        return numProposals - 1;
    }
 
    function proposeKickMember(address kickMember) return (uint){
        Proposal prop = Proposal(kickMember, 0, 0, new mapping(address => bool), true);
        proposals.set(numProposals, prop);
        numProposals++;
        return numProposals - 1;
    }

    function vote(uint id, bool voteYes) {
        Proposal prop = proposals.get(id);
        require(prop.subject != address(0x0));
        require(!prop.hasVoted.get(msg.sender));
        
        if(voteYes){
            prop = Proposal(prop.subject, prop.yays+1, prop.nays, prop.isKick, prop.hasVoted.set(msg.sender, true));
        } else {
            prop = Proposal(prop.subject, prop.yays, prop.nays+1, prop.isKick, prop.hasVoted.set(msg.sender, true));
        }

        proposals.set(id, prop);

        if(prop.yays > numMembers / 2){
            isMember.set(prop.subject, !prop.isKick);
        }
    }
}
