#!/bin/sh

# Only for Windows (workaround for GIT issue)
export MSYS_NO_PATHCONV=1

# Variables to be updated
CA_NAME="DevCA"
SUB="/C=IN/ST=DEL/L=DEL/O=Home/OU=Home/CN=localhost"
SAN="subjectAltName = DNS:localhost,IP:127.0.0.1"

# Client certificate and Server Truststore password
TRUSTSTORE_PASSWORD="makeitwork"
# Server keystore password
KEYSTORE_PASSWORD="makeitwork"

# CN separator character
IFS=","
# Include all clients(comma separated), certificate will be created for each client
ALL_CLIENT_CN="hsm-server,hsm-ui,hsm-gateway,keycloak"

# Creating directory for storing certificates and keys
mkdir dev-certificates
cd dev-certificates
mkdir -p CA
mkdir -p client

################## CA ##################
# Created CA Private Key
openssl ecparam -genkey -name prime256v1 -out CA/rootCA.key
# Create CA Certificate
openssl req -new -x509 -days 3650 -key CA/rootCA.key -out CA/rootCA.crt -subj "$SUB" -addext "$SAN"

# Generating P12 from crt and key:
openssl pkcs12 -password pass:$KEYSTORE_PASSWORD -export -in CA/rootCA.crt -inkey CA/rootCA.key -out CA/root-ca.p12 -name $CA_NAME

# Create pem file from a p12 file
openssl pkcs12 -in CA/root-ca.p12 -out CA/root-ca.pem -nokeys -passin pass:$KEYSTORE_PASSWORD -passout pass:$KEYSTORE_PASSWORD

# Create truststore with CA certificate
keytool -noprompt -keystore client/truststore.jks -importcert -file CA/root-ca.pem -alias root-ca -storepass $TRUSTSTORE_PASSWORD

echo -e "\e[1m CA Certificate created \e[0m"

################## CLIENT ##################
for CLIENT_CN in $ALL_CLIENT_CN
do
	mkdir -p client/$CLIENT_CN
	if [ "$CLIENT_CN" = "res" ] || [ "$CLIENT_CN" = "kms" ]
	then
		SUB="C=IN/ST=DEL/L=DEL/O=Home/OU=Home/CN=$CLIENT_CN"
		echo -e "\e[1m Client is $CLIENT_CN, so '$CLIENT_CN' will be used as CN value \e[0m"
	else
		SUB="C=IN/ST=DEL/L=DEL/O=Home/OU=Home/CN=localhost"
		echo -e "\e[1m Client is $CLIENT_CN, so 'localhost' will be used as CN value \e[0m"
	fi

	# Create the Client Private Key:
	openssl ecparam -genkey -name prime256v1 -out client/$CLIENT_CN/client-$CLIENT_CN.key
	# Create the client certificate request with client role:
	openssl req -new -key client/$CLIENT_CN/client-$CLIENT_CN.key -out client/$CLIENT_CN/client-$CLIENT_CN.csr -subj "$SUB" -addext "$SAN"

	# Sign the client’s certificate using the CA private key file and public certificate:
	openssl x509 -req -in client/$CLIENT_CN/client-$CLIENT_CN.csr -days 3650 -sha1 -CAcreateserial -CA CA/rootCA.crt -CAkey CA/rootCA.key -out client/$CLIENT_CN/client-$CLIENT_CN.crt

	# Generating P12 from crt and key:
	openssl pkcs12 -password pass:$KEYSTORE_PASSWORD -export -in client/$CLIENT_CN/client-$CLIENT_CN.crt -inkey client/$CLIENT_CN/client-$CLIENT_CN.key -out client/$CLIENT_CN/client-$CLIENT_CN.p12 -name $CLIENT_CN

	# Add the certificate to keystore JKS:
	keytool -noprompt -importkeystore -deststorepass $KEYSTORE_PASSWORD -destkeypass $KEYSTORE_PASSWORD -destkeystore client/$CLIENT_CN/keystore.jks -srckeystore client/$CLIENT_CN/client-$CLIENT_CN.p12 -srcstoretype PKCS12 -srcstorepass $KEYSTORE_PASSWORD -alias $CLIENT_CN

	# Add the certificates in the truststore
	keytool -noprompt -keystore client/$CLIENT_CN/truststore.jks -importcert -file CA/root-ca.pem -alias root-ca -storepass $TRUSTSTORE_PASSWORD




	# Add all certificate to common keystore P12
	openssl pkcs12 -password pass:$KEYSTORE_PASSWORD -export -in client/$CLIENT_CN/client-$CLIENT_CN.crt -inkey client/$CLIENT_CN/client-$CLIENT_CN.key -out client/keystore.p12 -name $CLIENT_CN

	# Add all certificate to common keystore JKS
	keytool -noprompt -importkeystore -deststorepass $KEYSTORE_PASSWORD -destkeypass $KEYSTORE_PASSWORD -destkeystore client/keystore.jks -srckeystore client/keystore.p12 -srcstoretype PKCS12 -srcstorepass $KEYSTORE_PASSWORD -alias $CLIENT_CN

	echo -e "\e[1m Client certificate created and added to truststore for: [$CLIENT_CN] \e[0m"
done
