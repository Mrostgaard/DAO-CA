import * as asn1js from 'asn1js';
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

async function testCertificate(url, hashedCertificate) {
  let data = await contractInstance.methods.check(url, hashedCertificate).call()
    .then()
    .catch(err => {
      console.log(err);
      return null;
    });
    return data;
}

export const verifyCertificate = async (SHA256, URLS) => {
  const endpoint = 'https://ropsten.infura.io/26802bf155a14df3b0facbeb81f1277a';
  //const endpoint = 'https://mainnet.infura.io/26802bf155a14df3b0facbeb81f1277a';
  const web3 = new Web3(new Web3.providers.HttpProvider(endpoint));
  
  const address = '0x9e02DD54f77F0e05cB47e386Fb68431Cd5efFf76';
 
  var abi = [{
    "constant": true,
    "inputs": [{
        "name": "url",
        "type": "string"
      },
      {
        "name": "hashedCertificate",
        "type": "bytes32"
      }
    ],
    "name": "check",
    "outputs": [{
      "name": "",
      "type": "bool"
    }],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  }];
  var contractInstance = web3.eth.Contract(abi, address);

  console.log(contractInstance.options.jsonInterface);
  console.log(contractInstance.options.address);

  var return_value = false;
  for (var i = 0; i < URLS.length; i++) {
    const url = URLS[i][1];
    if (!url.includes("*.")) { //Check if url is just a *.domain-name.tld, if so, ignore it. 
      return_value = testCertificate(url, web3.utils.fromAscii(SHA256));
      if (return_value == null){
        return 'yellow';
      }
      if (return_value){
        break;
      }

    }
  }
  if (return_value) {return 'green';}
  else{return 'red';}

}