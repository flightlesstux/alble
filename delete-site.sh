# Delete Everything from AWS
#!/bin/bash

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

if [ "$CNAME_CHECK" = "$ALB_DNS_NAME." ]; then
    echo "CNAME records is still pointing to $ALB_DNS_NAME. Are you sure to remove everything for $DOMAIN?"
    while true; do
    read -p "Do you want to reinstall the Let's Encrypt SSL for $DOMAIN? (Yy/Nn)" yn
    case $yn in
        [Yy]* ) echo "Continuing..."; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer Yy or Nn.";;
    esac
done
else
    CERT_ARN="aws acm list-certificates --region $AWS_REGION  --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn" --output text | tee" #--profile $AWS_PROFILE
    aws elbv2 remove-listener-certificates --region $AWS_REGION --listener-arn $ALB_LISTENER_ARN --certificates CertificateArn=$CERT_ARN #--profile $AWS_PROFILE
    aws acm delete-certificate --region $AWS_REGION --certificate-arn $CERT_ARN #--profile $AWS_PROFILE
    sed -i_bak -e '/aws.ercanermis.com/d' $ALBLE_PATH/domainlist
    alert "WARN" ":warning: Let's Encrypt SSL Deleted!" "Let's Encrypt SSL deleted for $DOMAIN on $ALB_ARN and ACM."
    exit
fi
