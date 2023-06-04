#!/bin/bash

##############################################
# SETUP
##############################################

# output arguments
echo "STEP="${1}

# output slurm environment variables
echo "SLURM_JOB_ID="$SLURM_JOB_ID
echo "SLURM_JOB_NODELIST"=$SLURM_JOB_NODELIST
echo "SLURM_NNODES"=$SLURM_NNODES
echo "SLURM_SUBMIT_DIR="$SLURM_SUBMIT_DIR
echo "SLURM_ARRAY_TASK_ID="$SLURM_ARRAY_TASK_ID
echo "SLURM_ARRAY_JOB_ID"=$SLURM_ARRAY_JOB_ID
echo "SLURM_ARRAY_TASK_ID"=$SLURM_ARRAY_TASK_ID
echo "SLURM_SUBMIT_DIR="$SLURM_SUBMIT_DIR

##############################################
# RUN STATA CODE
##############################################

umask 007
stata-mp -b "${ccdms1_code}/${1}.do" ${SLURM_ARRAY_TASK_ID}
rm -f Master_Build.log

# check stata log for errors
echo "Checking Stata log for errors..."
if [ -z ${SLURM_ARRAY_TASK_ID+x} ]
then 
    if egrep --before-context=2 --max-count=1 "^r\([0-9]+\);$" "${logs_path}/${1}.log"
    then
        exit 1
    fi
else 
    if egrep --before-context=2 --max-count=1 "^r\([0-9]+\);$" "${logs_path}/${1}_${SLURM_ARRAY_TASK_ID}.log"
    then
        exit 1
    fi
fi
echo "No errors found."

# print code file that was run and confirm script reached this point
echo "${ccdms1_code}/${1}.do"
rm "${ccdms1_code}/${1}.log"
echo "Finished Step "${1}
exit
