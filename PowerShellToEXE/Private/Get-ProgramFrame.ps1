<#
	.SYNOPSIS
		Builds the CSharp program frame that 'houses' the powershell script
	
	.DESCRIPTION
		Takes all of the settings specified by the user and puts them into the CSharp. The Script has been converted into a B64String to obfuscate it in the code (you can't just open the EXE in notepad)
	
	.PARAMETER B64InputScript
		The Script that has been converted into a B65 String for obfuscation purposes
	
	.PARAMETER ApartmentType
		The apartment mode. Default is Single threaded apartment mode
	
	.PARAMETER NoConsole
		If building a gui app, set this to true, otherwise leave as false.
	
	.PARAMETER CPUArchitecture
		Limit the architectures it can run on. By default this is set to 'anycpu'. Other options are 'x64' and 'x86'
	
	.PARAMETER Title
		This is the Title you see in the 'details' tab
	
	.PARAMETER Description
		This is the description you see in the 'details' tab of the output exe
	
	.PARAMETER Company
		This is the Company you see in the 'details' tab of the output exe. Default is 'CompanyName'
	
	.PARAMETER Product
		This is the Product you see in the 'details' tab of the output exe.
	
	.PARAMETER Copyright
		This is the Copyright you see in the 'details' tab of the output exe. Default is '(c) CompanyName all rights reserved'
	
	.PARAMETER Trademark
		This is the Trademark you see in the 'details' tab of the output exe.
	
	.PARAMETER Version
		This is the Version you see in the 'details' tab of the output exe
	
	.EXAMPLE
				PS C:\> Get-ProgramFrame -B64InputScript '342342AD324FE234BF23423423G'
				
				Output is too large to show in the example, but it outputs the full script as a single string
		
	
	.NOTES
		Program frame originally From PS2EXE by Ingo Karstein : https://gallery.technet.microsoft.com/scriptcenter/PS2EXE-Convert-PowerShell-9e4e07f1
        Improved by Markus Scholtes : https://gallery.technet.microsoft.com/scriptcenter/PS2EXE-GUI-Convert-e7cb69d5
        Also Rengifo : https://gallery.technet.microsoft.com/support-for-PowerShell-50-a633de5d
        
#>
function Get-ProgramFrame
{
	[CmdletBinding(PositionalBinding = $true,
				   SupportsPaging = $false,
				   SupportsShouldProcess = $false)]
	[OutputType([System.String])]
	param
	(
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 0)]
		[ValidateNotNullOrEmpty()]
		[System.String]$B64InputScript,
		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 1)]
		[ValidateSet('STA', 'MTA')]
		[System.String]$ApartmentType = 'STA',
		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 2)]
		[System.Boolean]$NoConsole = $false,
		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 3)]
		[System.String]$Title,
		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 4)]
		[System.String]$Description,
		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 5)]
		[System.String]$Company = 'CompanyName',
		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 6)]
		[System.String]$Product,
		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 7)]
		[System.String]$Copyright = '? CompanyName, All rights reserved',
		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 8)]
		[System.String]$Trademark,
		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
			 	   Position = 9)]
		[System.Version]$Version
		)
	
	BEGIN
	{
		# escape escape sequences in version info
		$Title = $Title -replace "\\", "\\"
		$Product = $Product -replace "\\", "\\"
		$Copyright = $Copyright -replace "\\", "\\"
		$Trademark = $Trademark -replace "\\", "\\"
		$Description = $Description -replace "\\", "\\"
		$Company = $Company -replace "\\", "\\"
	}
	PROCESS
	{

		#endregion
		return $programFrame
	}
	END { }
}