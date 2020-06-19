#!/bin/bash
# Script to keep Google Domains dynamic DNS IP up to date. Should be run on a frequent cron job or when IP address change is detected.
# API documentation is at https://support.google.com/domains/answer/6147083?hl=en-GB

# The hostname is your domain. The username and password can be found in the DNS tab under Dynamic DNS
HOSTNAME="example.com"
USERNAME="username"
PASSWORD="password"

# Paths for storing data from previous runs and logs
DATA_PATH="/opt/GoogleDynamicDNS"
LOG_PATH="/var/log/GoogleDynamicDNS/log.txt"

CURRENT_IP=$(curl -s https://domains.google.com/checkip)
LAST_IP=$(cat ${DATA_PATH}/ip)
LAST_RUN=$(cat ${DATA_PATH}/success)

# Check to see if last run was successful. If not, exit immediately.
# Google will block Dynamic DNS access for "failure to interpret previous responses correctly" so it's best to be on the safe side.
if [ "$LAST_RUN" != 0 ]; then
	echo "`date`: Last run failed. Check the log, correct the issue, change last run status to 0, and then run again." >> "${LOG_PATH}"
	exit 1
fi

# Check to see if IP address has changed since last run, if it has then update it
if [ "$CURRENT_IP" != "$LAST_IP" ]; then
	# Make the update GET request
	RESPONSE=$(curl https://${USERNAME}:${PASSWORD}@domains.google.com/nic/update?hostname=${HOSTNAME})
	# Interpret the response to the request and log the results
	case $RESPONSE in
		"good ${CURRENT_IP}" | "nochg ${CURRENT_IP}")
			echo $CURRENT_IP > "${DATA_PATH}/ip"
			echo "`date`: ${HOSTNAME} successfully updated to ${CURRENT_IP}." >> "${LOG_PATH}"
			echo "0" > "${DATA_PATH}/success"
			exit 0
			;;
		"nohost")
			echo "`date`: The host ${HOSTNAME} doesn't exist or does not have Dynamic DNS enabled." >> "${LOG_PATH}"
			;;
		"badauth")
			echo "`date`: The username/password combination is not valid for the specified host." >> "${LOG_PATH}"
			;;
		"notfqdn")
			echo "`date`: The supplied hostname ${HOSTNAME} is not a valid fully-qualified domain name." >> "${LOG_PATH}"
			;;
		"badagent")
			echo "`date`: Your Dynamic DNS client is making bad requests. Ensure that the user agent is set in the request." >> "${LOG_PATH}"
			;;
		"abuse")
			echo "`date`: Dynamic DNS access for the hostname ${HOSTNAME} has been blocked due to failure to interpret previous responses correctly." >> "${LOG_PATH}"
			;;
		"911")
			echo "`date`: An error happened on Google's end. Wait 5 minutes and retry." >> "${LOG_PATH}"
			;;
		"conflict A" | "conflict AAAA")
			echo "`date`: A custom A or AAAA resource record conflicts with the update. Delete the indicated resource record withing DNS settings page and try the update again." >> "${LOG_PATH}"
			;;
		*)
			echo "`date`: ${RESPONSE}" >> "${LOG_PATH}"
	esac
	echo 1 > "${DATA_PATH}/success"
	exit 1
fi

exit 0
