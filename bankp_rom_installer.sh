#!/bin/bash

# Define the working directory
WorkingDirectory=$(pwd)
length=53

clear
echo " .------------------------."
echo " |Building Bank Panic ROMs|"
echo " '------------------------'"

# Create directories
mkdir -p "$WorkingDirectory/arcade/bankp"

echo "Copying CPU ROMs"
cp epr-6175.7e "$WorkingDirectory/arcade/bankp/"
cp epr-6174.7f "$WorkingDirectory/arcade/bankp/"
cp epr-6173.7h "$WorkingDirectory/arcade/bankp/"

# Define the original file and new file paths
originalFilePath="$WorkingDirectory/epr-6176.7d"
newFilePath="$WorkingDirectory/arcade/bankp/epr-6176.7d_"

# Concatenate the original file with 8KB of zeros
cat "$originalFilePath" <(head -c 8192 < /dev/zero) > "$newFilePath"

# Confirm the action
echo "Concatenation complete. New file created: $newFilePath"

echo "Copying tiles"
cp epr-6165.5l "$WorkingDirectory/arcade/bankp/"
cp epr-6166.5k "$WorkingDirectory/arcade/bankp/"
cp epr-6172.5b "$WorkingDirectory/arcade/bankp/"
cp epr-6171.5d "$WorkingDirectory/arcade/bankp/"
cp epr-6170.5e "$WorkingDirectory/arcade/bankp/"
cp epr-6169.5f "$WorkingDirectory/arcade/bankp/"
cp epr-6168.5h "$WorkingDirectory/arcade/bankp/"
cp epr-6167.5i "$WorkingDirectory/arcade/bankp/"

echo "Copying LUTs"
# Define the original file path and new file path
originalFilePath="$WorkingDirectory/pr-6177.8a"
newFilePath="$WorkingDirectory/arcade/bankp/palettep"

# Concatenate the file eight times
for i in {1..8}; do
    cat "$originalFilePath" >> "$newFilePath"
done

echo "Concatenation complete. New file created: $newFilePath"

cp pr-6178.6f "$WorkingDirectory/arcade/bankp/"
cp pr-6179.5a "$WorkingDirectory/arcade/bankp/"

echo "Generating blank config file"
# Generate a file filled with 0xFF
bytes=$(printf '\xFF%.0s' {1..53})

output_file="$WorkingDirectory/arcade/bankp/bankpcfg"
echo -n "$bytes" > "$output_file"

echo "All done!"
