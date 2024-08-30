#!/bin/bash

# set -x  # Debugging mode to output each command

# Default logging level
DETAILED_LOGGING=false

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -dl) DETAILED_LOGGING=true ;;  # Enable detailed logging
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Function for logging messages (depending on the logging flag)
log() {
    local level="$1"
    local message="$2"
    if [ "$DETAILED_LOGGING" = true ]; then
        echo "$level: $message"
    elif [ "$level" != "DEBUG" ]; then
        echo "$level: $message"
    fi
}

# Script to collect data from all specified clusters
CLUSTERS="cluster1 cluster2"  # Replace with your cluster names

# Marker file to track if the script was run successfully before
MARKER_FILE="$(dirname "$0")/cluster_crawler_marker"

# Check if FORCE_REBUILD should be set
if [ -f "$MARKER_FILE" ]; then
    FORCE_REBUILD=0
else
    FORCE_REBUILD=1
fi

# Explanation: When FORCE_REBUILD is set to 1, all cached cluster information is refreshed.
# If it is set to 0 or not defined, existing cache data is used.

# Function to create a directory if it doesn't exist
create_directory() {
    locDir="${1}"
    if [ ! -d "${locDir}" ]; then
        mkdir -p "${locDir}" > /dev/null
    fi
    if [ ! -d "${locDir}" ]; then
        log "ERROR" "Failed to create directory '${locDir}'"
        return 1
    fi
    return 0
}

# Function to create an empty directory (removes it first if it exists)
create_empty_directory() {
    locDir="${1}"
    rm -rf "${locDir}" > /dev/null 2>&1
    create_directory "${locDir}"
}

# Function to set the Kubernetes context for a given cluster
set_kube_context() {
    if kubectl config use-context "${1}"; then
        log "INFO" "Successfully switched to context ${1}"
        return 0
    else
        log "ERROR" "Failed to switch to context ${1}"
        return 1
    fi
}

# Begin the main script

# Temporary directory
DAYSTAMP="$(date +"%Y%m%d")"

# Set up the info cache directory
INFO_CACHE="info_cache_${DAYSTAMP}"

if ! create_directory "${INFO_CACHE}"; then
    exit 1
fi

if [ "${FORCE_REBUILD}" == "1" ]; then
    log "INFO" "FORCE_REBUILD is set to 1, refreshing all cached cluster information"
    rm -rf "${INFO_CACHE}/*" > /dev/null 2>&1
else
    log "INFO" "FORCE_REBUILD is not set to 1, using cached cluster information"
fi

# Function to log errors and debugging information
debug_crawler_error() {
    pwd
    ls -al
    ls -al "${INFO_CACHE}"
}

# IP Scraper: Retrieve and store IP addresses of all clusters
CLSTR_IPS="${INFO_CACHE}/cluster_ips.json"
if [ ! -s "${CLSTR_IPS}" ]; then
    if ! cloudctl ip list -o json > "${CLSTR_IPS}"; then  # Replace 'cloudctl' with your command
        log "ERROR" "Failed to execute 'cloudctl ip list -o json'"
        debug_crawler_error
        exit 1
    fi

    if [ ! -s "${CLSTR_IPS}" ]; then
        log "ERROR" "'cloudctl ip list' produced no output in '${CLSTR_IPS}'"
        debug_crawler_error
        exit 1
    fi
fi

# NAMEID Scraper: Retrieve and store the name-ID mapping of all clusters
NAMEID_MAP="${INFO_CACHE}/name_id.map"
if [ ! -s "${NAMEID_MAP}" ]; then
    : > "${NAMEID_MAP}"  # Create or empty the file

    log "DEBUG" "Our clusters are '${CLUSTERS}'"
    for tnt in ${CLUSTERS}; do
        log "DEBUG" "Tenant is ${tnt}"
        # List clusters for each tenant and add to the map
        if ! cloudctl cluster list --tenant "${tnt}" | grep -v "NAME" | awk '{ print $4";"$1 }' >> "${NAMEID_MAP}"; then
            log "ERROR" "Failed to list clusters for tenant '${tnt}'"
            debug_crawler_error
            exit 1
        fi
    done

    # Final check if the name_id.map file is filled
    if [ ! -s "${NAMEID_MAP}" ]; then
        log "ERROR" "Failed to create/fill '${NAMEID_MAP}'"
        debug_crawler_error
        exit 1
    fi
fi

# Cluster Describer: Retrieve and store detailed information for each cluster
while IFS=";" read -r CLSTRNM CLSTRID; do
    log "DEBUG" "Describing ${CLSTRNM} with ${CLSTRID}"

    CLSTR_INFO="${INFO_CACHE}/${CLSTRNM}_describe.json"
    if [ ! -s "${CLSTR_INFO}" ]; then
        if ! cloudctl cluster describe "${CLSTRID}" -o json > "${CLSTR_INFO}"; then
            log "ERROR" "Failed to describe cluster '${CLSTRNM}' with ID '${CLSTRID}'"
            debug_crawler_error
            exit 1
        fi
    fi

    if [ ! -s "${CLSTR_INFO}" ]; then
        log "ERROR" "Failed to create/fill '${CLSTR_INFO}'"
        debug_crawler_error
        exit 1
    fi
done < "${NAMEID_MAP}"

# Kubernetes Data Collector: Retrieve and store Kubernetes information (Pods and Ingress) for each cluster
while IFS=";" read -r CLSTRNM CLSTRID; do
    log "DEBUG" "Collecting kubectl cluster content for ${CLSTRNM}"

    # Define file paths for storing cluster information
    CLSTR_PODS="${INFO_CACHE}/${CLSTRNM}_pods.json"
    CLSTR_INGRESS="${INFO_CACHE}/${CLSTRNM}_ingress.json"

    # Check if the kube context exists
    if ! kubectl config get-contexts "${CLSTRNM}" &> /dev/null; then
        log "WARNING" "No kube context found for cluster '${CLSTRNM}', skipping..."
        continue
    fi

    # Switch to the appropriate kube context for the cluster
    if ! set_kube_context "${CLSTRNM}"; then
        log "ERROR" "Failed to set kube context for cluster '${CLSTRNM}'"
        debug_crawler_error
        exit 1
    fi

    # Retrieve and store Pod information
    if ! kubectl get pods -A -o json > "${CLSTR_PODS}"; then
        log "ERROR" "Failed to retrieve pods for cluster '${CLSTRNM}'"
        debug_crawler_error
        exit 1
    fi

    # Retrieve and store Ingress information
    if ! kubectl get ingress -A -o json > "${CLSTR_INGRESS}"; then
        log "ERROR" "Failed to retrieve ingress for cluster '${CLSTRNM}'"
        debug_crawler_error
        exit 1
    fi
done < "${NAMEID_MAP}"

# Double-check that all clusters from name_id.map were processed
ALL_CLUSTERS_PROCESSED_SUCCESSFULLY=true

while IFS=";" read -r CLSTRNM CLSTRID; do
    CLSTR_INFO="${INFO_CACHE}/${CLSTRNM}_describe.json"
    
    if [ ! -s "${CLSTR_INFO}" ]; then
        log "ERROR" "Cluster '${CLSTRNM}' was not processed correctly"
        debug_crawler_error
        ALL_CLUSTERS_PROCESSED_SUCCESSFULLY=false
    fi
done < "${NAMEID_MAP}"

# Cleanup function to remove files if all clusters were processed successfully
cleanup() {
    if [ $ALL_CLUSTERS_PROCESSED_SUCCESSFULLY == true ]; then
        log "INFO" "All clusters were processed successfully, name_id.map and cluster_ips.json will be removed"
        rm -f "${NAMEID_MAP}"
        rm -f "${CLSTR_IPS}"
        # Create marker file to indicate successful run
        touch "$MARKER_FILE"
    else
        log "INFO" "Some clusters were not processed successfully, name_id.map and cluster_ips.json will be retained for further investigation."
    fi
}
trap cleanup EXIT

log "INFO" "Hinweis: Du kannst detailliertes Logging aktivieren, indem du das Skript mit der Option '-dl' ausführst."

exit 0

