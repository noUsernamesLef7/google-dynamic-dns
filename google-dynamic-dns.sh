#!/bin/bash
# Script to keep Google Domains dynamic DNS IP up to date. Should be run on a frequent cron job or when IP address change is detected.
# API documentation is at https://support.google.com/domains/answer/6147083?hl=en-GB

# The hostname is your domain. The username and password can be found in the DNS tab under Dynamic DNS
HOSTNAME="subdomain.example.com"
USERNAME="username"
PASSWORD="password"

# Paths for storing data from previous runs and logs
DATA_PATH="/opt/google-dynamic-dns"
LOG_PATH="/var/log/google-dynamic-dns/log.txt"

function main() {
	loadLastRun
	if [ $? = 1 ]; then
		exit 1
	fi

	checkForFailure
	if [ $? = 1 ]; then
		exit 1
	fi

	IP_RESPONSE=$(curl -s https://domains.google.com/checkip)
	interpretIPResponse "$IP_RESPONSE"
	if [ $? = 1 ]; then
		exit 1
	fi

	# Check to see if IP address has changed since last run, if it has then update it
	if [ "$CURRENT_IP" != "$LAST_IP" ]; then
		# Make the update GET request
		UPDATE_RESPONSE=$(curl -s https://${USERNAME}:${PASSWORD}@domains.google.com/nic/update?hostname=${HOSTNAME})
		interpretUpdateResponse "$UPDATE_RESPONSE"
	fi
	if [ $? = 1 ]; then
		exit 1
	fi
	exit 0
}

# Check to see if last run was successful. If not, exit immediately.
# Google will block Dynamic DNS access for "failure to interpret previous responses correctly" so it's best to be on the safe side.
function checkForFailure() {
	if [ "$LAST_RUN" != 0 ]; then
		echo "`date`: Last run failed. Check the log, correct the issue, change last run status to 0, and then run again." >> "${LOG_PATH}"
		return 1
	fi
}

# Load data from last run
function loadLastRun() {
	# Load and validate IP address as of last run
	LAST_IP=$(<${DATA_PATH}/ip)
	validateIP ${LAST_IP}
	if [ $? = 1 ]; then
		echo "`date`: The IP address from the last run either does not exist or is invalid. Correct and then re-run the script." >> "${LOG_PATH}"
		return 1
	fi

	# Load and validate the stored exit code from last run
	LAST_RUN=$(<${DATA_PATH}/success)
	if [ "${LAST_RUN}" != "0" ] && [ "${LAST_RUN}" != "1" ]; then
		echo "`date`: The success/fail status from the last run either does not exist or is invalid. Correct and then re-run the script." >> "${LOG_PATH}"
		return 1
	fi
}

# Takes an ipv4 address as an argument and returns a 0 if it's a valid IP and a 1 if it's not
function validateIP() {
	local  ip=$1
	local  stat=1

	if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		OIFS=$IFS
		IFS='.'
		ip=($ip)
		IFS=$OIFS
		[[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
		&& ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
		stat=$?
	fi
	return $stat
}

# Query to Google Domains checkip service to get public IP and then validate the response
function interpretIPResponse() {
	validateIP $1
	if [ $? = 1 ]; then
		echo "`date`: The response from the Google domains checkip service returned: ${RESPONSE}" >> "${LOG_PATH}"
		return 1
	fi
	CURRENT_IP=$1
}

# Interpret the response to the request and log the results
function interpretUpdateResponse() {
	case $1 in
		"good ${CURRENT_IP}" | "nochg ${CURRENT_IP}")
			echo $CURRENT_IP > "${DATA_PATH}/ip"
			echo "`date`: ${HOSTNAME} successfully updated to ${CURRENT_IP}." >> "${LOG_PATH}"
			echo "0" > "${DATA_PATH}/success"
			return 0
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
			echo "`date`: A custom A or AAAA resource record conflicts with the update. Delete the indicated resource record within DNS settings page and try the update again." >> "${LOG_PATH}"
			;;
		*)
			echo "`date`: ${1}" >> "${LOG_PATH}"
	esac
	echo 1 > "${DATA_PATH}/success"
	return 1
}

# Check to see if --test argument was supplied. If it was, do nothing to allow functions to be loaded. Otherwise run main()
if [ "${1}" !=  "--test" ]; then
	main
fi
