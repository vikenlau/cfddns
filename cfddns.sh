#! /bin/sh

getMachineExternalIP(){
	IP=$(curl -s "${IP_PROVIDER}")
	echo "${IP}"
}

checkEnvironments(){
	CHECKING=$1
	if [ "${!CHECKING}" == "NOT_INITIALIZED" ]
	then
		echo "${CHECKING}"
	fi
}

VERIFY_AUTH_KEY=$(checkEnvironments "AUTH_KEY")
VERIFY_AUTH_EMAIL=$(checkEnvironments "AUTH_EMAIL")
VERIFY_DNS_FQDN=$(checkEnvironments "DNS_FQDN")

FAILED=$VERIFY_AUTH_KEY$VERIFY_AUTH_EMAIL$VERIFY_DNS_FQDN

if [ "$FAILED" != "" ]
then
	echo "Initialization failed ($FAILED)"
	echo "Usage: "
	echo "docker run --rm \\"
	echo "    -e DNS_FQDN=test.example.com \\"
        echo "    -e AUTH_KEY=1234567890abcdef1234567890abcdef \\"
	echo "    -e AUTH_EMAIL=123@pop.com \\"
	echo "    -e IP_PROVIDER=http://ifconfig.me \\"
	echo "    cfdns:0.0.0"
	exit 1
fi

echo "Attempting to set ${DNS_FQDN} to ${IP}..."


# ==== Finding the Zone ID ====
echo "Pulling known ZONES..."

while IFS='.' read -ra FQDN_SEGMENTS; do
	SEGMENT=""
	FOUND="false"

	for (( idx=${#FQDN_SEGMENTS[@]}-1 ; idx>=0 ; idx-- )) ; do
		if [ "$FOUND" == "false" ]; then
			if [ "$SEGMENT" == "" ]; then
				SEGMENT=${FQDN_SEGMENTS[idx]}
			else
				SEGMENT=${FQDN_SEGMENTS[idx]}.$SEGMENT
			fi

			echo "Searching ${SEGMENT}..."
			RESULT=`curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$SEGMENT" -H "X-Auth-Email: ${AUTH_EMAIL}" -H "X-Auth-Key: ${AUTH_KEY}" -H "Content-Type: application/json"`
			RESULTS_COUNT=`echo $RESULT | jq .result_info.count`

			if [ "$RESULTS_COUNT" -ge 2 ]; then
				echo "[DEBUG] Too many results for search term ${SEGMENT}: ${RESULTS_COUNT}."
			elif [ "$RESULTS_COUNT" -eq 0 ]; then
				echo "[DEBUG] No results for search term ${SEGMENT}: ${RESULTS_COUNT}."
			else
				FOUND="true"
				ZONE_ID=`echo $RESULT | jq .result[0].id | sed -e 's/^"//' -e 's/"$//'`
			fi
		fi
	done
done <<< "$DNS_FQDN"

# ==== Finding DNS Record ID ====
echo "Finding DNS Record..."
RESULT=`curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=${DNS_FQDN}&type=${DNS_TYPE}" -H "X-Auth-Email: ${AUTH_EMAIL}" -H "X-Auth-Key: ${AUTH_KEY}" -H "Content-Type: application/json"`
RESULTS_COUNT=`echo $RESULT | jq .result_info.count`

DNS_RECORD_ID=""

if [ "$RESULTS_COUNT" -ge 2 ]; then
	echo "[DEBUG] Too many results for search term ${DNS_FQDN} . ${DNS_TYPE}: ${RESULTS_COUNT}."
elif [ "$RESULTS_COUNT" -eq 0 ]; then
	echo "[DEBUG] No results for search term ${DNS_FQDN} . ${DNS_TYPE}: ${RESULTS_COUNT}."
else
	DNS_RECORD_ID=`echo $RESULT | jq .result[0].id | sed -e 's/^"//' -e 's/"$//'`
fi


# ==== Get External IP Address ====
echo "Getting external IP address"
IP=$(getMachineExternalIP)


echo "[DEBUG] Zone id: ${ZONE_ID}"
echo "[DEBUG] Record id: ${DNS_RECORD_ID}"
echo "[DEBUG] IP: ${IP}"

# ==== Send PUT Request ====
RESULT=`curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${DNS_RECORD_ID}" \
     -H "X-Auth-Email: ${AUTH_EMAIL}" \
     -H "X-Auth-Key: ${AUTH_KEY}" \
     -H "Content-Type: application/json" \
     --data '{"type": "'"${DNS_TYPE}"'", "name": "'"${DNS_FQDN}"'", "content": "'"${IP}"'", "ttl": 120, "proxied": true}'`

RESULT=`echo $RESULT | jq .success`

if [ $RESULT == "true" ]; then
	echo "Successfully updated DDNS IP address for ${DNS_FQDN} to ${IP}."
else
	echo "Failed to update DDNS IP address for ${DNS_FQDN}."
fi
