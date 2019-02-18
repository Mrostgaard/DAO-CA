pragma solidity ^0.4.19;

contract Certificate {
    address owner;
    bytes32 urlHash;
    bytes32 certHash;
    Certificate prevCert;
    
    function Certificate(bytes32 _urlHash, bytes32 _certHash, address _owner, Certificate _prevCert) public {
        owner = _owner;
        certHash = _certHash;
        urlHash = _urlHash;
        prevCert = _prevCert;
    }
    
    function getOwner() public view returns (address) {
        return owner;
    }
    
    function getUrlHash() public view returns (bytes32) {
        return urlHash;
    }

    function getCertHash() public view returns (bytes32) {
        return certHash;
    }

    function getPrevCert() public view returns (Certificate) {
        return prevCert;
    }
}