#!/bin/bash

#==============================================================================
# check_ubiquiti_switch.sh
#==============================================================================
## SYNOPSIS
#@  ./check_ubiquiti_switch.sh [-d DEBUG] [-h IP] [-c COMMUNITY] [-v VERSION] [-i INT] [-down]
##
## DESCRIPTION
##   Monitor the status of an interface on a Ubiquiti EX switch using a read
##   ^ only SNMP community
#-----------------------------------------------------------------------------
## PARAMETERS
##
##
##    --help      Print this help
##    --version   Print script version and information
##    -d          Print debug information
##    -h          IP address of the Ubiquiti switch
##    -c          SNMP v1/v2 community string
##    -v          SNMP version [1 or 2c]
##    -i          Interface name
##    -down       Declares interface should be down, report critical if not
##
##  Note: Parameters are positional sensitive
##
## EXAMPLE
##    ./check_ubiquiti_switch.sh -h 192.168.1.5 -c public -v 1 -i 0/14
##    ./check_ubiquiti_switch.sh -h 10.1.20.9 -c nagios -v 2c -i 0/48 -down
##
#==============================================================================
#% INFORMATION
#%      VERSION              check_ubiquiti_switch.sh 1.0.0
#%      AUTHOR               Vehemont (brad@bradsvpn.com)
#%      TESTED ENVIRONMENTS  UniFi Switch 48 POE-750W - 4.0.66.10832
#%
#==============================================================================
# HISTORY
#       2020-01-31 : Brad : Creation of script
#		    2020-02-07 : Brad : Added port description to -down port														 
#
#
#==============================================================================
# ACTIONS
#       Nagios plugin to monitor the status of an interface on a Ubiquiti switch
#
#==============================================================================
# END OF LINE
#==============================================================================

# OIDs
getifs='1.3.6.1.2.1.31.1.1.1.1'
ifstatus='1.3.6.1.2.1.2.2.1.8.'
lastChange='1.3.6.1.2.1.2.2.1.9.'
ifDescrOID='1.3.6.1.2.1.2.2.1.2.'
ifAlias='1.3.6.1.2.1.31.1.1.1.18.'
debug=false

# Display masthead info
mastheadinfo() {
  InfoLvl="^#%"
  [[ "${1}" = "brief" ]] && InfoLvl="^#@"
  [[ "${1}" = "help" ]] && InfoLvl="^#[@#]"
  [[ "${1}" = "version" ]] && InfoLvl="^#%"
  head -$(grep -sn "^# END OF LINE" ${0} | head -1 | cut -f1 -d:) ${0} | grep -e "${InfoLvl}" | sed -e "s/${InfoLvl}//g" -e "s/\${self_name}/${self_name}/g"
}

# Invalid / Unrecognized parameter
invalidparameter() {
  printf '%s\n\t\t%s\n\n' "${1} Parameter not recognized." "Try '--help' for script parameters"
  printf '%s' "Usage: "
  mastheadinfo brief
  exit 3
}

main() {
  # Main dictionary where '<interface> : <snmp_index>' is kept.
  declare -A if_dict

  # Pull the snmp interface indexes through snmpwalk
  snmpif=$(/usr/bin/snmpwalk -v $version -c $community $host $getifs)
  if [ -z "$snmpif" ]; then # If snmp query times out
    echo "Warning - SNMP Query timeout!"
    exit 3
  fi
  # Read each line of the snmpwalk output and put it in an array
  ADDR=()
  while read -r line; do
    ADDR+=( "$line" )
  done < <( printf '%s' "$snmpif" )

  # Iterate through each line of the output
  for i in "${ADDR[@]}"; do
    IFS='='
    SPLIT=()
    read -ra SPLIT <<< "$i" # Split SNMP poll on '=' : [iso.3.6.1.2.1.31.1.1.1.1.503 ] [ STRING: "ge-0/0/0.0"]

    # Find interface from snmp poll
    INT_Array=()
    IFS=' '
    read -ra INT_Array <<< "${SPLIT[1]}" # Splits SPLIT[1] into : [STRING:] ["ge-0/0/0.0"]
    walkinterface="${INT_Array[1]}"  # ["ge-0/0/0.0"]
    walkinterface="${walkinterface#\"}"  # ["ge-0/0/0.0]
    walkinterface="${walkinterface%\"}"  # [ge-0/0/0.0]

    # Find snmp index from poll
    IFS='.'
    OID=()
    read -ra OID <<< "$SPLIT[0]" # Splits SPLIT[0] into : [iso][3][6][1][2][1][31][1][1][1][1][503 ]
    snmpIndex="${OID[-1]}" # Take only the last index : [503 ]
    snmpIndex=$(echo $snmpIndex | cut -d ' ' -f1) # Cut out the space : [503]

    # Add <interface> : <snmp_index> to the dictionary
    if_dict[$walkinterface]="$snmpIndex"
  done

  # Print the interfaces along with their snmp index for debug purposes
  if [[ "$debug" == true ]]; then
    for each_interface in "${!if_dict[@]}"; do
      printf "Interface: $each_interface\n"
      printf "SNMP Index: ${if_dict[$each_interface]}\n\n"
    done
  fi

  # See if users interface exists in poll
  if [[ -v "if_dict[$interface]" ]]; then
    ifStat=$(/usr/bin/snmpwalk -v "$version" -c "$community" "$host" "$ifstatus${if_dict[$interface]}") # If it does exist, poll it for its status.
    if [[ debug == true ]]; then # Print the snmp result of the interface if debug is on.
      echo "$ifStat"
    fi
  else
    printf "\nCouldn't find interface $interface \nUse -d to list the names of the interfaces the script finds.\n"
    exit 3
  fi

  # Cut $ifStat down to just a number.								  
  ifStat="$(cut -d '=' -f2 <<< "$ifStat")"
  ifStat=$(echo "$ifStat" | tr -dc '0-7')
  # Make sure its a number less than or equal to 7 in accordance to ifOperStatus (1.3.6.1.2.1.2.2.1.8.)																									   
  if (( "$ifStat" <= 7 )); then
    if [[ "$ifStat" == '1' ]]; then
      if [[ $downInt == True ]]; then
       # If the interface is supposed to be down (from the -down flag) and is up, exit 2 and throw an alert.																											 
        printf "CRITICAL - Port $interface is UP - This port should be down!\n"
        exit 2
      else
        # If the interface is up and is supposed to be up, exit 0 so everything is fine.																						
        ifLastChange=$(/usr/bin/snmpwalk -v "$version" -c "$community" "$host" "$lastChange${if_dict[$interface]}")
        ifLastChange=${ifLastChange#*(}
        portDescrip=$(/usr/bin/snmpget -Oqv -v "$version" -c "$community" "$host" "$ifAlias${if_dict[$interface]}")
        printf "OK - Port $interface is UP - $portDescrip\n($ifLastChange\n"
        exit 0
      fi
    elif [[ "$ifStat" == '2' ]]; then
      if [[ $downInt == True ]]; then
		# If the interface is supposed to be down (from the -down flag) and is down, exit 0 so everything is fine.																										  
        printf "OK - Port $interface is DOWN\n"
        exit 0
      else
		# If the interface is supposed to be up and is down, exit 2 and throw an alert.																			   
        portDescrip=$(/usr/bin/snmpget -Oqv -v "$version" -c "$community" "$host" "$ifAlias${if_dict[$interface]}")
        printf "CRITICAL - Port $interface is DOWN - $portDescrip\n\n"
        exit 2
      fi
    elif [[ "$ifStat" == '3' ]]; then
      # If you intend to have an interface in the testing state change the exit code to 0 for OK or 2 for critical																												  
      echo "WARNING - $interface is in a TESTING state"
      exit 1
    elif [[ "$ifStat" == '4' ]]; then
      # If your interface is broken on a hardware level, it might come up as unknown.																					 
      echo "UNKNOWN - $interface is in an UNKNOWN state"
      exit 3
    elif [[ "$ifStat" == '5' ]]; then
      echo "WARNING - $interface is in a DORMANT state and waiting for external actions"
      exit 1
    elif [[ "$ifStat" == '6' ]]; then
      # If an module SFP/port is removed, then it will state it is not present.																			   
      echo "CRITICAL - $interface is NOT PRESENT"
      exit 2
    elif [[ "$ifStat" == '7' ]]; then
      # If the box can detect something is wrong, it will state lower-layer down state.																					   
      echo "CRITICAL - $interface is in a LOWER-LAYER DOWN state"
      exit 2
    fi
  else
    # If we didn't get a ifOperStatus output, freak out and tell someone.																		 
    echo "CRITICAL - Could not recognize output from interface poll!"
    echo "$ifStat"
    exit 2
  fi
  exit 1
}

# Positional not-so-magic parameters.  									   
while [[ $# -gt 0 ]]; do
  case "${1}" in
   --help)
    mastheadinfo help
    exit 0;;
   --version|-v)
    mastheadinfo version
    exit 0;;
   -d)
     debug=true
     if [[ ${2} == '-h' ]]; then
       host=${3}
       echo 'IP Address: '${host}
      if [[ ${4} == '-c' ]]; then
        community=${5}
        echo 'Community: '${community}
        if [[ ${6} == '-v' && (${7} == '1' || ${7} == '2c') ]]; then
          version=${7}
          echo 'Version: '$version
        else
          invalidparameter
        fi
        if [[ ${8} == '-i' ]]; then
          interface=${9}
          printf 'Interface: '${9}'\n\n'
        else
          invalidparameter
        fi
        if [[ ${10} == '-down' ]]; then
          downInt=True
          echo $downInt
        else
          downInt=false
          echo $downInt
        fi
      fi
     else
        invalidparameter
     fi
     main;;
   -h)
     host=${2}
     if [[ ${3} == '-c' ]]; then
       community=${4}
       if [[ ${5} == '-v' && (${6} == '1' || ${6} == '2c') ]]; then
         version=${6}
       else
         invalidparameter
       fi
       if [[ ${7} == '-i' ]]; then
         interface=${8}
       else
         invalidparameter
       fi
       if [[ ${9} == '-down' ]]; then
         downInt=True
       else
         downInt=false
       fi
     else
        invalidparameter
     fi
     main;;
   *)
       invalidparameter
       exit 3;;
   esac
done
