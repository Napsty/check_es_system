#!/bin/bash
echo "Test Elasticsearch status"
./check_es_system.sh -H 127.0.0.1 -P 9200 -t status

if [[ $? -eq 0 ]]; then
  echo -e "\e[1m\e[32m✔ Test 1.1 OK: Status check worked and shows green\e[0m"
  exit 0
else
  echo -e "\e[1m\e[31m✘ Test 1.1 ERROR: Status check has not worked\e[0m"
  exit 1
fi

# Create index with a replica, this should result in unassigned shards and yellow status
curl -X PUT "127.0.0.1:9200/my-index-001" -H 'Content-Type: application/json' -d'{ "settings": { "index": { "number_of_shards": 2, "number_of_replicas": 1 } } }'
sleep 5

./check_es_system.sh -H 127.0.0.1 -P 9200 -t status
if [[ $? -eq 1 ]]; then
  echo -e "\e[1m\e[32m✔ Test 1.2 OK: Status check worked and shows yellow\e[0m"
  exit 0
else
  echo -e "\e[1m\e[31m✘ Test 1.2 ERROR: Status check has not worked as expected\e[0m"
  exit 1
fi
