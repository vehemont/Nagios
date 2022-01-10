#!/usr/bin/env bash

#===============================================================================
#
#          FILE:  slac_service_notify.sh
#
#         USAGE:  ./slack_service_notify.sh "$NOTIFICATIONTYPE$"  "$HOSTNAME$" "$HOSTADDRESS$" "$HOSTSTATE$" "$LONGHOSTOUTPUT$" "$LONGDATETIME$" "$HOSTINFOURL$"
#
#   DESCRIPTION: Pushes Nagios service notifications through Slack webhook
#
#  REQUIREMENTS:  Slack webhook URL, Nagios notification command.
#        AUTHOR:  Brad Riley, brad@bradsvpn.com
#       VERSION:  1.0
#       CREATED:  06/23/2021
#===============================================================================



# Edit your Slack hook URL
SLACK_URL=https://hooks.slack.com/services/

# Host Notification command example :

# define command {
#                command_name                          slack-service
#                command_line                          /usr/local/nagios/libexec/slack_service_notify.sh "$NOTIFICATIONTYPE$"  "$HOSTNAME$" "$HOSTADDRESS$" "$HOSTSTATE$" "$LONGSERVICEOUTPUT$" "$LONGDATETIME$" "$SERVICEACKCOMMENT$" "$SERVICEACKAUTHOR$" "$SERVICEINFOURL$"
# }
#
#
# $1 = "$NOTIFICATIONTYPE$"
# $2 = "$HOSTNAME$"
# $3 = "$HOSTADDRESS$"
# $4 = "$SERVICEDESC$"
# $5 = "$SERVICESTATE$"
# $6 = "$SERVICEOUTPUT$"
# $7 = "$LONGDATETIME$"
# $8 = "$SERVICEACKCOMMENT$"
# $9 = "$SERVICEACKAUTHOR$"
# $10 = "$SERVICEINFOURL$"

case $5 in

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
"PROBLEM")
  MSG_COLOR="#ff0000"
  ;;
"CRITICAL")
  MSG_COLOR="#ff0000"
  ;;
"OK")
  MSG_COLOR="#00ff00"
  ;;
*)
  MSG_COLOR="#dea035"
  ;;
esac

IFS='%'

# Include author and comment if it is a acknowledgement
if [[ "$1" == *"ACKNOWLEDGEMENT"* ]]; then
  SLACK_MSG='{"attachments":[{"color":"'"$MSG_COLOR"'","blocks":[{"type":"header","text":{"type":"plain_text","text":":rotating_light: Service '"$1"'","emoji":true}},{"type":"section","fields":[{"type":"plain_text","text":"Host:","emoji":true},{"type":"plain_text","text":"'"$2"'","emoji":true},{"type":"plain_text","text":"IP Address:","emoji":true},{"type":"plain_text","text":"'"$3"'","emoji":true},{"type":"plain_text","text":"Service:","emoji":true},{"type":"plain_text","text":"'"$4"'","emoji":true},{"type":"plain_text","text":"State:","emoji":true},{"type":"plain_text","text":"'"$5"'","emoji":true},{"type":"plain_text","text":"Additional Output:","emoji":true},{"type":"plain_text","text":"'"$6"'","emoji":true}]},{"type":"section","fields":[{"type":"plain_text","text":"Comment:","emoji":true},{"type":"plain_text","text":"'"$8"'","emoji":true},{"type":"plain_text","text":"Author:","emoji":true},{"type":"plain_text","text":"'"$9"'","emoji":true}]},{"type":"section","fields":[{"type":"mrkdwn","text":"<'"${10}" |Link to service>"}]}]}]}'
else
  SLACK_MSG='{"attachments":[{"color":"'"$MSG_COLOR"'","blocks":[{"type":"header","text":{"type":"plain_text","text":":rotating_light: Service '"$1"'","emoji":true}},{"type":"section","fields":[{"type":"plain_text","text":"Host:","emoji":true},{"type":"plain_text","text":"'"$2"'","emoji":true},{"type":"plain_text","text":"IP Address:","emoji":true},{"type":"plain_text","text":"'"$3"'","emoji":true},{"type":"plain_text","text":"Service:","emoji":true},{"type":"plain_text","text":"'"$4"'","emoji":true},{"type":"plain_text","text":"State:","emoji":true},{"type":"plain_text","text":"'"$5"'","emoji":true},{"type":"plain_text","text":"Additional Output:","emoji":true},{"type":"plain_text","text":"'"$6"'","emoji":true}]},{"type":"section","fields":[{"type":"mrkdwn","text":"<'"${10}"'|Link to service>"}]}]}]}'
fi

# Send message to Slack
curl -X POST -H 'Content-type: application/json' --data "$SLACK_MSG" $SLACK_URL


unset IFS