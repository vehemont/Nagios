# Nagios

## Check scripts

`check_ubiquiti_switch.sh` - Pulls SNMP to monitor a specific port. Allows monitoring of an initial state of up or down, so you can monitor if a switchport comes up. As well if a switch port happens to go down. Tested on UniFi Switch 48 POE-750W - 4.0.66.10832. Only supports SNMP version 1 and 2. 

EXAMPLE:
    

    `./check_ubiquiti_switch.sh -h 10.1.20.9 -c nagios -v 2c -i 0/48 -down`
    OK - Port 0/48 is DOWN
    
    `./check_ubiquiti_switch.sh -h 192.168.1.5 -c public -v 1 -i 0/14`
    OK - Port 0/14 is UP - 14 <Port Description>
    (2815900) 7:49:19.00
  
  

`check_aruba_cx6100.py` - Pulls interface, PSU, and fan status using the Aruba REST API on the switch.

EXAMPLE:


    check_aruba_cx6100.py -H 192.168.1.1 -v v10.09 -u admin -p test123 interface -n 1/1/1 -s
    check_aruba_cx6100.py -H switch.company.com -v10.04 -u admin -p test123 system fan
    check_aruba_cx6100.py -H switch.company.com -v10.04 -u admin -p test123 system psu
    usage: check_aruba_cx6100.py [-h] -H HOST -v VERSION -u USERNAME -p PASSWORD {interface,system} ...

    positional arguments:
      {interface,system}    Define RESTful endpoint to query a system part or interface

    options:
      -h, --help            show this help message and exit
      -H HOST, --host HOST  Define hostname or IP of Aruba switch - Example: switch.company.com or 192.168.1.2
      -v VERSION, --version VERSION
                            API version to access on the Aruba switch - Example: v10.09 or v10.04
      -u USERNAME, --username USERNAME
                            Define username to login to Aruba switch
      -p PASSWORD, --password PASSWORD
                            Define password to login to Aruba switch

    Troubleshooting: 400 error - Bad syntax | 401 - Wrong creds / Unauthorized

## Slack notifications

`slack_host_notify.sh` - Sends an embeded message to a Slack channel for Nagios host alerts. Works with acknowledgement alerts to provide the user who acknowledged the alert and the reason. Embed color changes based on alert status: recovery (green), problem(orange), critical (red).  

`slack_service_notify.sh` - This is the same as the host notify but just for services within Nagios.  

![service_problem](/images/slack_service_problem.png)
![acknowledgement](/images/slack_acknowledgement.png)  

### Setup:

1. [Create a Slack webhook](https://api.slack.com/messaging/webhooks) in a channel you want the alerts to go to. You will get a URL with your new webhook.
2. Copy the two shell scripts (`slack_service_notify.sh` and `slack_host_notify.sh`) onto your Nagios instance. In this example I put them in `/nagios/libexec/`.
3. Make the two shell scripts executable with `chmod +x slack_service_notify.sh` and `chmod +x slack_host_notify.sh`
4. Open each file in your preferred text editor and edit the `SLACK_URL` variable to your Slack webhook URL you received in step 1.
5. Make two new Nagios commands in a .cfg file. I used `/nagios/etc/objects/commands.cfg`. Make sure you update the `command_line` with the correct location of the script if you did not place the script in `/usr/local/nagios/libexec/`.
```
define command {
      command_name notify-service-by-slack
      command_line /usr/local/nagios/libexec/slack_service_notify.sh "$NOTIFICATIONTYPE$" "$HOSTNAME$" $HOSTADDRESS$ "$SERVICEDESC$" "$SERVICESTATE$" "$SERVICEOUTPUT$" "$LONGDATETIME$" "$SERVICEACKCOMMENT$" "$SERVICEACKAUTHOR$" "$SERVICEINFOURL$"
}
define command {
      command_name notify-host-by-slack
      command_line /usr/local/nagios/libexec/slack_host_notify.sh "$NOTIFICATIONTYPE$" "$HOSTNAME$" $HOSTADDRESS$ "$HOSTSTATE$" "$HOSTOUTPUT$" "$LONGDATETIME$" "$HOSTACKCOMMENT$" "$HOSTACKAUTHOR$" "$HOSTINFOURL$"
}
```
6. Create a new contact object to use the new Slack notification commands. I use `/nagios/etc/objects/contacts.cfg`.
```
define contact {
      contact_name                             slack
      alias                                    Slack
      service_notification_period              24x7
      host_notification_period                 24x7
      service_notification_options             w,u,c,r
      host_notification_options                d,u,r
      service_notification_commands            notify-service-by-slack
      host_notification_commands               notify-host-by-slack
}
```
7. Add the new contact to your contact groups or directly to host or service objects within Nagios.
8. Restart the Nagios process.  
`systemctl restart nagios`

