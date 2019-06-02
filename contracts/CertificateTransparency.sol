
pragma solidity ^0.5.1;

contract CertificateTransparency{
    struct Certificate {
        address owner;
        bytes32 urlHash;
        bytes32 certHash;
    }

    //Owner contract which can operate the inner workings of the CT contract
    address owner;

    //Certificates are indexed by their hashed URLs
    mapping(bytes32 => Certificate) certificates;

    //Current number of certificates
    uint certNum;

    modifier onlyOwner {
        require(owner == msg.sender);
        _;
    }
    
    constructor(address _owner) public{
        owner = _owner;
        certNum = 0;
    }
    
    //Might be easier to hash url on-chain, but this is cheaper, and arguably more private
    function ownerSetCertificate(address certOwner, bytes32 certHash, bytes32 hashedUrl) external onlyOwner returns(bytes32){
        return setCertificate(certOwner, certHash, hashedUrl);
    }
    
    function setCertificate(address certOwner, bytes32 certHash, bytes32 hashedUrl) internal onlyOwner returns (bytes32) {
        if(newCertificate(hashedUrl)){
            certNum++;
        }
        certificates[hashedUrl] = Certificate(certOwner, hashedUrl, certHash);
        return hashedUrl;
    }
    
    function newCertificate(bytes32 hashedUrl) public view returns (bool) {
        if(certificates[hashedUrl].owner == address(0x0)){
            return true;
        } else {
            return false;
        }
    }

    function add(string memory _url, string memory _certificate, address certOwner) public onlyOwner returns(bytes32){
        bytes32 hashedInput = keccak256(abi.encode(_toLower(_url)));
        bytes32 certHash = keccak256(abi.encode(_certificate));
        address oldOwner = certificates[hashedInput].owner;
        if(oldOwner != address(0)){
            require(oldOwner == certOwner);
        }
        return setCertificate(owner, certHash, hashedInput);
    }
    
    function check(bytes32 hashedUrl, bytes32 hashedCert)public view returns (bool) {
        require(certificates[hashedUrl].certHash != 0);
        require(hashedCert != 0);
        return certificates[hashedUrl].certHash == hashedCert;
    }

    function transferCertificateOwnership(address _newOwner, bytes32 hashedUrl) external {
        require(certificates[hashedUrl].owner == msg.sender);
        certificates[hashedUrl].owner = _newOwner;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }
 
    // Changes a string from uppercase to lowercase.
    // https://gist.github.com/thomasmaclean/276cb6e824e48b7ca4372b194ec05b97
    function _toLower(string memory str) private pure returns (string memory)  {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint i = 0; i < bStr.length; i++) {
            // Uppercase character...
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                // So we add 32 to make it lowercase
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }
}

