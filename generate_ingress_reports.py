import json
import os
from datetime import datetime
from tabulate import tabulate
import logging

# Expected clusters that should be processed
EXPECTED_CLUSTERS = {"cluster1", "cluster2"}  # Replace with your cluster prefixes

# Logging configuration
logging.basicConfig(level=logging.INFO)

def read_json_file(file_path):
    """
    Reads a JSON file and returns the data as a Python data structure.
    
    :param file_path: Path to the JSON file
    :return: Content of the JSON file as a Python data structure
    """
    with open(file_path, 'r', encoding='utf-8') as file:
        return json.load(file)

def extract_ingress_info(json_data):
    """
    Extracts relevant Ingress information from the given JSON data and performs validation checks.
    
    :param json_data: JSON data containing Ingress information
    :return: List of extracted Ingress information
    """
    ingress_info = []
    for item in json_data['items']:
        namespace = item['metadata']['namespace']
        name = item['metadata']['name']
        
        logging.info(f"Extracting data for Namespace: {namespace}, Name: {name}")
        
        # Extract hosts, marking missing 'host' keys as 'N/A'
        hosts = ", ".join(rule.get('host', 'N/A') for rule in item.get('spec', {}).get('rules', []))
        
        # Check if hosts were extracted correctly
        if 'N/A' in hosts or not hosts:
            logging.warning(f"Warning: Missing hosts for Ingress '{name}' in Namespace '{namespace}'.")
        
        # Extract the IP address of the LoadBalancer, if available, otherwise 'N/A'
        address = ", ".join(lb.get('ip', 'N/A') for lb in item.get('status', {}).get('loadBalancer', {}).get('ingress', []))
        
        # Check if the address was extracted correctly
        if not address:
            logging.warning(f"Warning: Missing IP address for Ingress '{name}' in Namespace '{namespace}'.")
        
        # Determine the ports used by this Ingress
        ports = set()
        if 'tls' in item.get('spec', {}):
            ports.add("443")  # Add port 443 by default if TLS is used
        for rule in item.get('spec', {}).get('rules', []):
            for path in rule.get('http', {}).get('paths', []):
                service_port = path.get('backend', {}).get('service', {}).get('port', {}).get('number', '80')
                ports.add(str(service_port))
        
        ports_str = ", ".join(ports) if ports else "80"  # Default to port 80 if no other ports are found
        
        # Check if ports were extracted correctly
        if not ports_str:
            logging.warning(f"Warning: Missing ports for Ingress '{name}' in Namespace '{namespace}'.")
        
        ingress_info.append([namespace, name, hosts, address, ports_str])
    return ingress_info

def generate_markdown_table(ingress_info, cluster_name, output_dir):
    """
    Generates a Markdown file with a table summarizing the extracted Ingress information.
    
    :param ingress_info: List of extracted Ingress information
    :param cluster_name: Name of the cluster for which the table is generated
    :param output_dir: Directory where the Markdown file will be saved
    """
    headers = ["Namespace", "Name", "Hosts", "Address", "Ports"]
    table = tabulate(ingress_info, headers, tablefmt="pipe")
    markdown_content = f"# Ingress Summary for Cluster: {cluster_name}\n\n{table}\n"
    
    # Save the generated table in a Markdown file
    output_file = os.path.join(output_dir, f"{cluster_name}_ingress.md")
    with open(output_file, 'w', encoding='utf-8') as file:
        file.write(markdown_content)
    
    print(f"Markdown file for cluster '{cluster_name}' created.")

def process_all_clusters(info_cache_dir, results_dir):
    """
    Processes all clusters in the specified cache directory, extracts the Ingress information,
    and generates Markdown files for each cluster. Also checks if all expected clusters were processed.
    
    :param info_cache_dir: Directory containing the cache files for the clusters
    :param results_dir: Directory where the results (Markdown files) will be saved
    """
    # Ensure the results directory exists, create it if it doesn't
    if not os.path.exists(results_dir):
        os.makedirs(results_dir)
    
    processed_clusters = set()
    
    # Iterate through all Ingress JSON files in the cache directory and process each one
    for filename in os.listdir(info_cache_dir):
        if filename.endswith("_ingress.json"):
            cluster_name = filename.split("_")[0]
            file_path = os.path.join(info_cache_dir, filename)
            
            # Track processed cluster prefixes, e.g., 'cluster1' or 'cluster2'
            cluster_prefix = cluster_name.split('-')[0]
            processed_clusters.add(cluster_prefix)
            
            # Read the JSON data from the file
            json_data = read_json_file(file_path)
            
            # Extract the Ingress information
            ingress_info = extract_ingress_info(json_data)
            
            # Generate the Markdown file for this cluster
            generate_markdown_table(ingress_info, cluster_name, results_dir)
    
    # Check if all expected clusters (e.g., 'cluster1' and 'cluster2') were processed
    missed_clusters = EXPECTED_CLUSTERS - processed_clusters
    if missed_clusters:
        print(f"Warning: The following expected clusters were not processed: {', '.join(missed_clusters)}")
    else:
        print("All expected clusters were processed.")
    
    # Summary of Ingresses with Issues
    print("\nSummary of Ingresses with Issues:")
    for filename in os.listdir(info_cache_dir):
        if filename.endswith("_ingress.json"):
            cluster_name = filename.split("_")[0]
            file_path = os.path.join(info_cache_dir, filename)
            json_data = read_json_file(file_path)
            for item in json_data['items']:
                namespace = item['metadata']['namespace']
                name = item['metadata']['name']
                hosts = ", ".join(rule.get('host', 'N/A') for rule in item.get('spec', {}).get('rules', []))
                if 'N/A' in hosts or not hosts:
                    print(f"Cluster: {cluster_name}, Namespace: {namespace}, Name: {name}, Hosts: {hosts} (Warning: Hosts missing)")
    
    print("Hinweis: Du kannst detailliertes Logging aktivieren, indem du das Skript mit der Option '-dl' ausführst.")

if __name__ == "__main__":
    # Dynamically generate the directory name based on today's date
    today_date = datetime.now().strftime("%Y%m%d")
    INFO_CACHE_DIR = f"info_cache_{today_date}"
    RESULTS_DIR = "results"

    try:
        # Start processing all clusters
        process_all_clusters(INFO_CACHE_DIR, RESULTS_DIR)
    except FileNotFoundError as e:
        # Error message if the specified directory was not found
        print(f"Error: {e}. The directory '{INFO_CACHE_DIR}' does not exist. Please check the date or directory path.")

