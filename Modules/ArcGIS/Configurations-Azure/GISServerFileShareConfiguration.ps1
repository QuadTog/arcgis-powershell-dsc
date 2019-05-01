﻿Configuration GISServerFileShareConfiguration
{
	param(
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]
        $ServiceCredential

        ,[Parameter(Mandatory=$false)]
        [System.String]
        $ServiceCredentialIsDomainAccount = 'false'

        ,[Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential]
        $SiteAdministratorCredential

		,[Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]
        $MachineAdministratorCredential

        ,[Parameter(Mandatory=$false)]
        [System.Int32]
        $OSDiskSize = 0

        ,[Parameter(Mandatory=$false)]
        [System.String]
        $EnableDataDisk  

        ,[Parameter(Mandatory=$false)]
        [System.String]
        $ExternalDNSHostName    

        ,[Parameter(Mandatory=$false)]
        [System.String]
        $FileShareName = 'fileshare' 

        ,[Parameter(Mandatory=$false)]
        [System.String]
        $DebugMode
    )
    
    Import-DscResource -Name MSFT_xDisk
    Import-DscResource -Name MSFT_xSmbShare
    Import-DscResource -Name ArcGIS_Disk
    
    $FileShareHostName = $env:ComputerName    
    $FileShareLocalPath = (Join-Path $env:SystemDrive $FileShareName)      
    $IsDebugMode = $DebugMode -ieq 'true'
    $IsServiceCredentialDomainAccount = $ServiceCredentialIsDomainAccount -ieq 'true'

	Node localhost
	{            
        if($OSDiskSize -gt 0) 
        {
            ArcGIS_Disk OSDiskSize
            {
                DriveLetter = ($env:SystemDrive -replace ":" )
                SizeInGB    = $OSDiskSize
            }
        }
        
        if($EnableDataDisk -ieq 'true')
        {
            xDisk DataDisk
            {
                DiskNumber  =  2
                DriveLetter = 'F'
            }
        }

		$HasValidServiceCredential = ($ServiceCredential -and ($ServiceCredential.GetNetworkCredential().Password -ine 'Placeholder'))
        if($HasValidServiceCredential) 
        {
            if(-Not($IsServiceCredentialDomainAccount)){
                User ArcGIS_RunAsAccount
                {
                    UserName                = $ServiceCredential.UserName
                    Password				= $ServiceCredential
                    FullName				= 'ArcGIS Service Account'
                    Ensure					= 'Present'
                    PasswordChangeRequired  = $false
                    PasswordNeverExpires    = $true
                }
            }
        
			File FileShareLocationPath
			{
				Type						= 'Directory'
				DestinationPath				= $FileShareLocalPath
				Ensure						= 'Present'
				Force						= $true
			}      
		
			$Accounts = @('NT AUTHORITY\SYSTEM')
			if($ServiceCredential) { $Accounts += $ServiceCredential.GetNetworkCredential().UserName }
			if($MachineAdministratorCredential -and ($MachineAdministratorCredential.GetNetworkCredential().UserName -ine 'Placeholder') -and ($MachineAdministratorCredential.GetNetworkCredential().UserName -ine $ServiceCredential.GetNetworkCredential().UserName)) { $Accounts += $MachineAdministratorCredential.GetNetworkCredential().UserName }
			xSmbShare FileShare 
			{ 
				Ensure						= 'Present' 
				Name						= $FileShareName
				Path						= $FileShareLocalPath
				FullAccess					= $Accounts
				DependsOn					= if(-Not($IsServiceCredentialDomainAccount)){ @('[User]ArcGIS_RunAsAccount','[File]FileShareLocationPath')}else{ @('[File]FileShareLocationPath')}
			}
		}
	}
}