# check_aruba_cx6100.py
# Brad Riley
# Check status of interfaces, PSUs, and fans on Aruba CX switch
# 8/18/2022
# Usage: check_aruba_cx6100.py -H 192.168.1.1 -v v10.09 -u admin -p test123 interface -n 1/1/1 -s
# Run check_aruba_cx6100.py -h for help

import requests
import argparse
import urllib.parse
import warnings
import sys


def main():

    def genArgs():
        '''Generates all of the command line switches'''
        parser = argparse.ArgumentParser()
        parser = argparse.ArgumentParser(description='Obtain interface information and status from Aruba CX switches')
        parser = argparse.ArgumentParser(epilog='Troubleshooting: 400 error - Bad syntax | 401 - Wrong creds / Unauthorized')
        parser.add_argument('-H', '--host', action='store', type=str, required=True, help='Define hostname or IP of Aruba switch - Example: switch.company.com or 192.168.1.2')
        parser.add_argument('-v', '--version', action='store', type=str, required=True, help='API version to access on the Aruba switch - Example: v10.09 or v10.04')
        parser.add_argument('-u', '--username', action='store', type=str, required=True, help='Define username to login to Aruba switch')
        parser.add_argument('-p', '--password', action='store', type=str, required=True, help='Define password to login to Aruba switch')

        subparsers = parser.add_subparsers(dest='endpoint',help='Define RESTful endpoint to query a system part or interface')
        parser_a = subparsers.add_parser('interface')
        parser_a.add_argument('-n', '--name', type=str, required=True, help='Interface name')
        parser_a.add_argument('-d', '--down', action='store_true', help='Define whether the interface is expected to be up or down')
        parser_a.add_argument('-s', '--statistics', action='store_true', help='Append interface utilization percentage as performance data')

        parser_b = subparsers.add_parser('system')
        parser_b.add_argument('-p', '--part', choices=['psu', 'fan'])
        args = parser.parse_args()
        return args


    def login(url, username, password):
        '''Begin session and login to the Aruba REST API of the switch'''
        s = requests.Session()
        data = {'username' : username, 'password' : password}
        endpoint = f'{url}/login'
        r = s.post(endpoint, data=data, verify=False)
        r.raise_for_status()
        return s

    def logout(s, url):
        '''Logout of the Aruba REST API of the switch and close session'''
        endpoint = f'{url}/logout'
        r = s.post(endpoint, verify=False)
        r.raise_for_status()
        s.close()


    def getInterface(s, url, interface):
        '''Send POST to obtain description, link state, and rate statistics on the specified interface'''
        interface = urllib.parse.quote_plus(interface)
        params = {'attributes' : 'name,description,link_state,rate_statistics'}
        endpoint = f'{url}/system/interfaces/{interface}'
        r = s.get(endpoint, params=params, verify=False)
        r.raise_for_status()
        return r.json()


    def format_stats(response):
        '''Format the JSON output of the rate_statistics request'''
        rounded = dict()
        for eachKey in response['rate_statistics']:
            rounded[eachKey] = round(response['rate_statistics'][eachKey], 2)

        perf = ''
        for eachKey in rounded:
            perf += f'{eachKey} - {rounded[eachKey]}\n'
        return perf


    def getPart(s, base, part):
        '''Query the requested system part for its status'''

        def getPart(s, part):
            if part == 'psu':
                endpoint = base + '/rest/v10.09/system/subsystems/chassis,1/power_supplies'
            elif part == 'fan':
                endpoint = base + '/rest/v10.09/system/subsystems/chassis,1/fans'
            else:
                raise ValueError('Unknown part')

            r = s.get(endpoint, verify=False)
            r.raise_for_status()

            partList = r.json()
            partStats = list()

            for eachPart in partList:
                endpoint = base + partList[eachPart]
                r = s.get(endpoint, verify=False)
                r.raise_for_status()
                r = r.json()
                if part == 'psu':
                    partOutput = {'name' : eachPart, 'description' : r['identity']['description'], 'status' : r['status']}
                if part == 'fan':
                    partOutput = {'name' : eachPart, 'status' : r['status']}
                partStats.append(partOutput)
            return partStats

        output = getPart(s, part)
        return output


    def getExitPart(response, part):
        '''Return exit code for state of part query'''
        # Check all PSUs if the status value is not 'ok'
        # Report critical exit code if PSU does not have status of 'ok'
        if not any(d['status'] == 'ok' for d in response):
            if part == 'psu':
                string = 'PSU not OK | '
                code = 2
            else:
                string = 'Fan not OK | '
                code = 2
        else:
            if part == 'psu':
                string = 'All PSUs OK | '
                code = 0
            else:
                string = 'All fans OK | '
                code = 0
        
        # Add performance information to string for each power supply
        perf = ''
        for eachPart in response:
            if part == 'psu':
                perf += f'{eachPart["name"]} - {eachPart["description"]} - {eachPart["status"]}\n'
            else:
                perf += f'{eachPart["name"]} - {eachPart["status"]}\n'
        status = string + perf

        # Print the status string for Nagios to report on the check
        print(status)
        return code


    def getExitInt(response, statistics, perf):
        '''Return exit code for the current state of the interface'''

        # Build the output string that contains performance data and print it for Nagios check output
        # Exit the program with the exit code according to the interface status for Nagios state check

        if response['link_state'] == 'up':
            if down:
                status = f'CRITICAL - Interface should not be up - {response["description"]}'
                if statistics:
                    status += f' | {perf}'
                code = 2
            else:
                status = f'OK - Interface is up - {response["description"]}'
                if statistics:
                    status += f' | {perf}'
                code = 0

        elif response['link_state'] == 'down':
            if down:
                status = f'OK - Interface is down - {response["description"]}'
                if statistics:
                    status += f' | {perf}'
                code = 0
            else:
                status = f'CRITICAL - Interface should not be down - {response["description"]}'
                if statistics:
                    status += f' | {perf}'
                code = 2
        
        else:
            status = f'UNKNOWN - Interface is in an unknown state - {response["description"]}'
            if statistics:
                status += f' | {perf}'
            code = 3
        
        print(status)
        return code


    args = genArgs()
    base = f'https://{args.host}' # URL without version
    url = f'{base}/rest/{args.version}' # Build the main URL to send REST API commands
    username = args.username
    password = args.password
    endpoint = args.endpoint

    session = login(url, username, password)

    if endpoint == 'interface':
        interface = args.name
        down = args.down
        statistics = args.statistics
        response = getInterface(session, url, interface)
        perf = format_stats(response)
        code = getExitInt(response, statistics, perf)
    else:
        part = args.part
        response = getPart(session, base, part)
        code = getExitPart(response, part)
    
    # Aruba can only have 6 concurrent API sessions. Logout MUST be done.
    logout(session, url)
    # Exit the program with the exit code to report the status to Nagios (OK, Critical, Warning, etc.)
    sys.exit(code)
    


if __name__ == "__main__":
    
    # Aruba REST API only works with self-signed certificates, and the API server cannot change certificates.
    # Bypasses the warning that is printed on every request to the self-signed certificate
    warnings.filterwarnings("ignore")
    
    main()
