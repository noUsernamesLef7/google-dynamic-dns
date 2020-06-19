# google-dynamic-dns
A Bash script that keeps your Google Domains Dynamic DNS updated.

## Why
I have a domain registered with Google Domains and wanted to implement Dynamic DNS on one of my subdomains. The common method of using your router to keep it updated didn't work for me as my router only supports a two Dynamic DNS providers, neither of which is Google. I looked for an existing script but was unsatisfied with the ones I found so I decided to write my own.

## How It Works
Google provides an API that you can use to change your Dynamic DNS record to match your current public IP. Documentation for this API is [here](https://support.google.com/domains/answer/6147083?hl=en). This script automates that process, provides feedback useful in troubleshooting, and tries to prevent you from accidentally getting Dynamic DNS blocked on your domain by running too many requests. It's meant to be run on a frequent basis, using something like cron, or you could optionally run it when a change in your public IP address is detected.

The script tries to keep you from making bad requests. It checks the current public IP every time it's run and if it hasn't changed it exits. If and request returns an error or something unexpected, it will change the value stored in the "success" file from 0 to 1. Once that happens, it won't run again until you have manually corrected the problem and changed that value back to 0. Better safe than sorry in my view.

## Installation
* Clone the repository to your preferred installation location. I suggest /opt but /usr/local or somewhere else is fine.
    git clone git@github.com:noUsernamesLef7/google-dynamic-dns.git
* Edit the script and ensure that the **$DATA_PATH** variable matches the path to your install directory. While you have the file open, copy your hostname, username, and password from your Google Domains Dynamic DNS page. You can also edit the log file location if you wish.
* Make the script executable
```
chmod +x /opt/google-dynamic-dns/google-dynamic-dns.sh
```
* Create your log file directory and file
```
mkdir /var/log/google-dynamic-dns
touch /var/log/google-dynamic-dns/log.txt
```
* Add a crontab entry to run with a certain frequency
```
crontab -e
```
And add an entry like `*/5 * * * * /opt/google-dynamic-dns/google-dynamic-dns.sh`

That's it, now it will run every five minutes. [Here](https://crontab.guru) is a handy tool for creating cron schedule expressions if you want something different.
