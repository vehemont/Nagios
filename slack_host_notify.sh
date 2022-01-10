#!/bin/bash
#!/usr/bin/env bash

#===============================================================================
#
#          FILE:  slack_host_notify.sh
#
#         USAGE:  ./slack_host_notify.sh "$NOTIFICATIONTYPE$"  "$HOSTNAME$" "$HOSTADDRESS$" "$HOSTSTATE$" "$LONGHOSTOUTPUT$" "$LONGDATETIME$" "$HOSTINFOURL$"
#
#   DESCRIPTION: Pushes Nagios notifications through Slack webhook
#
#  REQUIREMENTS:  Slack webhook URL, Nagios notification command.
#        AUTHOR:  Brad Riley, brad@bradsvpn.com
#       VERSION:  1.0
#       CREATED:  06/23/2021
#===============================================================================



# Edit your Slack hook URL and footer icon URL
SLACK_URL=https://hooks.slack.com/services/


# Host Notification command example :

# define command {
#                command_name                          slack-host
#                command_line                          /usr/local/nagios/libexec/slack_host_notify.sh "$NOTIFICATIONTYPE$"  "$HOSTNAME$" "$HOSTADDRESS$" "$HOSTSTATE$" "$LONGHOSTOUTPUT$" "$LONGDATETIME$" "$HOSTINFOURL$"
# }
#
#
# $1 = "$NOTIFICATIONTYPE$"
# $2 = "$HOSTNAME$"
# $3 = "$HOSTADDRESS$"
# $4 = "$HOSTSTATE$"
# $5 = "$LONGHOSTOUTPUT$"
# $6 = "$LONGDATETIME$"
# $7 = "$HOSTACKCOMMENT$" OR "$HOSTINFOURL$"
# $8 = "$HOSTACKAUTHOR$"
# $9 = "$HOSTINFOURL$"

case $4 in

"DOWN")
  MSG_COLOR="#ff0000"
  ;;
"UP")
  MSG_COLOR="#00ff00"
  ;;
"UNREACHABLE")
  MSG_COLOR="#ff6200"
  ;;
"UNKNOWN")
  MSG_COLOR="#ff6200"
  ;;
"OK")
  MSG_COLOR="#00ff00"
  ;;
*)
  MSG_COLOR="#dea035"
  ;;
esac

IFS='%'


if [[ "$1" == *"ACKNOWLEDGEMENT"* ]]; then
  SLACK_MSG='{"attachments":[{"color":"'"$MSG_COLOR"'","blocks":[{"type":"header","text":{"type":"plain_text","text":":rotating_light: Host '"$1"'","emoji":true}},{"type":"section","fields":[{"type":"plain_text","text":"Host:","emoji":true},{"type":"plain_text","text":"'"$2"'","emoji":true},{"type":"plain_text","text":"IP Address:","emoji":true},{"type":"plain_text","text":"'"$3"'","emoji":true},{"type":"plain_text","text":"State:","emoji":true},{"type":"plain_text","text":"'"$4"'","emoji":true},{"type":"plain_text","text":"Additional Output:","emoji":true},{"type":"plain_text","text":"'"$5"'","emoji":true}]},{"type":"section","fields":[{"type":"plain_text","text":"Comment:","emoji":true},{"type":"plain_text","text":"'"$7"'","emoji":true},{"type":"plain_text","text":"Author:","emoji":true},{"type":"plain_text","text":"'"$8"'","emoji":true},{"type":"mrkdwn","text":"<'"$9"'|Link to host>"}]}]}]}'
else
  SLACK_MSG='{"attachments":[{"color":"'"$MSG_COLOR"'","blocks":[{"type":"header","text":{"type":"plain_text","text":":rotating_light: Host '"$1"'","emoji":true}},{"type":"section","fields":[{"type":"plain_text","text":"Host:","emoji":true},{"type":"plain_text","text":"'"$2"'","emoji":true},{"type":"plain_text","text":"IP Address:","emoji":true},{"type":"plain_text","text":"'"$3"'","emoji":true},{"type":"plain_text","text":"State:","emoji":true},{"type":"plain_text","text":"'"$4"'","emoji":true},{"type":"plain_text","text":"Additional Output:","emoji":true},{"type":"plain_text","text":"'"$5"'","emoji":true}]},{"type":"section","fields":[{"type":"mrkdwn","text":"<'"$9"'|Link to host>"}]}]}]}'
fi


#Send message to Slack
curl -X POST -H 'Content-type: application/json' --data "$SLACK_MSG" $SLACK_URL

unset IFS