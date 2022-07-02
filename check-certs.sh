#!/bin/bash
# Run this script with cron on every day or night.

set -e

source /opt/alble/env

alert() {
  local color='good'
  if [ $1 == 'ERROR' ]; then
    color='danger'
  elif [ $1 == 'WARN' ]; then
    color = 'warning'
  fi
  local message="payload={\"channel\": \"$SLACK_CHANNEL\",\"attachments\":[{\"pretext\":\"$2\",\"text\":\"$3\",\"color\":\"$color\"}]}"

  curl -X POST --data-urlencode "$message" ${SLACK_WEBHOOK_URL}
}

DOMAIN="./domainlist"
while IFS= read -r DOMAIN
do

echo | timeout --preserve-status 4 openssl s_client -showcerts -servername $DOMAIN -connect $DOMAIN:443 2>/dev/null | openssl x509 -noout -checkend 864000

if [ $? -eq 0 ]; then
   httpStatusCode=`curl -m 4 -sL -w "%{http_code}" https://$DOMAIN -o /dev/null`
   if [ $httpStatusCode -ne 200 ]; then
      alert "ERROR" ":octagonal_sign: Let's Encrypt Check Failed!" "$DOMAIN URL https://$DOMAIN failed!"
   fi
else
      alert "WARN" ":warning: Let's Encrypt Expiration Warning" "$DOMAIN's Let's Encrypt SSL Certificate will be expired in 10 days!"
fi
done < "$DOMAIN"
