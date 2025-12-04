#!/bin/sh
#
# ubxpurge   Purge ubxdata archive and logfiles
#
# (c) 2024 Hans van der Marel, TUD.

#-------------------------------------------------------------------------
# All user defined and OS related settings are in ubxlogger.config

ubxscriptdir=$(dirname "$(readlink -f "$0")")
. ${ubxscriptdir}/ubxlogger.config

#-------------------------------------------------------------------------

# Settings

max_disk_usage=95
min_days_to_keep=30
min_days_to_delete=3
max_days_to_delete=7
max_logfile_size=512k

# Check the command line arguments

while getopts "h" options; do
  case "${options}" in
    h|?)
      echo "Purge ubx and log files."
      echo "Syntax:"
      echo "   ubxpurge -h"
      echo "   ubxpurge"
      exit
      ;;
    *)
      echo "Error: unknown option ${option}, quiting."
      exit
      ;;
  esac
done
shift $((OPTIND-1))

logfile=${logdir}/ubxpurge.log

# Determine how much diskspace is used

diskusage=$(df ${archivedir} | tail -1 | xargs | cut -d " " -f 5)
diskusage=${diskusage%\%}

# Check the disk usage and if necessary delete the oldest data

if [ ${diskusage} -ge ${max_disk_usage} ]; then
   echo "Current disk usage of ${archivedir} (${diskusage}%) is above maximum of ${max_disk_usage}%, need to purge data."
   echo $(date -u +"%F %R") "Current disk usage of ${archivedir} (${diskusage}%) is above maximum of ${max_disk_usage}%, need to purge data." >> ${logfile}
   candidates=$(find ${archivedir}/*/  -maxdepth 1 -mindepth 1 -mtime +${min_days_to_keep} | sort)
   #echo $candidates
   daycount=0
   for d in ${candidates}; do
      echo "Purge ubx data files $d/*_MO.??x.gz"
      echo $(date -u +"%F %R") "Purge ubx data files $d/*_MO.??x.gz" >> ${logfile}
      rm $d/*_MO.??x.gz
      rmdir $d
      daycount=$((daycount+1))
      # delete a maximum number of days at a time ...
      if [ $daycount -ge ${max_days_to_delete} ]; then
         break
      fi
      # stop when disk size is below the limit after deleting minimum number of days
      diskusage=$(df ${archivedir} | tail -1 | xargs | cut -d " " -f 5)
      diskusage=${diskusage%\%}
      if [ $daycount -ge ${min_days_to_delete} ] && [ ${diskusage} -lt ${max_disk_usage} ]; then
         break
      fi
   done
   echo "Disk usage of ${archivedir} is reduced to ${diskusage}% after deleting ${daycount} days of data."
   echo $(date -u +"%F %R") "Disk usage of ${archivedir} is reduced to ${diskusage}% after deleting ${daycount} days of data." >> ${logfile}
else
   echo "No need to purge data on ${archivedir}, current disk usage of ${diskusage}% is below maximum of ${max_disk_usage}%."
fi

# Check the log file size and start a new one if the size exceeds the limit

for f in $(find ${logdir}/*.log -size +${max_logfile_size}); do
   logarchive=${f%.log}_$(date +%Y%m%d).log
   echo "Archive logfile $f to ${logarchive}.gz"
   echo $(date -u +"%F %R") "Archive logfile $f to ${logarchive}.gz" >> ${logfile}
   mv $f $logarchive
   gzip $logarchive
done

exit
