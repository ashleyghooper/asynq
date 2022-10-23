#!/usr/bin/env bash

# Run a command using the ts(1) task spooler for async operation,
# meaning the command can take as long as it needs, but this script
# return immediately, allowing the results to be picked up on the
# next run. Useful for status bars like i3status-rs, which otherwise
# may pause while the command runs.

# Usage: asynq COMMAND [ARG, ...]

# e.g. asynq ping -w 10000 -c 4 1.1.1.1

if [[ $# -le 0 ]]; then
    echo "Usage: $(basename $0) COMMAND [ARG, ...]"
    exit 10001
fi

if ! command -v ts >/dev/null; then
    echo "ts is not installed!"
    exit 10002
fi

# Set minimum number of pending jobs that will trigger a new job.
# Specify a higher value in your environment before calling this
# script to enable multiple pending jobs, which may be useful if
# the interval between calling asynq.sh is lower than the typical
# job duration.
pending_jobs_min=${ASYNQ_PENDING_JOBS_MIN:-0}

# Socket for TS to ensure dedicated queue
TMPDIR=${TMPDIR:-/tmp}
command_hash=$(echo "$@" | md5sum | awk '{print $1}')
export TS_SOCKET=$TMPDIR/socket-ts.$(id -u).$command_hash

cleanup_job() {
    local job_id
    local job_output_file
    job_id=$1
    job_output_file=$(ts -l | tail -n +2 | grep "^${job_id}\s" | awk '{print $3}')
    if [[ -n $job_output_file ]]; then
	# Due to a glitch with ts, the ts job's stderr file filename matches
        # only up to the 2nd to last character of the job's stdout file
        # filename, so we trim the last char before using wildcard delete.
        rm -f ${job_output_file::-1}*
    fi
    ts -r $job_id
}

# Get the list of all jobs for this queue
all_jobs_summary=$(ts -l | tail -n +2)
fin_jobs_summary=$(echo "$all_jobs_summary" | grep '^[0-9]\+\s\+finished')
# We'll use the last finished job as our data source
last_fin_job_summary=$(echo "$fin_jobs_summary" | tail -n 1)
last_fin_job_id=$(echo "$last_fin_job_summary" | awk '{print $1}')
if [[ -n $last_fin_job_id ]]; then
    last_fin_job_info=$(ts -i $last_fin_job_id)
    asynq_last_res=$(echo "$last_fin_job_info" | head -n1 | awk '{print $NF}')
    last_fin_job_output_file=$(echo "$last_fin_job_summary" | awk '{print $3}')
    asynq_last_out=$(cat "$last_fin_job_output_file")
else
    asynq_last_res=1
    asynq_last_out=
fi

pending_jobs_count=$(echo "$all_jobs_summary" | grep -v '^[0-9]\+\s\+finished' | printf "%s" "$a" | grep -c "^")
if [[ $pending_jobs_count -le $pending_jobs_min ]]; then
    # Start a new instance if there is none pending
    ts -E "$@" >/dev/null
fi

# Clean up all but the last finished job
while IFS= read -r job_summary; do
    cleanup_job $(echo $job_summary | awk '{print $1}')
done < <(printf '%s\n' "$fin_jobs_summary" | head -n -1)

# echo output of most recent finished job
echo "$asynq_last_out"

# exit with exit code of most recent finished job
exit $asynq_last_res
