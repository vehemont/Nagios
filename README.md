# Nagios

## Check scripts

`check_ubiquiti_switch.sh` - Pulls SNMP to monitor a specific port. Allows monitoring of an initial state of up or down, so you can monitor if a switchport comes up. As well if a switch port happens to go down. Tested on UniFi Switch 48 POE-750W - 4.0.66.10832. Only supports SNMP version 1 and 2. This is meant to be ran as a Nagios plugin.

EXAMPLE:
    

    `./check_ubiquiti_switch.sh -h 10.1.20.9 -c nagios -v 2c -i 0/48 -down`
    `./check_ubiquiti_switch.sh -h 192.168.1.5 -c public -v 1 -i 0/14`

## Slack notifications

`slack_host_notify.sh` - Sends an embeded message to a Slack channel for Nagios host alerts. Works with acknowledgement alerts to provide the user who acknowledged the alert and the reason.  
`slack_service_notify.sh` - This is the same as the host notify but just for services within Nagios.

### Setup:

1. (Create a Slack webhook)[https://api.slack.com/messaging/webhooks] in a channel you want the alerts to go to. You will get a URL to copy.
2. Copy the two shell scripts into your script library. In this example I put them in `/nagios/libexec/`.
3. Make the two shell scripts executable with `chmod +x slack_service_notify.sh` and `chmod +x slack_host_notify.sh`
4. Open each file in your preferred text editor and edit the `SLACK_URL` variable to your Slack webhook URL.
5. Make a two new Nagios commands in a .cfg file. I used `/nagios/etc/objects/commands.cfg`.
```
define command {
      command_name notify-service-by-slack
      command_line /usr/local/nagios/libexec/slack_service_notify.sh "$NOTIFICATIONTYPE$" "$HOSTNAME$" $HOSTADDRESS$ "$SERVICEDESC$" "$SERVICESTATE$" "$SERVICEOUTPUT$" "$LONGDATETIME$" "$SERVICEACKCOMMENT$" "$SERVICEACKAUTHOR$" "$SERVICEINFOURL$"
}

define command {
      command_name notify-host-by-slack
      command_line /usr/local/nagios/libexec/slack_host_notify.sh "$NOTIFICATIONTYPE$" "$HOSTNAME$" $HOSTADDRESS$ "$HOSTSTATE$" "$HOSTOUTPUT$" "$LONGDATETIME$" "$HOSTACKCOMMENT$" "$HOSTACKAUTHOR$" "$HOSTINFOURL$"
}
}```

2. 
