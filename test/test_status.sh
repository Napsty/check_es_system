#!/bin/bash
echo "Test Elasticsearch status"
./check_es_system.sh -H 127.0.0.1 -P 9200 -t status

if [[ $? -eq 0 ]]; then
  echo -e "\e[1m\e[32m✔ Test 1 OK: Status check worked and shows green\e[0m"
  exit 0
else
  echo -e "\e[1m\e[31m✘ Test 1 ERROR: Status check has not worked\e[0m"
  exit 1
fi
