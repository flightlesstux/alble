## Which problem I solved?
**-** This codes are requesting a Let's Encrypt SSL Certificate from ACME and issuing and deploying the issued SSL certificate to the AWS Application Lod Balancer. You can check out the story and installation steps on **https://ercanermis.com/automate-lets-encrypt-ssl-on-aws-application-load-balancer**

## Prerequisites
**-** aws-cli
**-** epel Repository
**-** jq
**-** dig
**-** nginx
**-** crond
**-** certbot
**-** python2-certbot-nginx
**-** IAM Role Policy
**-** IAM Role or AWS Cli User

## Installation
On the CentOS based server, just go to /opt/ path with `cd /opt/` command and run the `git clone https://github.com/flightlesstux/alble.git` Otherwise, something will goes wrong.

## Disclaimer
I'm not taking any responsibilites to use, just be careful when you are playing in the production area : )

## Contributions
Just and a PR. All PR's and contributions are welcome!
