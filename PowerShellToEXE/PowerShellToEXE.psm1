#######################################################################################################################
# File:             PowerShellToEXE.psm1      			                        	                                  #
# Author:           Ben McElroy                                                                                       #
# Publisher:        Gloucester Research Ltd                                                                           #
# Copyright:        © 2017 Gloucester Research Ltd. All rights reserved.                                              #
# Documentation:    Inbuilt																							  #
#######################################################################################################################
#Get public and private function definition files.
$Public  = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue )
#Dot source the files
Foreach($import in @($Public + $Private))
{
    Try
    {
        . $import.fullname
    }
    Catch
    {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}
#region Required Assemblies
$RequiredAssemblies = @()
$RequiredAssemblies += New-Object -typename psobject -property @{ 'Name' = "System.dll"; 'String' = "System, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089"; 'NoConsole' = $false; 'Required' = $true}
$RequiredAssemblies += New-Object -typename psobject -property @{'Name' = "System.Core.dll"; 'String' = "System.Core, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089"; 'NoConsole' = $false; 'Required' = $true}
$RequiredAssemblies += New-Object -typename psobject -property @{ 'Name' = "System.Management.Automation.dll"; 'String' = "System.Management.Automation, Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35"; 'NoConsole' = $false; 'Required' = $true }
$RequiredAssemblies += New-Object -typename psobject -property @{ 'Name' = "Microsoft.PowerShell.ConsoleHost.dll"; 'String' = "Microsoft.PowerShell.ConsoleHost, Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35"; 'NoConsole' = $true; 'Required' = $false }
$RequiredAssemblies += New-Object -typename psobject -property @{'Name' = "System.Windows.Forms.dll"; 'String' = "System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089"; 'NoConsole' = $true; 'Required' = $false}
$RequiredAssemblies += New-Object -typename psobject -property @{'Name' = "System.Drawing.dll"; 'String' = "System.Drawing, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a"; 'NoConsole' = $true; 'Required' = $false}
#endregion
$DefaultIconPath = "$PSScriptRoot\DefaultIcon.ico"
$Win32Manifest = @"
<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?>
<assembly xmlns=""urn:schemas-microsoft-com:asm.v1"" manifestVersion=""1.0"">
	<trustInfo xmlns=""urn:schemas-microsoft-com:asm.v2"">
		<security>
			<requestedPrivileges xmlns=""urn:schemas-microsoft-com:asm.v3"">
				<requestedExecutionLevel level=""requireAdministrator"" uiAccess=""false""/>
			</requestedPrivileges>
		</security>
	</trustInfo>
</assembly>
"@
Export-ModuleMember -Function $Public.Basename