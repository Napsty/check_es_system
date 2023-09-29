#!/bin/bash
echo "Test Elasticsearch status"
./check_es_system.sh -H 127.0.0.1 -P 9200 -t disk
output=$(./check_es_system.sh -H 127.0.0.1 -P 9200 -t disk)

if [[ $? -eq 0 ]]; then
  echo -e "\e[1m\e[32m✔ Test 3.1 OK: Disk check worked and shows green\e[0m"
  exitcode=0
else
  echo -e "\e[1m\e[31m✘ Test 3.1 ERROR: Disk check has not worked\e[0m"
  exitcode=1
fi

if ! [[ "${output}" =~ "ES SYSTEM OK - Disk usage is at 0%" ]]; then
  exitcode=1
fi

exit $exitcode
