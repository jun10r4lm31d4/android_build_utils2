#!/bin/bash

# Check if a file argument is provided
if [[ "$#" == '0' ]]; then
    echo -e 'ERROR: No File Specified!' && exit 1
fi

# Query GoFile API to find the best server for upload
# Use jq to parse JSON response and extract the server name
SERVER=$(curl -s https://api.gofile.io/servers | jq -r '.data.servers[0].name')

# Iterate over all provided files
for FILE in "$@"; do
    # Check if the file exists
    if [[ ! -f "$FILE" ]]; then
        echo -e "ERROR: File '$FILE' not found!" && continue
    fi

    # Upload the file to GoFile
    LINK=$(curl -# -F "file=@$FILE" "https://${SERVER}.gofile.io/uploadFile" | jq -r '.data|.downloadPage') 2>&1
    
    # Check if upload was successful
    if [[ "$LINK" == "null" ]]; then
        echo -e "ERROR: Failed to upload '$FILE'!"
    else
        echo -e "Uploaded '$FILE': $LINK"
    fi
    
    echo
done
