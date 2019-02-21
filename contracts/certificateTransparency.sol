pragma solidity ^0.4.22;

contract CertificateTransparency{
    struct Certificate {
        //Owner might need to be specified by something other than an address in the future
        address owner;
        bytes urlHash;
        //If I'm not wrong, they only save a hash of the certificate, and not the certificate itself.
        //May be worth investigating if we should implement something closer to the X.509 standard
        bytes certHash;
    }

    //Owner contract which can operate the inner workings of the CT contract
    address owner;

    //Certificate storage, right now it uses a simple incrementing id system
    //May be smarter to simply use an array/list?
    mapping(uint256 => Certificate) certificates;

    //Current number of certificates
    uint certNum;

    modifier onlyOwner {
        require(owner == msg.sender);
        _;
    }
    function CertificateTransparency(address _owner){
        owner = _owner;
        certNum = 0;
    }
    
    //Might be easier to hash url on-chain, but this is cheaper, and arguably more private
    function setCertificate(Certificate inputCert, bytes hashedUrl) public onlyOwner {
        if(certificates[hashedUrl].owner == address(0x0)){
            certNum++;
        }
        certificates[hashedUrl] = inputCert;
    }
    
    function getCertificate(bytes hashedUrl) public return (Certificate) {
        return certificates[hashedUrl]
    }

    //Add functionality to check if certficate is already added
    function add(string _url, string _certificate, address owner) public onlyOwner {
        bytes hashedInput = keccak256(_toLower(_url));
        bytes certHash = sha256(_certificate);
        Certificate oldCert = Certificates.get(hashedInput);
        require(oldCert.getOwner() == owner));
        
        setCertificate(Certificate(owner, hashedInput, certHash), hashedInput);
    }

    function check(bytes hashedUrl, string _certificate) public view returns (bool) {
        require(address(cert) == address(0x0));
        Certificate cert = getCertificate(hashedUrl);
        bytes hashedCert = sha256(_certificate);
        return cert.getCertHash() == hashedCert;
    }

    function transferCertificateOwnership(address _newOwner, bytes hashedUrl) public onlyOwner {
        Certificate cert = getCertificate(hashedIrl);
        require(cert.owner != address(0x0));
        require(cert.getOwner() == msg.sender);
        certificates[hashedUrl] = Certificate(_owner, cert.urlHash, cert.certHash);
    }

    //Probably unnecessary to be able to transfer ownership for now, but may come in handy. 
    function transferOwnership(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }
 
    // Changes a string from uppercase to lowercase.
    // https://gist.github.com/thomasmaclean/276cb6e824e48b7ca4372b194ec05b97
    function _toLower(string str) private pure returns (string)  {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint i = 0; i < bStr.length; i++) {
            // Uppercase character...
            if ((bStr[i] >= 65) && (bStr[i] <= 90)) {
                // So we add 32 to make it lowercase
                bLower[i] = bytes1(int(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }
}
