# TF Plan Compare Script

This parses a `plan.out.json` file and compares S3 buckets, Glue Jobs, Glue Crawlers and Glue Workflows from the 
<Project> Int, Test and Prod environments

⚠ **This is a reference script and can probably not be run "as-is" in your environment** ⚠

## Prerequisites
- Have `jq` installed
- Have AWS CLI v2 installed
- Already logged in with <company-specific-AWS-tool> (can use `aws-cli`)
- Have a file called `plan.out-prod.json`, which is the json formatted terraform plan file
  - To get this file:
        ```bash
        cd cor-third-party-infrastructure
        export AWS_PROFILE=project-de-tooling
        ./run_locally.sh prod
        terraform show -json > plan.out-prod.json
        ```
- Have named profiles in your `~/.aws/credentials` file called `project-de-tp-int`, `project-de-tp-test` and `project-de-tp-prod`

## Limitations
- This script will fail for AWS accounts with more than 25 Workflows

## Usage

To run the script, mark it as executable and run it:

```bash
chmod +x ./compare.sh
./compare.sh
```