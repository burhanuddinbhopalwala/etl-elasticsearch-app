#!/bin/sh
echo "RESTARTING ETL..."
ps -aux | grep [.]rb | awk '{print $2}' | xargs -rn 1 kill -9
./track_process.pl

