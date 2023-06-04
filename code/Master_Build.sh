#!/bin/bash
echo "Begin CCDMS Run ..."


##############################################
# SETUP
##############################################

nodes=1
mailtype="BEGIN,FAIL,END"
username=$(whoami)

# Code path
export ccdms1_code="<CODE_PATH>"

# Data path
export data_path="<DATA_PATH>"

# Logs path
export logs_path="<LOGS_PATH>"

if [[ -z "$data_path" ]]; then
   echo "Empty data_path variable: Exiting..."
   exit
fi


##############################################
# SET PARAMETERS FOR EACH JOB
##############################################


# baseline
partition="<SLURM_PARTITION>"
time="0-02:00:00"
ntasks=1
mem="30G"

# Run MS Data
partition_ms_data="<SLURM_PARTITION>"
time_ms_data="0-02:00:00"
ntasks_ms_data=1
mem_ms_data="20G"
array_ms_data="1-7"

# Append MS Files
partition_append_ms_data="<SLURM_PARTITION>"
time_append_ms_data="0-02:00:00"
ntasks_append_ms_data=1
mem_append_ms_data="50G"


# Figures Aggregate by Currency
partition_fig_curr_data="<SLURM_PARTITION>"
time_fig_curr_data="0-02:00:00"
ntasks_fig_curr_data=1
mem_fig_curr_data="50G"

        
##############################################
# SUBMITS JOBS
##############################################
  
# Figure 1a and 1b
code_file=Issuance 
JOB_issuance_ID=`sbatch \
    --partition=${partition} --time=${time} \
    --mem=${mem} --nodes=${nodes} --ntasks=${ntasks} \
    --mail-user=${mailuser} --mail-type=${mailtype} --requeue \
    --output="${log_path}/${code_file}_%A_%a.out" --error="${log_path}/${code_file}_%A_%a.err" \
    --job-name=${code_file} \
    --array=${array} \
    "${ccdms1_code}/Master_Controller.sh" ${code_file} | awk '{print $NF}'`
echo "Submitted ${code_file} Job: "${JOB_issuance_ID}
sleep 1

# Figure 1c and 1d
code_file=Holdings 
JOB_holdings_ID=`sbatch \
    --partition=${partition} --time=${time} \
    --mem=${mem} --nodes=${nodes} --ntasks=${ntasks} \
    --mail-user=${mailuser} --mail-type=${mailtype} --requeue \
    --output="${log_path}/${code_file}_%A_%a.out" --error="${log_path}/${code_file}_%A_%a.err" \
    --job-name=${code_file} \
    --array=${array} \
    "${ccdms1_code}/Master_Controller.sh" ${code_file} | awk '{print $NF}'`
echo "Submitted ${code_file} Job: "${JOB_holdings_ID}
sleep 1

# Submit MS Holdings files:
code_file=MS_Data 
JOB_ms_data_ID=`sbatch \
    --partition=${partition_ms_data} --time=${time_ms_data} \
    --mem=${mem_ms_data} --nodes=${nodes} --ntasks=${ntasks_ms_data} \
    --mail-user=${mailuser} --mail-type=${mailtype} --requeue \
    --output="${log_path}/${code_file}_%A_%a.out" --error="${log_path}/${code_file}_%A_%a.err" \
    --job-name=${code_file} \
    --array=${array_ms_data} \
    "${ccdms1_code}/Master_Controller.sh" ${code_file} | awk '{print $NF}'`
echo "Submitted ${code_file} Job: "${JOB_ms_data_ID}
sleep 1

code_file=Append_MS_Data 
JOB_append_ms_data_ID=`sbatch \
    --partition=${partition_append_ms_data} --time=${time_append_ms_data} \
    --mem=${mem_append_ms_data} --nodes=${nodes} --ntasks=${ntasks_append_ms_data} \
    --mail-user=${mailuser} --mail-type=${mailtype} --requeue \
    --output="${log_path}/${code_file}_%A_%a.out" --error="${log_path}/${code_file}_%A_%a.err" \
    --job-name=${code_file} \
    --depend=afterok:${JOB_ms_data_ID} \
    "${ccdms1_code}/Master_Controller.sh" ${code_file} | awk '{print $NF}'` 
echo "Submitted ${code_file} Job: "${JOB_append_ms_data_ID}
sleep 1

# Figure 2
code_file=Currency
JOB_fig_curr_ID=`sbatch \
    --partition=${partition_fig_curr_data} --time=${time_fig_curr_data} \
    --mem=${mem_fig_curr_data} --nodes=${nodes} --ntasks=${ntasks_fig_curr_data} \
    --mail-user=${mailuser} --mail-type=${mailtype} --requeue \
    --output="${log_path}/${code_file}_%A_%a.out" --error="${log_path}/${code_file}_%A_%a.err" \
    --job-name=${code_file} \
    --depend=afterok:${JOB_append_ms_data_ID} \
    "${ccdms1_code}/Master_Controller.sh" ${code_file} | awk '{print $NF}'` 
echo "Submitted ${code_file} Job: "${JOB_fig_curr_ID}
sleep 1

# Data for Figure 3
code_file=Firm_Level
JOB_firm_level_ID=`sbatch \
    --partition=${partition} --time=${time} \
    --mem=${mem} --nodes=${nodes} --ntasks=${ntasks} \
    --mail-user=${mailuser} --mail-type=${mailtype} --requeue \
    --output="${log_path}/${code_file}_%A_%a.out" --error="${log_path}/${code_file}_%A_%a.err" \
    --job-name=${code_file} \
    "${ccdms1_code}/Master_Controller.sh" ${code_file} | awk '{print $NF}'`
echo "Submitted ${code_file} Job: "${JOB_firm_level_ID}
sleep 1

# Figure 3
code_file=Sankey_Plot
JOB_sankey_plot_ID=`sbatch \
    --partition=${partition} --time=${time} \
    --mem=${mem} --nodes=${nodes} --ntasks=${ntasks} \
    --mail-user=${mailuser} --mail-type=${mailtype} --requeue \
    --output="${log_path}/${code_file}_%A_%a.out" --error="${log_path}/${code_file}_%A_%a.err" \
    --job-name=${code_file} \
    "${ccdms1_code}/Master_Controller_R.sh" ${code_file} | awk '{print $NF}'`
echo "Submitted ${code_file} Job: "${JOB_sankey_plot_ID}
sleep 1

# FINISH
echo "Finished Submitting Build"
exit
