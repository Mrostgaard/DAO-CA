pragma solidity ^0.4.19;

import "./certificate.sol";

contract datastore {
    address owner;
    mapping(bytes32 => uint256) pointers;
    Certificate[] certificates;
    
    function datastore() public {
        owner = msg.sender;
        certificates.push(Certificate(address(0x0)));
    }
    
    // Should get be owner only, is there a reason for keeping it
    // open, is there a security reason to keep it closed?
    function get(bytes32 _input) public view onlyOwner returns (Certificate) {
        if(_input == 0) {
            return certificates[0];
        }
        return certificates[pointers[_input]];
    }
    
    function set(Certificate _inputCert, bytes32 _inputPosition) public onlyOwner {
        uint256 inputId = certificates.push(_inputCert) - 1;
        pointers[_inputPosition] = inputId;
    }
    
    function transferOwnership(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }
    
    // Only allow owner (DCT contract) to interact
    modifier onlyOwner {
        require(owner == msg.sender);
        _;
    }
}