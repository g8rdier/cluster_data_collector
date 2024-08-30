# Cluster Data Collection and Report Generation
This repository contains a set of scripts designed to collect data from multiple Kubernetes clusters and generate detailed Markdown reports. The process involves two main scripts:

- **Bash Script ('crawl_clusters.sh'):** This script collects data from the specified Kubernetes clusters.
- **Python Script ('generate_ingress_reports.py'):** This script processes the collected data and generates Markdown files summarizing the Ingress information for each cluster.

  
## Prerequisites
Before running the scripts, ensure that the following tools are installed on your system:
- Kubernetes CLI (kubectl): Used to interact with Kubernetes clusters.
- Cloud CLI (cloudctl): Used to interact with Kubernetes clusters (or any similar tool you use to interact with your clusters).
- Python 3.x: Required to run the Python script.


## Usage Instructions
# Step 1: Clone the Repository
Clone the repository to your local machine:
```
git clone https://github.com/your-repo/cluster-data-collector.git
cd cluster-data-collector
```

# Step 2: Run the Bash Script
The script crawl_clusters.sh collects data from the Kubernetes clusters specified in the script. It switches contexts to each cluster, retrieves the required information, and stores it in the info_cache_ directory.

*First Run of the Script*
Before the first run of the script, log in using cloudctl login (or your cluster access tool).
When running the script for the first time, set the environment variable FORCE_REBUILD to 1 to force the collection of new data from all clusters:

```./crawl_clusters.sh -dl```
-dl: Enables detailed logging, providing more verbose output for debugging and monitoring purposes.

*Subsequent Runs*
In subsequent runs, the script will use cached data unless FORCE_REBUILD is manually set to 1. You can run the script without additional arguments:
```
./crawl_clusters.sh
```
Note: The script automatically toggles the FORCE_REBUILD variable depending on whether it has been run before. The script creates a marker file (cluster_crawler_marker) after a successful run, which is used to determine whether the cache should be rebuilt on the next run.

# Step 3: Run the Python Script
After collecting the cluster data, run the Python script to generate Markdown reports:
```python3 generate_ingress_reports.py -dl```
-dl: Enables detailed logging in the Python script.
This script processes the data stored in the info_cache_ directory and generates Markdown files summarizing the Ingress information for each cluster. The Markdown files are saved in the results directory and are named according to their respective clusters.

# Step 4: View the Markdown Reports
After running the Python script, navigate to the results directory to view the generated Markdown reports. Each file is named after the cluster with a _ingress.md suffix.

Example:

python
Copy code
results/
├── cluster1_ingress.md
├── cluster2_ingress.md
...

## Troubleshooting
Authentication Issues: Ensure you have the required permissions and credentials to access the Kubernetes clusters.
Force Rebuild: If the script does not collect new data, try setting the FORCE_REBUILD environment variable to 1 manually.
Detailed Logging: Use the -dl option for more detailed output that can help with troubleshooting.

## Example Workflow
1. Run the Bash Script to Collect Cluster Data
```./crawl_clusters.sh -dl```
2. Run the Python Script to generate reports
```python3 generate_ingress_reports.py -dl```
3. View the generated Reports in the results directory

## Script Details
# Bash Script (crawl_clusters.sh)
- Purpose: Collects data from Kubernetes clusters, including IP addresses, pod details, and Ingress configurations.
- Logging: Provides detailed logs when run with the -dl option. It also automatically toggles the FORCE_REBUILD variable depending on whether it is the first time the script is run.
- Outputs: Stores collected data in the info_cache_ directory and creates a marker file after successful completion.

# Python Script (generate_ingress_reports.py)
- Purpose: Processes the collected data and generates Markdown reports summarizing the Ingress configurations for each cluster.
- Logging: Provides detailed logs when run with the -dl option.
- Outputs: Generates Markdown files in the results directory.
