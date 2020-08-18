#!/bin/bash
source google-dynamic-dns.sh --test

# Create temporary test files to use for input/output
DATA_PATH=`mktemp -d`
LOG_PATH="${DATA_PATH}/log"

# 4 test cases
function testLoadLastRun() {
	# Test valid IP and a successful last run
	echo "127.0.0.1" > "${DATA_PATH}/ip"
	echo "0" > "${DATA_PATH}/success"
	loadLastRun
	if [ "$LAST_IP" = "127.0.0.1" ]; then
		echo "PASS - Load valid IP"
	else
		echo "FAIL - Load valid IP"
	fi
	if [ "$LAST_RUN" = "0" ]; then
		echo "PASS - Load valid last run"
	else
		echo "FAIL - Load valid last run"
	fi

	# Test invalid IP and successful last run
	echo "invalid" > "${DATA_PATH}/ip"
	loadLastRun
	LOG=$(<${LOG_PATH})
	if [[ "${LOG}" == *"The IP address"* ]]; then
		echo "PASS - Prevent invalid IP loading"
	else
		echo "FAIL - Prevent invalid IP loading"
	fi

	# Test invalid last run
	echo "127.0.0.1" > "${DATA_PATH}/ip"
	echo "invalid" > "${DATA_PATH}/success"
	loadLastRun
	LOG=$(<${LOG_PATH})
	if [[ "${LOG}" == *"The success/fail status"* ]]; then
		echo "PASS - Prevent invalid exit status loading"
	else
		echo "FAIL - Prevent invalid exit status loading"
	fi
}

# 2 test cases
function testCheckForFailure() {
	# Test a successful last run
	LAST_RUN=0
	checkForFailure
	if [ $? = 0 ]; then
		echo "PASS - Check for previous success"
	else
		echo "FAIL - Check for previous success"
	fi

	# Test a failed or invalid last run
	LAST_RUN="invalid"
	checkForFailure
	if [ $? = 1 ]; then
		echo "PASS - Check for previous failure or bad data"
	else
		echo "FAIL - Check for previous failure or bad data"
	fi
}

# 2 test cases
function testValidateIP() {
	# Test a valid IP
	validateIP "127.0.0.1"
	if [ $? = 0 ]; then
		echo "PASS - Check for a valid IP"
	else
		echo "FAIL - Check for a valid IP"
	fi

	# Test an invalid ip
	validateIP "invalid"
	if [ $? = 1 ]; then
		echo "PASS - Check for an invalid IP"
	else
		echo "FAIL - Check for an invalid IP"
	fi
}

# 3 test cases
function testInterpretIPResponse() {
	# Test if we get valid IP
	local RESPONSE="127.0.0.1"
	interpretIPResponse $RESPONSE
	if [ $? = 0 ]; then
		echo "PASS - Fetch a valid IP"
	else
		echo "FAIL - Fetch a valid IP"
	fi

	# Test if we get an invalid IP
	local RESPONSE="invalid"
	interpretIPResponse $RESPONSE
	if [ $? = 1 ]; then
		echo "PASS - Fetch an invalid IP"
	else
		echo "FAIL - Fetch an invalid IP"
	fi

	# Try actually getting an IP from google
	local RESPONSE=$(curl -s https://domains.google.com/checkip)
	interpretIPResponse $RESPONSE
	if [ $? = 0 ]; then
		echo "PASS - Fetch an IP from Google"
	else
		echo "FAIL - Fetch an IP from Google"
	fi
}

# 11 test cases
function testInterpretUpdateResponse() {
	# Test good response
	CURRENT_IP="127.0.0.1"
	local RESPONSE="good 127.0.0.1"
	interpretUpdateResponse "$RESPONSE"
	if [ $? = 0 ]; then
		echo "PASS - Test good update response"
	else
		echo "FAIL - Test good update response"
	fi

	# Test nochg response
	local RESPONSE="nochg 127.0.0.1"
	interpretUpdateResponse "$RESPONSE"
	if [ $? = 0 ]; then
		echo "PASS - Test nochg update response"
	else
		echo "FAIL - Test nochg update response"
	fi

	# Test nohost response
	local RESPONSE="nohost"
	interpretUpdateResponse "$RESPONSE"
	LOG=$(<${LOG_PATH})
	if [[ "${LOG}" == *"DNS enabled."* ]]; then
		echo "PASS - Test nohost update response"
	else
		echo "FAIL - Test nohost update response"
	fi

	# Test badauth response
	local RESPONSE="badauth"
	interpretUpdateResponse "$RESPONSE"
	LOG=$(<${LOG_PATH})
	if [[ "${LOG}" == *"username/password"* ]]; then
		echo "PASS - Test badauth update response"
	else
		echo "FAIL - Test badauth update response"
	fi

	# Test notfqdn response
	local RESPONSE="notfqdn"
	interpretUpdateResponse "$RESPONSE"
	LOG=$(<${LOG_PATH})
	if [[ "${LOG}" == *"supplied hostname"* ]]; then
		echo "PASS - Test notfqdn update response"
	else
		echo "FAIL - Test notfqdn update response"
	fi

	# Test badagent response
	local RESPONSE="badagent"
	interpretUpdateResponse "$RESPONSE"
	LOG=$(<${LOG_PATH})
	if [[ "${LOG}" == *"making bad requests"* ]]; then
		echo "PASS - Test badagent update response"
	else
		echo "FAIL - Test badagent update response"
	fi

	# Test abuse response
	local RESPONSE="abuse"
	interpretUpdateResponse "$RESPONSE"
	LOG=$(<${LOG_PATH})
	if [[ "${LOG}" == *"failure to interpret"* ]]; then
		echo "PASS - Test abuse update response"
	else
		echo "FAIL - Test abuse update response"
	fi

	# Test 911 response
	local RESPONSE="911"
	interpretUpdateResponse "$RESPONSE"
	LOG=$(<${LOG_PATH})
	if [[ "${LOG}" == *"Google's end."* ]]; then
		echo "PASS - Test 911 update response"
	else
		echo "FAIL - Test 911 update response"
	fi

	# Test conflict A response
	local RESPONSE="conflict A"
	interpretUpdateResponse "$RESPONSE"
	LOG=$(<${LOG_PATH})
	if [[ "${LOG}" == *"custom A or"* ]]; then
		echo "PASS - Test conflict A update response"
	else
		echo "FAIL - Test conflict A update response"
	fi

	# Test conflict AAAA response
	local RESPONSE="conflict AAAA"
	interpretUpdateResponse "$RESPONSE"
	LOG=$(<${LOG_PATH})
	if [[ "${LOG}" == *"custom A or"* ]]; then
		echo "PASS - Test conflict AAAA update response"
	else
		echo "FAIL - Test conflict AAAA update response"
	fi

	# Test unknown response
	local RESPONSE="unknownresponse"
	interpretUpdateResponse "$RESPONSE"
	LOG=$(<${LOG_PATH})
	if [[ "${LOG}" == *"unknownresponse"* ]]; then
		echo "PASS - Test unknown update response"
	else
		echo "FAIL - Test unknown update response"
	fi
}

testValidateIP
testLoadLastRun
testCheckForFailure
testInterpretIPResponse
testInterpretUpdateResponse
