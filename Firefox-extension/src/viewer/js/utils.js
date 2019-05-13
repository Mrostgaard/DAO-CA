import * as asn1js from 'asn1js';
import { strings } from './strings.js';
import {
  fromBase64,
  stringToArrayBuffer
} from 'pvutils';
import Web3 from 'web3';


export const b64urltodec = (b64) => {
  return new asn1js.Integer({
    valueHex: stringToArrayBuffer(fromBase64('AQAB', true, true))
  }).valueBlock._valueDec;
};


export const b64urltohex = (b64) => {
  const hexBuffer = new asn1js.Integer({
    valueHex: stringToArrayBuffer(fromBase64(b64, true, true))
  }).valueBlock._valueHex;
  const hexArray = Array.from(new Uint8Array(hexBuffer));

  return hexArray.map(b => ('00' + b.toString(16)).slice(-2));
};

export const hash = async (algo, buffer) => {
  const hashBuffer = await crypto.subtle.digest(algo, buffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));

  return hashArray.map(b => ('00' + b.toString(16)).slice(-2)).join(':').toUpperCase();
};

export const hashify = (hash) => {
  if (typeof hash === 'string') {
    return hash.match(/.{2}/g).join(':').toUpperCase();
  } else {
    return hash.join(':').toUpperCase();
  }
}

// this particular prototype override makes it easy to chain down complex objects
export const getObjPath = (obj, path) => {
  for (var i = 0, path = path.split('.'), len = path.length; i < len; i++) {
    if (Array.isArray(obj[path[i]])) {
      obj = obj[path[i]][path[i + 1]];
      i++;
    } else {
      obj = obj[path[i]];
    }

  };

  return obj;
};

async function testCertificate(url, hashedCertificate, contractInstance) {
  console.log(url);
  console.log(hashedCertificate)
  let data = await contractInstance.methods.check(url, hashedCertificate).call()
    .then(val => {
      return val;
    })
    .catch(err => {
      return false;
    });
    return data;
}

export const verifyCertificate = async (publicKey, expiryDate, values) => {

    //Clean public key to fit the format expected.
  var publicKeyInfo = "";
  if (publicKey.n) {
    publicKeyInfo = publicKey.n.replace(/:/g, " ");
  }
  else if (publicKey.xy){
    publicKeyInfo = publicKey.xy.replace(/:/g, " ");
  }

    
  //Get Common Name
  var commonName = "";
  values.forEach(dn => {
    const name = strings.names[dn.type];
    const value = dn.value.valueBlock.value;

    if (name.short === 'cn') {
      commonName = value;
      //console.log(value);
    }
  });


    //Create string to send. 
  var infoString = publicKeyInfo + " " + expiryDate.getTime().toString() + " " + commonName;
 
  
  const endpoint = 'https://ropsten.infura.io/26802bf155a14df3b0facbeb81f1277a';
  //const endpoint = 'https://mainnet.infura.io/26802bf155a14df3b0facbeb81f1277a';
  const web3 = new Web3(new Web3.providers.HttpProvider(endpoint));
  
  const address = '0x6aeA54F95a8776C91e51D989BFB7f4B00bba3F9c';
 
  var hashedCommmonName = web3.utils.keccak256(commonName);

  var abi = [
    {
      "constant": false,
      "inputs": [
        {
          "name": "_url",
          "type": "string"
        },
        {
          "name": "_certificate",
          "type": "string"
        },
        {
          "name": "certOwner",
          "type": "address"
        }
      ],
      "name": "add",
      "outputs": [
        {
          "name": "",
          "type": "bytes32"
        }
      ],
      "payable": false,
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "constant": false,
      "inputs": [
        {
          "name": "certOwner",
          "type": "address"
        },
        {
          "name": "certHash",
          "type": "bytes32"
        },
        {
          "name": "hashedUrl",
          "type": "bytes32"
        }
      ],
      "name": "setCertificate",
      "outputs": [
        {
          "name": "",
          "type": "bytes32"
        }
      ],
      "payable": false,
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "constant": false,
      "inputs": [
        {
          "name": "_newOwner",
          "type": "address"
        },
        {
          "name": "hashedUrl",
          "type": "bytes32"
        }
      ],
      "name": "transferCertificateOwnership",
      "outputs": [],
      "payable": false,
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "constant": false,
      "inputs": [
        {
          "name": "_newOwner",
          "type": "address"
        }
      ],
      "name": "transferOwnership",
      "outputs": [],
      "payable": false,
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [],
      "payable": false,
      "stateMutability": "nonpayable",
      "type": "constructor"
    },
    {
      "constant": true,
      "inputs": [
        {
          "name": "hashedUrl",
          "type": "bytes32"
        },
        {
          "name": "hashedCert",
          "type": "bytes32"
        }
      ],
      "name": "check",
      "outputs": [
        {
          "name": "",
          "type": "bool"
        }
      ],
      "payable": false,
      "stateMutability": "view",
      "type": "function"
    },
    {
      "constant": true,
      "inputs": [
        {
          "name": "hashedUrl",
          "type": "bytes32"
        }
      ],
      "name": "newCertificate",
      "outputs": [
        {
          "name": "",
          "type": "bool"
        }
      ],
      "payable": false,
      "stateMutability": "view",
      "type": "function"
    }
  ];
  var contractInstance = web3.eth.Contract(abi, address);

  var tmp = "yellow";
  tmp = await testCertificate(hashedCommmonName, web3.utils.keccak256(infoString), contractInstance).
    then((val) => {

      if (val) {
        return 'green';
      }
      else{
        return 'red';
      }
  });

    return tmp;

}
