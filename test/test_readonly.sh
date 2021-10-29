#!/bin/bash
echo "Test Elasticsearch status"
./check_es_system.sh -H 127.0.0.1 -P 9200 -t readonly

if [[ $? -eq 0 ]]; then
  echo -e "\e[1m\e[32m✔ Test 2.1 OK: Readonly check worked and no read_only indexes were found\e[0m"
  exitcode=0
else
  echo -e "\e[1m\e[31m✘ Test 2.1 ERROR: Readonly check has not worked or read_only indexes were found\e[0m"
  exitcode=1
fi

# Create an index with read_only setting
curl -X PUT "127.0.0.1:9200/my-index-002" -H 'Content-Type: application/json' -d'{ "settings": { "index": { "blocks.read_only": true } } }'
sleep 5

./check_es_system.sh -H 127.0.0.1 -P 9200 -t readonly
if [[ $? -eq 2 ]]; then
  echo -e "\e[1m\e[32m✔ Test 2.1 OK: Readonly check worked and detected a read only index\e[0m"
  exitcode=0
else
  echo -e "\e[1m\e[31m✘ Test 2.1 ERROR: Readonly check has not worked as expected\e[0m"
  exitcode=1
fi


exit $exitcode
