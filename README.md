# Nagios

`check_ubiquiti_switch.sh` - Pulls SNMP to monitor a specific port. Allows monitoring of an initial state of up or down, so you can monitor if a switchport comes up. As well if a switch port happens to go down. Tested on UniFi Switch 48 POE-750W - 4.0.66.10832. Only supports SNMP version 1 and 2. This is meant to be ran as a Nagios plugin.

EXAMPLE:
    

    ./check_ubiquiti_switch.sh -h 10.1.20.9 -c nagios -v 2c -i 0/48 -down
    ./check_ubiquiti_switch.sh -h 192.168.1.5 -c public -v 1 -i 0/14


`slack_host_notify.sh` - Sends an embeded message to a Slack channel for Nagios host alerts. Works with acknowledgement alerts to provide the user who acknowledged the alert and the reason.  
`slack_service_notify.sh` - This is the same as the host notify but just for services within Nagios.
