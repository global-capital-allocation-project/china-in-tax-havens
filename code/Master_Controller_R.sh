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
# RUN R CODE
##############################################

umask 007
Rscript "${ccdms1_code}/${1}.R" ${SLURM_ARRAY_TASK_ID}
rm -f Master_Build.log

# print code file that was run and confirm script reached this point
echo "${ccdms1_code}/${1}.R"
rm "${ccdms1_code}/${1}.log"
echo "Finished Step "${1}
exit
