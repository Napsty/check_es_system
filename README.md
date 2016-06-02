# check_es_store
Monitoring plugin to check disk (store) usage of an ElasticSearch node. 

Please refer to http://www.claudiokuenzler.com/nagios-plugins/check_es_store.php for full documentation.

Requirements
------
The following commands must be available: curl, jshon, expr

Usage
------

    ./check_es_store.sh -H ESNode [-p port] [-S] [-u user] [-p pass] -d diskspace [-o unit] [-w warn] [-c crit]
    
    
Example
-------

    ./check_es_store.sh -H MyESCluster.found.no -u search -p find -d 50 
    ES STORE OK - Disk usage is at 25% (12 G)|es_store=13461027761B;42949672960;51002736640;;
