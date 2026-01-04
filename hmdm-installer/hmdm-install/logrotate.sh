#!/bin/bash
#
# Weekly log rotation utility for Headwind MDM
#
BASE_DIR=/var/lib/tomcat9

find $BASE_DIR/work/logs -name "hmdm.log.*" -mtime +7 -exec rm {} \;
find $BASE_DIR/work/logs -name "audit.log.*" -mtime +7 -exec rm {} \;

# Uncomment if you need to rotate catalina.out as well
#rm $BASE_DIR/catalina.out.1
#mv $BASE_DIR/catalina.out $BASE_DIR/catalina.out.1
#service tomcat9 restart

