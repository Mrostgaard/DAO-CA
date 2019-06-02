pragma solidity ^0.5.1;
import "./CertificateTransparency.sol";

contract MinDAO {
    address initialOwner;
    CertificateTransparency ct;
    mapping (address => bool) addressIsMember;
    mapping (uint => Proposal) proposals;
    mapping (uint => Request) requests;
    uint numMembers;
    uint numProposals;
    uint numRequests;
    
    struct Request {
        address owner;
        uint bounty;
        string URL;
        string certificate;
        uint16 numAttesters;
        bool issued;
        mapping (address => bool) hasAttested;
    }

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
        ct = new CertificateTransparency(address(this));
    }

    modifier onlyMember(){
        require(addressIsMember[msg.sender]);
        _;
    }
    
    function setCertificate(address _certOwner, bytes32 _certHash, bytes32 _hashedUrl) internal onlyMember {
        ct.ownerSetCertificate(_certOwner, _certHash, _hashedUrl);
    }
    
    function toBytes(uint256 x) internal pure returns (bytes memory b) {
        b = new bytes(32);
        for (uint i = 0; i < 32; i++) {
            b[i] = byte(uint8(x / (2**(8*(31 - i))))); 
        }
    }

    //found @ https://ethereum.stackexchange.com/questions/32003/concat-two-bytes-arrays-with-assembly
    function MergeBytes(bytes memory a, bytes memory b) public pure returns (bytes memory c) {
        // Store the length of the first array
        uint alen = a.length;
        // Store the length of BOTH arrays
        uint totallen = alen + b.length;
        // Count the loops required for array a (sets of 32 bytes)
        uint loopsa = (a.length + 31) / 32;
        // Count the loops required for array b (sets of 32 bytes)
        uint loopsb = (b.length + 31) / 32;
        assembly {
            let m := mload(0x40)
            // Load the length of both arrays to the head of the new bytes array
            mstore(m, totallen)
            // Add the contents of a to the array
            for {  let i := 0 } lt(i, loopsa) { i := add(1, i) } { mstore(add(m, mul(32, add(1, i))), mload(add(a, mul(32, add(1, i))))) }
            // Add the contents of b to the array
            for {  let i := 0 } lt(i, loopsb) { i := add(1, i) } { mstore(add(m, add(mul(32, add(1, i)), alen)), mload(add(b, mul(32, add(1, i))))) }
            mstore(0x40, add(m, add(32, totallen)))
            c := m
        }
    }

    function requestCertificate(string memory _url, string memory _certificate) public payable returns(uint) {
        //We require no minimum payment, as it is up to the attesters, whether or not they want to sign something.
        requests[numRequests] = Request(msg.sender, msg.value,  _url, _certificate, 0, false);
        numRequests += 1;
        return numRequests-1;
    }

    function attestCertificate(uint requestID) external onlyMember {
        //If the member has alreay attested the CSR, they cannot attest it again.
        require(!requests[requestID].hasAttested[msg.sender]);
        requests[requestID].hasAttested[msg.sender] = true;
        requests[requestID].numAttesters += 1;
        //If half or more of the DAO members have attested a certificate, it is finalized on the spot.
        if(requests[requestID].numAttesters > numMembers/2){
            finalizeCertificate(requestID);
        }
    }

    function finalizeCertificate(uint requestID) public {
        require(requests[requestID].numAttesters > numMembers/2);
        bytes32 hashedURL = keccak256(bytes(requests[requestID].URL));
        bytes memory certificateBytes = bytes(requests[requestID].certificate);
        bytes memory urlBytes = bytes(requests[requestID].URL);
        bytes32 certificateHash = keccak256(MergeBytes(certificateBytes, urlBytes));

        setCertificate(requests[requestID].owner, certificateHash, hashedURL);
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
