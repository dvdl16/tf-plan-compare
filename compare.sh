#!/bin/bash

# Dirk van der Laarse
# 2021-12-21
# This parses a plan.out.json file and compares S3 buckets, Glue Jobs, Glue Crawlers and Glue Workflows from the 
# project DE Int, Test and Prod environments

# PREREQUISITES
# - Have jq installed
# - Have AWS CLI v2 installed
# - Already logged in with cdh (can use aws-cli)
# - Have a file called "plan.out-prod.json", which is the json formatted terraform plan file
#   - To get this file:
#         cd cor-third-party-infrastructure
#         export AWS_PROFILE=project-de-tooling
#         ./run_locally.sh prod
#         terraform show -json > plan.out-prod.json
# - Have named profiles in your ~/.aws/credentials file called "project-de-tp-int", "project-de-tp-test" and "project-de-tp-prod"

# LIMITATIONS
# - This script will fail for AWS accounts with more than 25 Workflows


# Set up array of different AWS Calls to make in loop
types=("Glue Crawler" "Glue Job" "Glue Workflow")
type_api_response_key_names=("CrawlerNames" "JobNames" "Workflows")
type_max_results=("1000" "1000" "25")
aws_commands=("list-crawlers" "list-jobs" "list-workflows")

terraform_array_names=("terraform_crawlers" "terraform_jobs" "terraform_workflows")

# Get Glue Crawlers from terraform output file
readarray -t terraform_crawlers < <(cat plan.out-prod.json | jq '.values.root_module.child_modules[].resources[] | {type: .type, crawler_name: .values.name} | select( .type == "aws_glue_crawler" ) | .crawler_name ' )
# Get Glue Jobs from terraform output file
readarray -t terraform_jobs < <(cat plan.out-prod.json | jq '.values.root_module.child_modules[].resources[] | {type: .type, job_name: .values.name} | select( .type == "aws_glue_job" ) | .job_name ' )
# Get Glue Workflows from terraform output file
readarray -t terraform_workflows < <(cat plan.out-prod.json | jq '.values.root_module.resources[] | {type: .type, workflow_name: .values.name} | select( .type == "aws_glue_workflow" ) | .workflow_name ' )

# First line/headers
echo "Type,Name,Terraform,PROD,TEST,INT"

for i in ${!aws_commands[@]}; do

    aws_command=${aws_commands[$i]}

    # Get Glue Jobs from AWS environments
    # Int environment
    profile="project-de-tp-int"
    records_response=$(aws glue $aws_command --profile $profile --max-results ${type_max_results[$i]} --output json)
    readarray -t records_int < <(echo "$records_response" | jq -r ".${type_api_response_key_names[$i]}[]"  )

    # Test environment
    profile="project-de-tp-test"
    records_response=$(aws glue $aws_command --profile $profile --max-results ${type_max_results[$i]} --output json)
    readarray -t records_test < <(echo "$records_response" | jq -r ".${type_api_response_key_names[$i]}[]"  )

    # Prod environment
    profile="project-de-tp-prod"
    records_response=$(aws glue $aws_command --profile $profile --max-results ${type_max_results[$i]} --output json)
    readarray -t records_prod < <(echo "$records_response" | jq -r ".${type_api_response_key_names[$i]}[]"  )

    # Make a unique list of Records
    all_jobs=("${records_test[@]}" "${records_int[@]}" "${records_prod[@]}")
    readarray -t unique_records < <(printf "%s\n" "${all_jobs[@]}" | sort -u)

    # Get terraform array
    terraform_array_name=${terraform_array_names[$i]}
    records_terraform=$terraform_array_name[@]
    records_terraform=("${!records_terraform}")

    for record in "${unique_records[@]}"; do

        # Check if entry is terraformed
        in_terraform="no"
        if printf '%s\n' "${records_terraform[@]}" | grep -Fqx "\"$record\""; then
            in_terraform="yes"
        fi

        # Check if entry is in the PROD environment
        in_prod=""
        if printf '%s\n' "${records_prod[@]}" | grep -Fqx "$record"; then
            in_prod="yes"
        fi

        # Check if entry is in the TEST environment
        in_test=""
        if printf '%s\n' "${records_test[@]}" | grep -Fqx "$record"; then
            in_test="yes"
        fi

        # Check if entry is in the INT environment
        in_int=""
        if printf '%s\n' "${records_int[@]}" | grep -Fqx "$record"; then
            in_int="yes"
        fi

        echo "${types[$i]},$record,$in_terraform,$in_prod,$in_test,$in_int"

    done

    echo ""
    
done