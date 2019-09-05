#!/bin/bash
################################################################################
# Script:       check_es_system.sh                                             #
# Author:       Claudio Kuenzler www.claudiokuenzler.com                       #
# Purpose:      Monitor ElasticSearch Store (Disk) Usage                       #
# Official doc: https://www.claudiokuenzler.com/monitoring-plugins/            #
# License:      GPLv2                                                          #
# GNU General Public Licence (GPL) http://www.gnu.org/                         #
# This program is free software; you can redistribute it and/or                #
# modify it under the terms of the GNU General Public License                  #
# as published by the Free Software Foundation; either version 2               #
# of the License, or (at your option) any later version.                       #
#                                                                              #
# This program is distributed in the hope that it will be useful,              #
# but WITHOUT ANY WARRANTY; without even the implied warranty of               #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                #
#                                                                              #
# GNU General Public License for more details.                                 #
#                                                                              #
# You should have received a copy of the GNU General Public License            #
# along with this program; if not, see <https://www.gnu.org/licenses/>.        #
#                                                                              #
# Copyright 2016,2018,2019 Claudio Kuenzler                                    #
# Copyright 2018 Tomas Barton                                                  #
#                                                                              #
# History:                                                                     #
# 20160429: Started programming plugin                                         #
# 20160601: Continued programming. Working now as it should =)                 #
# 20160906: Added memory usage check, check types option (-t)                  #
# 20160906: Renamed plugin from check_es_store to check_es_system              #
# 20160907: Change internal referenced variable name for available size        #
# 20160907: Output now contains both used and available sizes                  #
# 20161017: Add missing -t in usage output                                     #
# 20180105: Fix if statement for authentication (@deric)                       #
# 20180105: Fix authentication when wrong credentials were used                #
# 20180313: Configure max_time for Elastic to respond (@deric)                 #
# 20190219: Fix alternative subject name in ssl (issue 4), direct to auth      #
# 20190220: Added status check type                                            #
# 20190403: Check for mandatory parameter checktype, adjust help               #
# 20190403: Catch connection refused error                                     #
# 20190426: Catch unauthorized (403) error                                     #
# 20190626: Added readonly check type                                          #
# 20190905: Catch empty cluster health status (issue #13)                      #
################################################################################
#Variables and defaults
STATE_OK=0              # define the exit code if status is OK
STATE_WARNING=1         # define the exit code if status is Warning
STATE_CRITICAL=2        # define the exit code if status is Critical
STATE_UNKNOWN=3         # define the exit code if status is Unknown
export PATH=$PATH:/usr/local/bin:/usr/bin:/bin # Set path
version=1.5.1
port=9200
httpscheme=http
unit=G
indexes='_all'
warning=80
critical=95
max_time=30
################################################################################
#Functions
help () {
echo -e "$0 $version (c) 2016-$(date +%Y) Claudio Kuenzler and contributors

Usage: ./check_es_system.sh -H ESNode [-P port] [-S] [-u user] [-p pass] -t checktype [-d int] [-o unit] [-w int] [-c int] [-m int]

Options:

   *  -H Hostname or ip address of ElasticSearch Node
      -P Port (defaults to 9200)
      -S Use https
      -u Username if authentication is required
      -p Password if authentication is required
   *  -t Type of check (disk|mem|status|readonly)
   +  -d Available size of disk or memory (ex. 20)
      -o Disk space unit (K|M|G) (defaults to G)
      -i Space separated list of indexes to be checked for readonly (default: '_all')
      -w Warning threshold in percent (default: 80)
      -c Critical threshold in percent (default: 95)
      -m Maximum time in seconds to wait for response (default: 30)
      -h Help!

*mandatory options
+mandatory option for types disk,mem

Requirements: curl, jshon, expr"
exit $STATE_UNKNOWN;
}

authlogic () {
if [[ -z $user ]] && [[ -z $pass ]]; then echo "ES SYSTEM UNKNOWN - Authentication required but missing username and password"; exit $STATE_UNKNOWN
elif [[ -n $user ]] && [[ -z $pass ]]; then echo "ES SYSTEM UNKNOWN - Authentication required but missing password"; exit $STATE_UNKNOWN
elif [[ -n $pass ]] && [[ -z $user ]]; then echo "ES SYSTEM UNKNOWN - Missing username"; exit $STATE_UNKNOWN
fi
}

unitcalc() {
# ES presents the currently used disk space in Bytes
if [[ -n $unit ]]; then
  case $unit in
    K) availsize=$(expr $available \* 1024); outputsize=$(expr ${size} / 1024);;
    M) availsize=$(expr $available \* 1024 \* 1024); outputsize=$(expr ${size} / 1024 / 1024);;
    G) availsize=$(expr $available \* 1024 \* 1024 \* 1024); outputsize=$(expr ${size} / 1024 / 1024 / 1024);;
  esac
  if [[ -n $warning ]] ; then
    warningsize=$(expr $warning \* ${availsize} / 100)
  fi
  if [[ -n $critical ]] ; then
    criticalsize=$(expr $critical \* ${availsize} / 100)
  fi
  usedpercent=$(expr $size \* 100 / $availsize)
else echo "UNKNOWN - Shouldnt exit here. No units given"; exit $STATE_UNKNOWN
fi
}

availrequired() {
if [ -z ${available} ]; then echo "UNKNOWN - Missing parameter '-d'"; exit $STATE_UNKNOWN; fi
}
################################################################################
# Check requirements
for cmd in curl jshon expr; do
 if ! `which ${cmd} 1>/dev/null`; then
   echo "UNKNOWN: ${cmd} does not exist, please check if command exists and PATH is correct"
   exit ${STATE_UNKNOWN}
 fi
done
################################################################################
# Check for people who need help - aren't we all nice ;-)
if [ "${1}" = "--help" -o "${#}" = "0" ]; then help; exit $STATE_UNKNOWN; fi
################################################################################
# Get user-given variables
while getopts "H:P:Su:p:d:o:i:w:c:t:m:" Input;
do
  case ${Input} in
  H)      host=${OPTARG};;
  P)      port=${OPTARG};;
  S)      httpscheme=https;;
  u)      user=${OPTARG};;
  p)      pass=${OPTARG};;
  d)      available=${OPTARG};;
  o)      unit=${OPTARG};;
  i)      indexes=${OPTARG};;
  w)      warning=${OPTARG};;
  c)      critical=${OPTARG};;
  t)      checktype=${OPTARG};;
  m)      max_time=${OPTARG};;
  *)      help;;
  esac
done

# Check for mandatory opts
if [ -z ${host} ]; then help; exit $STATE_UNKNOWN; fi
if [ -z ${checktype} ]; then help; exit $STATE_UNKNOWN; fi
################################################################################
# Retrieve information from Elasticsearch
getstatus() {
esurl="${httpscheme}://${host}:${port}/_cluster/stats"
eshealthurl="${httpscheme}://${host}:${port}/_cluster/health"
if [[ -z $user ]]; then 
  # Without authentication
  esstatus=$(curl -k -s --max-time ${max_time} $esurl)
  esstatusrc=$?
  if [[ $esstatusrc -eq 7 ]]; then
    echo "ES SYSTEM CRITICAL - Failed to connect to ${host} port ${port}: Connection refused"
    exit $STATE_CRITICAL
  elif [[ $esstatusrc -eq 28 ]]; then
    echo "ES SYSTEM CRITICAL - server did not respond within ${max_time} seconds"
    exit $STATE_CRITICAL
  fi
  # Additionally get cluster health infos
  if [ $checktype = status ]; then
    eshealth=$(curl -k -s --max-time ${max_time} $eshealthurl)
    if [[ -z $eshealth ]]; then
      echo "ES SYSTEM CRITICAL - unable to get cluster health information"
      exit $STATE_CRITICAL
    fi
  fi
fi

if [[ -n $user ]] || [[ -n $(echo $esstatus | grep -i authentication) ]] ; then
  # Authentication required
  authlogic
  esstatus=$(curl -k -s --max-time ${max_time} --basic -u ${user}:${pass} $esurl)
  esstatusrc=$?
  if [[ $esstatusrc -eq 7 ]]; then
    echo "ES SYSTEM CRITICAL - Failed to connect to ${host} port ${port}: Connection refused"
    exit $STATE_CRITICAL
  elif [[ $esstatusrc -eq 28 ]]; then
    echo "ES SYSTEM CRITICAL - server did not respond within ${max_time} seconds"
    exit $STATE_CRITICAL
  elif [[ -n $(echo $esstatus | grep -i "unable to authenticate") ]]; then
    echo "ES SYSTEM CRITICAL - Unable to authenticate user $user for REST request"
    exit $STATE_CRITICAL
  elif [[ -n $(echo $esstatus | grep -i "unauthorized") ]]; then
    echo "ES SYSTEM CRITICAL - User $user is unauthorized"
    exit $STATE_CRITICAL
  fi
  # Additionally get cluster health infos
  if [[ $checktype = status ]]; then
    eshealth=$(curl -k -s --max-time ${max_time} --basic -u ${user}:${pass} $eshealthurl)
    if [[ -z $eshealth ]]; then
      echo "ES SYSTEM CRITICAL - unable to get cluster health information"
      exit $STATE_CRITICAL
    fi
  fi
fi

# Catch empty reply from server (typically happens when ssl port used with http connection)
if [[ -z $esstatus ]] || [[ $esstatus = '' ]]; then
  echo "ES SYSTEM UNKNOWN - Empty reply from server (verify ssl settings)"
  exit $STATE_UNKNOWN
fi
}
################################################################################
# Do the checks
case $checktype in
disk) # Check disk usage
  availrequired
  getstatus
  size=$(echo $esstatus | jshon -e indices -e store -e "size_in_bytes")
  unitcalc
  if [ -n "${warning}" ] || [ -n "${critical}" ]; then
    # Handle tresholds
    if [ $size -ge $criticalsize ]; then
      echo "ES SYSTEM CRITICAL - Disk usage is at ${usedpercent}% ($outputsize $unit from $available $unit)|es_disk=${size}B;${warningsize};${criticalsize};;"
      exit $STATE_CRITICAL
    elif [ $size -ge $warningsize ]; then
      echo "ES SYSTEM WARNING - Disk usage is at ${usedpercent}% ($outputsize $unit from $available $unit)|es_disk=${size}B;${warningsize};${criticalsize};;"
      exit $STATE_WARNING
    else
      echo "ES SYSTEM OK - Disk usage is at ${usedpercent}% ($outputsize $unit from $available $unit)|es_disk=${size}B;${warningsize};${criticalsize};;"
      exit $STATE_OK
    fi
  else
    # No thresholds
    echo "ES SYSTEM OK - Disk usage is at ${usedpercent}% ($outputsize $unit from $available $unit)|es_disk=${size}B;;;;"
    exit $STATE_OK
  fi
  ;;

mem) # Check memory usage
  availrequired
  getstatus
  size=$(echo $esstatus | jshon -e nodes -e jvm -e mem -e "heap_used_in_bytes")
  unitcalc
  if [ -n "${warning}" ] || [ -n "${critical}" ]; then
    # Handle tresholds
    if [ $size -ge $criticalsize ]; then
      echo "ES SYSTEM CRITICAL - Memory usage is at ${usedpercent}% ($outputsize $unit) from $available $unit|es_memory=${size}B;${warningsize};${criticalsize};;"
      exit $STATE_CRITICAL
    elif [ $size -ge $warningsize ]; then
      echo "ES SYSTEM WARNING - Memory usage is at ${usedpercent}% ($outputsize $unit from $available $unit)|es_memory=${size}B;${warningsize};${criticalsize};;"
      exit $STATE_WARNING
    else
      echo "ES SYSTEM OK - Memory usage is at ${usedpercent}% ($outputsize $unit from $available $unit)|es_memory=${size}B;${warningsize};${criticalsize};;"
      exit $STATE_OK
    fi
  else
    # No thresholds
    echo "ES SYSTEM OK - Memory usage is at ${usedpercent}% ($outputsize $unit from $available $unit)|es_memory=${size}B;;;;"
    exit $STATE_OK
  fi
  ;;

status) # Check Elasticsearch status
  getstatus
  status=$(echo $esstatus | jshon -e status -u)
  shards=$(echo $esstatus | jshon -e indices -e shards -e total -u)
  docs=$(echo $esstatus | jshon -e indices -e docs -e count -u)
  nodest=$(echo $esstatus | jshon -e nodes -e count -e total -u)
  nodesd=$(echo $esstatus | jshon -e nodes -e count -e data -u)
  relocating=$(echo $eshealth | jshon -e relocating_shards -u)
  init=$(echo $eshealth | jshon -e initializing_shards -u)
  unass=$(echo $eshealth | jshon -e unassigned_shards -u)
  if [ "$status" = "green" ]; then 
    echo "ES SYSTEM OK - Elasticsearch Cluster is green (${nodest} nodes, ${nodesd} data nodes, ${shards} shards, ${docs} docs)|total_nodes=${nodest};;;; data_nodes=${nodesd};;;; total_shards=${shards};;;; relocating_shards=${relocating};;;; initializing_shards=${init};;;; unassigned_shards=${unass};;;; docs=${docs};;;;"
    exit $STATE_OK
  elif [ "$status" = "yellow" ]; then
    echo "ES SYSTEM WARNING - Elasticsearch Cluster is yellow (${nodest} nodes, ${nodesd} data nodes, ${shards} shards, ${relocating} relocating shards, ${init} initializing shards, ${unass} unassigned shards, ${docs} docs)|total_nodes=${nodest};;;; data_nodes=${nodesd};;;; total_shards=${shards};;;; relocating_shards=${relocating};;;; initializing_shards=${init};;;; unassigned_shards=${unass};;;; docs=${docs};;;;"
      exit $STATE_WARNING
  elif [ "$status" = "red" ]; then
    echo "ES SYSTEM CRITICAL - Elasticsearch Cluster is red (${nodest} nodes, ${nodesd} data nodes, ${shards} shards, ${relocating} relocating shards, ${init} initializing shards, ${unass} unassigned shards, ${docs} docs)|total_nodes=${nodest};;;; data_nodes=${nodesd};;;; total_shards=${shards};;;; relocating_shards=${relocating};;;; initializing_shards=${init};;;; unassigned_shards=${unass};;;; docs=${docs};;;;"
      exit $STATE_CRITICAL
  fi  
  ;;

readonly) # Check Readonly status on given indexes
  icount=0
  for index in $indexes; do 
    if [[ -z $user ]]; then
      # Without authentication
      settings=$(curl -k -s --max-time ${max_time} ${httpscheme}://${host}:${port}/$index/_settings)
      if [[ $? -eq 7 ]]; then
        echo "ES SYSTEM CRITICAL - Failed to connect to ${host} port ${port}: Connection refused"
        exit $STATE_CRITICAL
      elif [[ $? -eq 28 ]]; then
        echo "ES SYSTEM CRITICAL - server did not respond within ${max_time} seconds"
        exit $STATE_CRITICAL
      fi
      rocount=$(echo $settings | jshon -a -e settings -e index -e blocks -e read_only_allow_delete -u -Q | grep -c true)
      if [[ $rocount -gt 0 ]]; then
        output[${icount}]="Elasticsearch Index $index is read-only (found $rocount index(es) set to read-only)"
        roerror=true
      fi
    fi

    if [[ -n $user ]] || [[ -n $(echo $esstatus | grep -i authentication) ]] ; then
      # Authentication required
      authlogic
      settings=$(curl -k -s --max-time ${max_time} --basic -u ${user}:${pass} ${httpscheme}://${host}:${port}/$index/_settings)
      if [[ $? -eq 7 ]]; then
        echo "ES SYSTEM CRITICAL - Failed to connect to ${host} port ${port}: Connection refused"
        exit $STATE_CRITICAL
      elif [[ $? -eq 28 ]]; then
        echo "ES SYSTEM CRITICAL - server did not respond within ${max_time} seconds"
        exit $STATE_CRITICAL
      elif [[ -n $(echo $esstatus | grep -i "unable to authenticate") ]]; then
        echo "ES SYSTEM CRITICAL - Unable to authenticate user $user for REST request"
        exit $STATE_CRITICAL
      elif [[ -n $(echo $esstatus | grep -i "unauthorized") ]]; then
        echo "ES SYSTEM CRITICAL - User $user is unauthorized"
        exit $STATE_CRITICAL
      fi
      rocount=$(echo $settings | jshon -a -e settings -e index -e blocks -e read_only_allow_delete -u -Q | grep -c true)
      if [[ $rocount -gt 0 ]]; then
        output[${icount}]="Elasticsearch Index $index is read-only (found $rocount index(es) set to read-only)"
        roerror=true
      fi
    fi
    let icount++
  done

  if [[ $roerror ]]; then 
    echo "ES SYSTEM CRITICAL - ${output[*]}"
    exit $STATE_CRITICAL
  else 
    echo "ES SYSTEM OK - Elasticsearch Indexes ($indexes) are writeable"
    exit $STATE_OK
  fi
  ;;

*) help
esac
