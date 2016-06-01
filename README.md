# check_es_store
Monitoring plugin to check disk (store) usage of an ElasticSearch node

Requirements
------
The following commands must be available: curl, jshon, expr

Usage
------

    ./check_es_store.sh -H ESNode [-p port] [-S] [-u user] [-p pass] -d diskspace [-o unit] [-w warn] [-c crit]
    
    
Example
-------

    ./check_es_store.sh -H MyESCluster.found.no -u search -p find -d 50 
