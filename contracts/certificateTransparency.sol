pragma solidity ^0.5.3;


contract CertificateTransparency{
    struct Certificate {
        //Owner might need to be specified by something other than an address in the future
        address owner;
        bytes32 urlHash;
        //If I'm not wrong, they only save a hash of the certificate, and not the certificate itself.
        //May be worth investigating if we should implement something closer to the X.509 standard
        bytes32 certHash;
    }

    //Owner contract which can operate the inner workings of the CT contract
    address owner;

    //Certificate storage, right now it uses a simple incrementing id system
    //May be smarter to simply use an array/list?
    mapping(bytes32 => Certificate) certificates;

    //Current number of certificates
    uint certNum;

    modifier onlyOwner {
        require(owner == msg.sender);
        _;
    }
    
    constructor() public{
        owner = msg.sender;
        certNum = 0;
    }
    
    //Might be easier to hash url on-chain, but this is cheaper, and arguably more private
    function setCertificate(address certOwner, bytes32 certHash, bytes32 hashedUrl) public onlyOwner {
        if(hasCertificate(hashedUrl)){
            certNum++;
        }
        certificates[hashedUrl] = Certificate(certOwner, certHash, hashedUrl);
    }
    
    function hasCertificate(bytes32 hashedUrl) public view returns (bool) {
        if(certificates[hashedUrl].owner == address(0x0)){
            return true;
        } else {
            return false;
        }
    }

    //Add functionality to check if certficate is already added
    function add(string memory _url, string memory _certificate, address certOwner) public onlyOwner {
        bytes32 hashedInput = keccak256(abi.encode(_toLower(_url)));
        bytes32 certHash = sha256(abi.encode(_certificate));
        Certificate memory oldCert = certificates[hashedInput];
        require(oldCert.owner == certOwner);
        
        setCertificate(owner, hashedInput, certHash);
    }

    //Might be possible to attack by creating a malformed Certificate equivalent to the default Certificate
    function check(bytes32 hashedUrl, string memory _certificate) public view returns (bool) {
        Certificate memory cert = certificates[hashedUrl];
        bytes32 hashedCert = sha256(abi.encode(_certificate));
        return cert.certHash == hashedCert;
    }

    function transferCertificateOwnership(address _newOwner, bytes32 hashedUrl) external {
        require(certificates[hashedUrl].owner == msg.sender);
        certificates[hashedUrl].owner = _newOwner;
    }

    //Probably unnecessary to be able to transfer ownership for now, but may come in handy. 
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
