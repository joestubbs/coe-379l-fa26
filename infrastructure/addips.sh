#!/usr/bin/env bash                                                                                                                                                                                                                           
set -euo pipefail                                                                                                                                                                                                                             
                                                                                                                                                                                                                                              
IPS_FILE=$1                                                                                                                                                                                                                                   
VMS_FILE=$2                                                                                                                                                                                                                                   
APPLY=false                                                                                                                                                                                                                                   
                                                                                                                                                                                                                                              
[[ "${1:-}" == "--apply" ]] && APPLY=true                                                                                                                                                                                                     
                                                                                                                                                                                                                                              
command -v openstack >/dev/null || {                                                                                                                                                                                                          
    echo "ERROR: openstack CLI not found" >&2                                                                                                                                                                                                 
    exit 1                                                                                                                                                                                                                                    
}                                                                                                                                                                                                                                             
                                                                                                                                                                                                                                              
command -v jq >/dev/null || {                                                                                                                                                                                                                 
    echo "ERROR: jq is required" >&2                                                                                                                                                                                                          
    exit 1                                                                                                                                                                                                                                    
}                                                                                                                                                                                                                                             
                                                                                                                                                                                                                                              
mapfile -t FIPS < <(sed 's/#.*//; /^[[:space:]]*$/d' "$IPS_FILE")                                                                                                                                                                             
mapfile -t VMS  < <(sed 's/#.*//; /^[[:space:]]*$/d' "$VMS_FILE")                                                                                                                                                                             
                                                                                                                                                                                                                                              
if (( ${#FIPS[@]} != ${#VMS[@]} )); then                                                                                                                                                                                                      
    echo "ERROR: Counts do not match:" >&2                                                                                                                                                                                                    
    echo "  Floating IPs: ${#FIPS[@]}" >&2                                                                                                                                                                                                    
    echo "  VMs:          ${#VMS[@]}" >&2                                                                                                                                                                                                     
    exit 1                                                                                                                                                                                                                                    
fi                                                                                                                                                                                                                                            
                                                                                                                                                                                                                                              
echo "Pairing ${#VMS[@]} VMs and floating IPs by line number."                                                                                                                                                                                
$APPLY || echo "DRY RUN: rerun with --apply to perform attachments."                                                                                                                                                                          
echo                                                                                                                                                                                                                                          
                                                                                                                                                                                                                                              
for i in "${!VMS[@]}"; do                                                                                                                                                                                                                     
    vm="${VMS[$i]}"                                                                                                                                                                                                                           
    fip="${FIPS[$i]}"                                                                                                                                                                                                                         
                                                                                                                                                                                                                                              
    mapfile -t ports < <(                                                                                                                                                                                                                     
        openstack port list \
            --server "$vm" \
            --status ACTIVE \
            -f value -c ID
    )

    if (( ${#ports[@]} == 0 )); then
        echo "ERROR: VM $vm has no ACTIVE port" >&2
        exit 1
    elif (( ${#ports[@]} > 1 )); then
        echo "ERROR: VM $vm has multiple ACTIVE ports:" >&2
        printf '  %s\n' "${ports[@]}" >&2
        echo "Refusing to guess which port should receive $fip." >&2
        exit 1
    fi

    port="${ports[0]}"
