$WorkingDirectory = Get-Location
$length = 53

	cls
	Write-Output " .------------------------."
	Write-Output " |Building Bank Panic ROMs|"
	Write-Output " '------------------------'"

	New-Item -ItemType Directory -Path $WorkingDirectory"\arcade" -Force
	New-Item -ItemType Directory -Path $WorkingDirectory"\arcade\bankp" -Force

	Write-Output "Copying CPU ROMs"
	cmd /c copy /b epr-6175.7e $WorkingDirectory"\arcade\bankp\"
	cmd /c copy /b epr-6174.7f $WorkingDirectory"\arcade\bankp\"
	cmd /c copy /b epr-6173.7h $WorkingDirectory"\arcade\bankp\"
	
	# Define the original file and new file paths
	$originalFilePath = "$WorkingDirectory\epr-6176.7d"
	$newFilePath = "$WorkingDirectory\arcade\bankp\epr-6176.7d_"

	# Read the original file
	$originalContent = [System.IO.File]::ReadAllBytes($originalFilePath)

	# Create an array of 8KB (8192 bytes) filled with zeros
	$zeros = New-Object byte[] (8192)

	# Concatenate the original content with the zeros
	$combinedContent = $originalContent + $zeros

	# Write the combined content to the new file
	[System.IO.File]::WriteAllBytes($newFilePath, $combinedContent)

	# Confirm the action
	Write-Output "Concatenation complete. New file created: $newFilePath"

	Write-Output "Copying tiles"
	cmd /c copy /b epr-6165.5l $WorkingDirectory"\arcade\bankp\"
	cmd /c copy /b epr-6166.5k $WorkingDirectory"\arcade\bankp\"
	cmd /c copy /b epr-6172.5b $WorkingDirectory"\arcade\bankp\"
	cmd /c copy /b epr-6171.5d $WorkingDirectory"\arcade\bankp\"
	cmd /c copy /b epr-6170.5e $WorkingDirectory"\arcade\bankp\"
	cmd /c copy /b epr-6169.5f $WorkingDirectory"\arcade\bankp\"
	cmd /c copy /b epr-6168.5h $WorkingDirectory"\arcade\bankp\"
	cmd /c copy /b epr-6167.5i $WorkingDirectory"\arcade\bankp\"
	
	
	Write-Output "Copying LUTs"
	# Define the original file path and new file path
	$originalFilePath = "$WorkingDirectory\pr-6177.8a"
	$newFilePath = "$WorkingDirectory\arcade\bankp\palettep"

	# Read the original file
	$originalContent = [System.IO.File]::ReadAllBytes($originalFilePath)

	# Concatenate the file eight times
	$combinedContent = @()
	for ($i = 0; $i -lt 8; $i++) {
	$combinedContent += $originalContent
	}

	# Write the combined content to the new file
	[System.IO.File]::WriteAllBytes($newFilePath, $combinedContent)

	Write-Output "Concatenation complete. New file created: $newFilePath"

	cmd /c copy /b pr-6178.6f $WorkingDirectory"\arcade\bankp\"
	cmd /c copy /b pr-6179.5a $WorkingDirectory"\arcade\bankp\"
	
	Write-Output "Generating blank config file"
	$bytes = New-Object byte[] $length
	for ($i = 0; $i -lt $bytes.Length; $i++) {
	$bytes[$i] = 0xFF
	}
	
	$output_file = Join-Path -Path $WorkingDirectory -ChildPath "arcade\bankp\bankpcfg"
	$output_directory = [System.IO.Path]::GetDirectoryName($output_file)
	[System.IO.File]::WriteAllBytes($output_file,$bytes)

	Write-Output "All done!"