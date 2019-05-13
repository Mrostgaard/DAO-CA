import * as asn1js from 'asn1js';
import { Certificate } from 'pkijs';
import { ctLogNames } from './ctlognames.js';
import { strings } from './strings.js';
import { b64urltodec, b64urltohex, getObjPath, hash, hashify, verifyCertificate } from './utils.js';



const getX509Ext = (extensions, v) => {
  for (var extension in extensions) {
    if (extensions[extension].extnID === v) {
      return extensions[extension];
    }
  }

  return {
    extnValue: undefined,
    parsedValue: undefined,
  };

};


const parseSubsidiary = (distinguishedNames) => {
  const subsidiary = {
    cn: '',
    dn: [],
    entries: [],
  };

  distinguishedNames.forEach(dn => {
    const name = strings.names[dn.type];
    const value = dn.value.valueBlock.value;

    if (name === undefined) {
      subsidiary.dn.push(`OID.${dn.type}=${value}`);
      subsidiary.entries.push([`OID.${dn.type}`, value]);
    } else if (name.short === undefined) {
      subsidiary.dn.push(`OID.${dn.type}=${value}`);
      subsidiary.entries.push([name.long, value]);
    } else {
      subsidiary.dn.push(`${name.short}=${value}`);
      subsidiary.entries.push([name.long, value]);

      // add the common name for tab display
      if (name.short === 'cn') {
        subsidiary.cn = value;
      }
    }
  });

  // turn path into a string
  subsidiary.dn = subsidiary.dn.join(', ');

  return subsidiary;
};


export const parse = async (der) => {
  const supportedExtensions = [
    '1.3.6.1.4.1.11129.2.4.2',  // embedded scts
    '1.3.6.1.5.5.7.1.1',        // authority info access
    '1.3.6.1.5.5.7.1.24',       // ocsp stapling
    '2.5.29.14',                // subject key identifier
    '2.5.29.15',                // key usages
    '2.5.29.17',                // subject alt names
    '2.5.29.19',                // basic constraints
    '2.5.29.31',                // crl points
    '2.5.29.32',                // certificate policies
    '2.5.29.35',                // authority key identifier
    '2.5.29.37',                // extended key usage
  ];

  // get the current time zone - note that there are some time zones that this doesn't easily
  // match, for whatever reason.  https://github.com/april/certainly-something/issues/21
  let timeZone = new Date().toString().match(/\(([A-Za-z\s].*)\)/);
  if (timeZone === null) {    // America/Chicago
    timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone;
  } else if (timeZone.length > 1) {
    timeZone = timeZone[1];   // Central Daylight Time
  } else {
    timeZone = 'Local Time';  // not sure if this is right, but let's go with it for now
  }

  // parse the DER
  const asn1 = asn1js.fromBER(der.buffer);
  var x509 = new Certificate({ schema: asn1.result });
  x509 = x509.toJSON()

  // convert the cert to PEM
  const certBTOA = window.btoa(String.fromCharCode.apply(null, der)).match(/.{1,64}/g).join('\r\n');

  // get which extensions are critical
  const criticalExtensions = [];
  x509.extensions.forEach(ext => {
    if (ext.hasOwnProperty('critical') && ext.critical === true) {
      criticalExtensions.push(ext.extnID);
    }
  });

  // get the public key info
  let spki = Object.assign({
    crv: undefined,
    e: undefined,
    kty: undefined,
    n: undefined,
    keysize: undefined,
    x: undefined,
    xy: undefined,
    y: undefined,
  }, x509.subjectPublicKeyInfo);

  if (spki.kty === 'RSA') {
    spki.e = b64urltodec(spki.e);                      // exponent
    spki.keysize = b64urltohex(spki.n).length * 8;     // key size in bits
    spki.n = hashify(b64urltohex(spki.n));             // modulus
  } else if (spki.kty === 'EC') {
    spki.kty = 'Elliptic Curve';
    spki.keysize = parseInt(spki.crv.split('-')[1])    // this is a bit hacky
    spki.x = hashify(b64urltohex(spki.x));             // x coordinate
    spki.y = hashify(b64urltohex(spki.y));             // y coordinate
    spki.xy = `04:${spki.x}:${spki.y}`;                // 04 (uncompressed) public key
  }

  // get the keyUsages
  const keyUsages = {
    critical: criticalExtensions.includes('2.5.29.15'),
    purposes: [],
  };

  let keyUsagesBS = getX509Ext(x509.extensions, '2.5.29.15').parsedValue;
  if (keyUsagesBS !== undefined) {
    // parse the bit string, shifting as necessary
    let unusedBits = keyUsagesBS.valueBlock.unusedBits;
    keyUsagesBS = parseInt(keyUsagesBS.valueBlock.valueHex, 16) >> unusedBits;

    // iterate through the bit string
    strings.keyUsages.slice(unusedBits - 1).forEach(usage => {
      if (keyUsagesBS & 1) {
        keyUsages.purposes.push(usage);
      }

      keyUsagesBS = keyUsagesBS >> 1;
    })

    // reverse the order for legibility
    keyUsages.purposes.reverse();
  };

  // get the subjectAltNames
  let san = getX509Ext(x509.extensions, '2.5.29.17').parsedValue;
  if (san && san.hasOwnProperty('altNames')) {
    san = Object.keys(san.altNames).map(x => {
      const type = san.altNames[x].type;

      switch (type) {
        case 4:  // directory
          return [strings.san[type], parseSubsidiary(san.altNames[x].value.typesAndValues).dn]
        case 7:  // ip address
          let address = san.altNames[x].value.valueBlock.valueHex;

          if (address.length === 8) {  // ipv4
            return [strings.san[type], address.match(/.{1,2}/g).map(x => parseInt(x, 16)).join('.')];
          } else if (address.length === 32) {  // ipv6
            return [strings.san[type], address.toLowerCase().match(/.{1,4}/g).join(':').replace(/\b:?(?:0+:?){2,}/, '::')];
          } else {
            return [strings.san[type], 'Unknown IP address'];
          }
        default:
          return [strings.san[type], san.altNames[x].value]
      }
    });
  } else {
    san = [];
  }

  san = {
    altNames: san,
    critical: criticalExtensions.includes('2.5.29.17'),
  };

  // get the basic constraints
  let basicConstraints;
  const basicConstraintsExt = getX509Ext(x509.extensions, '2.5.29.19');
  if (basicConstraintsExt && basicConstraintsExt.parsedValue) {
    basicConstraints = {
      cA: (basicConstraintsExt.parsedValue.cA !== undefined && basicConstraintsExt.parsedValue.cA),
      critical: criticalExtensions.includes('2.5.29.19'),
    };
  }

  // get the extended key usages
  let eKeyUsages = getX509Ext(x509.extensions, '2.5.29.37').parsedValue;
  if (eKeyUsages) {
    eKeyUsages = {
      critical: criticalExtensions.includes('2.5.29.37'),
      purposes: eKeyUsages.keyPurposes.map(x => strings.eKU[x]),
    }
  }

  // get the subject key identifier
  let sKID = getX509Ext(x509.extensions, '2.5.29.14').parsedValue;
  if (sKID) {
    sKID = {
      critical: criticalExtensions.includes('2.5.29.14'),
      id: hashify(sKID.valueBlock.valueHex),
    }
  }

  // get the authority key identifier
  let aKID = getX509Ext(x509.extensions, '2.5.29.35').parsedValue;
  if (aKID) {
    aKID = {
      critical: criticalExtensions.includes('2.5.29.35'),
      id: hashify(aKID.keyIdentifier.valueBlock.valueHex),
    }
  }

  // get the CRL points
  let crlPoints = getX509Ext(x509.extensions, '2.5.29.31').parsedValue;
  if (crlPoints) {
    crlPoints = {
      critical: criticalExtensions.includes('2.5.29.31'),
      points: crlPoints.distributionPoints.map(x => x.distributionPoint[0].value),
    };
  }

  let ocspStaple = getX509Ext(x509.extensions, '1.3.6.1.5.5.7.1.24').extnValue;
  if (ocspStaple && ocspStaple.valueBlock.valueHex === '3003020105') {
    ocspStaple = {
      critical: criticalExtensions.includes('1.3.6.1.5.5.7.1.24'),
      required: true,
    }
  } else {
    ocspStaple = {
      critical: criticalExtensions.includes('1.3.6.1.5.5.7.1.24'),
      required: false,
    }
  }

  // get the Authority Information Access
  let aia = getX509Ext(x509.extensions, '1.3.6.1.5.5.7.1.1').parsedValue;
  if (aia) {
    aia = aia.accessDescriptions.map(x => {
      return {
        location: x.accessLocation.value,
        method: strings.aia[x.accessMethod],
      };
    });
  }

  aia = {
    descriptions: aia,
    critical: criticalExtensions.includes('1.3.6.1.5.5.7.1.1'),
  }

  // get the embedded SCTs
  let scts = getX509Ext(x509.extensions, '1.3.6.1.4.1.11129.2.4.2').parsedValue;
  if (scts) {
    scts = Object.keys(scts.timestamps).map(x => {
      let logId = scts.timestamps[x].logID.toLowerCase();
      return {
        logId: hashify(logId),
        name: ctLogNames.hasOwnProperty(logId) ? ctLogNames[logId] : undefined,
        signatureAlgorithm: `${scts.timestamps[x].hashAlgorithm.replace('sha', 'SHA-')} ${scts.timestamps[x].signatureAlgorithm.toUpperCase()}`,
        timestamp: `${scts.timestamps[x].timestamp.toLocaleString()} (${timeZone})`,
        version: scts.timestamps[x].version + 1,
      }
    });
  } else {
    scts = [];
  }

  scts = {
    critical: criticalExtensions.includes('1.3.6.1.4.1.11129.2.4.2'),
    timestamps: scts,
  }

  // Certificate Policies, this stuff is really messy
  let cp = getX509Ext(x509.extensions, '2.5.29.32').parsedValue;
  if (cp && cp.hasOwnProperty('certificatePolicies')) {
    cp = cp.certificatePolicies.map(x => {
      let id = x.policyIdentifier;
      let name = strings.cps.hasOwnProperty(id) ? strings.cps[id].name : undefined;
      let qualifiers = undefined;
      let value = strings.cps.hasOwnProperty(id) ? strings.cps[id].value : undefined;

      // ansi organization identifiers
      if (id.startsWith('2.16.840')) {
        value = id;
        id = '2.16.840';
        name = strings.cps['2.16.840'].name;
      }

      // statement identifiers
      if (id.startsWith('1.3.6.1.4.1')) {
        value = id;
        id = '1.3.6.1.4.1';
        name = strings.cps['1.3.6.1.4.1'].name;
      }

      if (x.hasOwnProperty('policyQualifiers')) {
        qualifiers = x.policyQualifiers.map(qualifier => {
          let id = qualifier.policyQualifierId;
          let name = strings.cps.hasOwnProperty(id) ? strings.cps[id].name : undefined;
          let value = qualifier.qualifier.valueBlock.value;

          // sometimes they are multiple qualifier subblocks, and for now we'll
          // only return the first one because it's getting really messy at this point
          if (Array.isArray(value) && value.length === 1) {
            value = value[0].valueBlock.value;
          } else if (Array.isArray(value) && value.length > 1) {
            value = '(currently unsupported)';
          }

          return {
            id,
            name,
            value,
          }
        });
      }

      return {
        id,
        name,
        qualifiers,
        value,
      };
    });
  }

  cp = {
    critical: criticalExtensions.includes('2.5.29.32'),
    policies: cp,
  }

  // determine which extensions weren't supported
  let unsupportedExtensions = [];
  x509.extensions.forEach(ext => {
    if (!supportedExtensions.includes(ext.extnID)) {
      unsupportedExtensions.push(ext.extnID);
    }
  });

  // console.log('returning from parse() for cert', x509);

  // the output shell
  return {
    ext: {
      aia,
      aKID,
      basicConstraints,
      crlPoints,
      cp,
      eKeyUsages,
      keyUsages,
      ocspStaple,
      scts: scts,
      sKID,
      san,
    },
    files: {
      der: undefined,
      pem: encodeURI(`-----BEGIN CERTIFICATE-----\r\n${certBTOA}\r\n-----END CERTIFICATE-----\r\n`),
    },
    fingerprint: {
      'sha1': await hash('SHA-1', der.buffer),
      'sha256': await hash('SHA-256', der.buffer),
    },
    issuer: parseSubsidiary(x509.issuer.typesAndValues),
    notBefore: `${x509.notBefore.value.toLocaleString()} (${timeZone})`,
    notAfter: `${x509.notAfter.value.toLocaleString()} (${timeZone})`,
    subject: parseSubsidiary(x509.subject.typesAndValues),
    serialNumber: hashify(getObjPath(x509, 'serialNumber.valueBlock.valueHex')),
    signature: {
      name: strings.signature[getObjPath(x509, 'signature.algorithmId')],
      type: getObjPath(x509, 'signature.algorithmId'),
    },
    subjectPublicKeyInfo: spki,
    unsupportedExtensions,
    version: (x509.version + 1).toString(),
    tmp: {
      'infura': await verifyCertificate(spki, x509.notAfter.value, x509.subject.typesAndValues),
    },
  }
};
