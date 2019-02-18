pragma solidity ^0.4.19;

import "./certificate.sol";
import "./datastore.sol";

contract DCT {
    address owner;
    datastore dstore;
    uint16 version;

    function DCT(bool withDatastore) public {
        if(withDatastore)
            dstore = new datastore();
        else
            dstore = datastore(0x0);
        owner = msg.sender;
        version = 3;
    }

    /// Add a new certificate to chain.
    function add(string _url, string _certificate) public returns (bool) {
        bytes32 hashedInput = keccak256(_toLower(_url));
        bytes32 certHash = sha256(_certificate);
        Certificate oldCert = dstore.get(hashedInput);

        if (oldCert == address(0x0)) {
            dstore.set(new Certificate(hashedInput, certHash, msg.sender, dstore.get(0)), hashedInput);
            return true;
        } else {
            if (oldCert.getOwner() == msg.sender) {
                dstore.set(new Certificate(hashedInput, certHash, msg.sender, oldCert), hashedInput);
                return true;
            }
        }
        return false;
    }
    
    function get(string _url) public view returns (Certificate) {
        return dstore.get(keccak256(_toLower(_url)));
    }
    
    function check(string _url, string _certificate) public view returns (bool) {
        Certificate cert = get(_url);
        if(address(cert) == address(0x0)) return false;
        bytes32 hashedCert = sha256(_certificate);
        while(address(cert) != address(0x0) && cert.getCertHash() != hashedCert)
            cert = cert.getPrevCert();
        return address(cert) != address(0x0) && cert.getCertHash() == hashedCert;
    }
    
    function transferOwnership(address _newOwner, string _url) public returns (bool) {
        Certificate _cert = get(_url);
        if (_cert != address(0x0)) {
            if(_cert.getOwner() == msg.sender) {
                dstore.set(new Certificate(
                    _cert.getUrlHash(),
                    _cert.getCertHash(),
                    _newOwner,
                    _cert
                ), _cert.getUrlHash());
                return true;
            }
        }
        return false;
    }
    
    function upgradeContract(DCT _newAddress) public onlyOwner returns (bool) {
        if(_newAddress.getVersion() > getVersion()) {
            dstore.transferOwnership(_newAddress);
            selfdestruct(_newAddress);
            return true;
        }
        return false;
    }
    
    function getDatastore() public view onlyOwner returns (datastore) {
        return dstore;
    }
    
    function importDatastore(datastore _dstore) public onlyOwner returns (bool) {
        if(dstore == address(0x0)) {
            dstore = _dstore;
            return true;
        }
        return false;
    }
    
    function getVersion() public view returns (uint16) {
        return version;
    }
    
    // Only allow owner (DCT contract) to interact
    modifier onlyOwner {
        require(owner == msg.sender);
        _;
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