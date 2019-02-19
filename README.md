# check_es_system
Monitoring plugin to check disk or memory usage on an ElasticSearch node, whether on-prem or running in the Cloud.

Please refer to http://www.claudiokuenzler.com/nagios-plugins/check_es_system.php for full documentation.

Requirements
------
The following commands must be available: `curl`, `jshon`, `expr`

Usage
------

    ./check_es_system.sh -H ESNode [-P port] [-S] [-u user] [-p pass] -d diskspace -t check [-o unit] [-w warn] [-c crit] [-m max_time]
    
    
Example
-------

    ./check_es_system.sh -H MyESCluster.found.no -u search -p find -d 50 -t disk
    ES SYSTEM OK - Disk usage is at 25% (12 G)|es_store=13461027761B;42949672960;51002736640;;
