#!/bin/bash
echo "Test Elasticsearch status"
./check_es_system.sh -H 127.0.0.1 -P 9200 -t readonly

if [[ $? -eq 0 ]]; then
  echo -e "\e[1m\e[32m✔ Test 2 OK: Readonly check worked and no read_only indexes were found\e[0m"
  exit 0
else
  echo -e "\e[1m\e[31m✘ Test 2 ERROR: Readonly check has not worked or read_only indexes were found\e[0m"
  exit 1
fi
