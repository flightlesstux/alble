#!/bin/bash

# mkdir -p /etc/letsencrypt/renewal-hooks/deploy/
# mv renew-on-alb.sh /etc/letsencrypt/renewal-hooks/deploy/
# chmod +x /etc/letsencrypt/renewal-hooks/deploy/renew-on-alb.sh

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

for domain in $RENEWED_DOMAINS
do
	DOMAIN_UPDATE_SCRIPT="/opt/alble/renewal/$domain.sh"
	if [[ -x "$DOMAIN_UPDATE_SCRIPT" ]]
	then
		$DOMAIN_UPDATE_SCRIPT
	else
	    alert "ERROR" ":octagonal_sign: Renew Failed!" "Script '$DOMAIN_UPDATE_SCRIPT' is not executable or found for $domain to renew a Let's Encrypt SSL on $ALB_ARN"
	fi
done
