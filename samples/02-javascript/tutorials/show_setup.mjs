console.log('HTTPS server:', process.env.DESKCITE_URL);
console.log('Private credential file configured:', Boolean(process.env.DESKCITE_TOKEN_FILE));
console.log('Trusted certificate configured:', Boolean(process.env.NODE_EXTRA_CA_CERTS));
console.log('WSS broker:', process.env.MESGD_WSS);
console.log('Messaging credential configured:', Boolean(process.env.MESGD_TOKEN));
