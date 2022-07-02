#!/bin/bash

# Author: Ercan Ermis - 28/06/2022 - Izmir/Turkey
# Pre Requisites: certbot, python2-certbot-nginx, jq, dig, aws-cli (min v1.18.147), nginx.
# For example: "$ sudo yum -y install nginx certbot python2-certbot-nginx jq dig"
# Recommended: You should install the script via Gitlab under /opt/ or any kind of path.
# Otherwise, you should set a directory on check_certificates.sh and update-alb.sh source line.

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

DOMAIN=$1
CNAME_CHECK=$(dig +short CNAME $1)

if [ "$CNAME_CHECK" = "${ALB_DNS_NAME,,}." ]; then
    echo "CNAME verification Success"
else
    alert "ERROR" ":octagonal_sign: CNAME Check Failed!" "DNS Record doesn't exist for $DOMAIN to issue a Let's Encrypt SSL for ${ALB_DNS_NAME,,}"
	exit
fi

EXIST="/etc/letsencrypt/live/$DOMAIN/"
if [ -d "$EXIST" ]; then
    echo "Looks like, the $DOMAIN path is already exist. Please check $EXIST"
    while true; do
    read -p "Do you want to reinstall the Let's Encrypt SSL for $DOMAIN? (Yy/Nn)" yn
    case $yn in
        [Yy]* ) echo "Continuing..."; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer Yy or Nn.";;
    esac
done
else
    echo "$EXIST path is available"
fi

certbot certonly --webroot -w $ALBLE_PATH/certbot-challange --agree-tos -m $EMAIL --non-interactive -d $DOMAIN

if [ $? -eq 0 ]; then
	CERT_ARN=`aws acm import-certificate --region $AWS_REGION --certificate fileb:///etc/letsencrypt/live/$DOMAIN/cert.pem --certificate-chain fileb:///etc/letsencrypt/live/$DOMAIN/fullchain.pem --private-key fileb:///etc/letsencrypt/live/$DOMAIN/privkey.pem | jq -r .CertificateArn` #--profile $AWS_PROFILE
	aws elbv2 add-listener-certificates --region $AWS_REGION --listener-arn $ALB_LISTENER_ARN --certificates CertificateArn=$CERT_ARN #--profile $AWS_PROFILE
	echo "Let's Encrypt Successfully issued for $DOMAIN"
else
	echo "ERROR Certbot Failed!"
    exit
fi

CHECK_DOMAINLIST=$(grep "$DOMAIN" $ALBLE_PATH/domainlist)

if [[ "$DOMAIN" == "$CHECK_DOMAINLIST" ]]; then
  echo "$DOMAIN already found in domainlist, skiping..."
else
	echo "$DOMAIN" > $ALBLE_PATH/domainlist
fi

ALB_MAX_LE='23'
TOTAL_DOMAIN_COUNT=$(wc -l domainlist | awk '{ print $1 }')
if ! [[ "$TOTAL_DOMAIN_COUNT" -gt "$ALB_MAX_LE" ]] ; then
   echo "You have still SSL limit on ALB."
else
   alert "WARN" ":octagonal_sign: ALB SSL Max Count Reached!" "On $ALB_ARN reached maximum SSL Limit. Please take an action."
   exit
fi


CHECK_RENEWAL="$ALBLE_PATH/renewal/$DOMAIN.sh"
if [ -d "$CHECK_RENEWAL" ]; then
    echo "Looks like, the $DOMAIN renewal already setup. If you need, please check $CHECK_RENEWAL"
    echo "Exiting..."
    exit
else
echo "#!/bin/bash" > $ALBLE_PATH/renewal/$DOMAIN.sh
echo "set -e" >> $ALBLE_PATH/renewal/$DOMAIN.sh
cat >> $ALBLE_PATH/renewal/$DOMAIN.sh <<'EOF'

source ../env

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

DOMAIN="$DOMAIN"
CERT_ARN="aws acm list-certificates --region $AWS_REGION --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn" --output text > /dev/null" #--profile $AWS_PROFILE

aws acm import-certificate --region $AWS_REGION --certificate-arn $CERT_ARN --certificate fileb:///etc/letsencrypt/live/$DOMAIN/cert.pem --certificate-chain fileb:///etc/letsencrypt/live/$DOMAIN/fullchain.pem --private-key fileb:///etc/letsencrypt/live/$DOMAIN/privkey.pem > /dev/null #  --profile $AWS_PROFILE
aws elbv2 add-listener-certificates --region $AWS_REGION --listener-arn $ALB_LISTENER_ARN --certificates CertificateArn=$CERT_ARN > /dev/null

alert "Good job! :muscle: $DOMAIN is successfully renews on $ALB_ARN."
EOF
chmod +x $ALBLE_PATH/renewal/$DOMAIN.sh
fi
exit
