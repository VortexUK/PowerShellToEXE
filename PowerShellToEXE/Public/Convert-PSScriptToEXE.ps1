<#
	.SYNOPSIS
		Converts a powershell script to an executable.
	
	.DESCRIPTION
		Takes a Powershell script and uses the 'Add-Type' function to create a useable executable. Useful for obfuscating code. Also works for gui based apps using the -NoConsole $True option
	
	.PARAMETER ScriptPath
		The Full path to the Script. eg: D:\MyScript.ps1. This is the Only required variable
	
	.PARAMETER ExecutablePath
		The full path to the output exe. Eg D:\MyScript.exe - not required, function will just replace 'ps1' with exe if not specified (path stays the same)
	
	.PARAMETER IconPath
		If you have a custom icon file you can use this. Full path required and only .ico files accepted
	
	.PARAMETER MTA
		Multithreated Apartment mode. Mainly for GUI apps
	
	.PARAMETER STA
		Singlethreaded Apartment mode. This is the default
	
	.PARAMETER NoConsole
		If building a gui app, set this to true, otherwise leave as false.
	
	.PARAMETER CPUArchitecture
		Limit the architectures it can run on. By default this is set to 'anycpu'. Other options are 'x64' and 'x86'
	
	.PARAMETER Title
		This is the Title you see in the 'details' tab
	
	.PARAMETER Description
		This is the description you see in the 'details' tab of the output exe
	
	.PARAMETER Company
		This is the Company you see in the 'details' tab of the output exe. Default is 'GResearch'
	
	.PARAMETER Product
		This is the Product you see in the 'details' tab of the output exe.
	
	.PARAMETER Copyright
		This is the Copyright you see in the 'details' tab of the output exe. Default is '(c) GResearch all rights reserved'
	
	.PARAMETER Trademark
		This is the Trademark you see in the 'details' tab of the output exe.
	
	.PARAMETER Version
		This is the Version you see in the 'details' tab of the output exe
	
	.EXAMPLE
		PS C:\> Convert-PSScriptToEXE -ScriptPath D:\test-convert.ps1
		
		FullName                DirectoryName Extension VersionInfo
		--------            	------------- --------- -----------
		D:\test-convert.exe 	D:\testing    .exe      File:             D:\test-convert.exe...
		
		Converts the powershell script with default settings and places the file in the same directory as the script
	
	.EXAMPLE
		Convert-PSScriptToEXE -ScriptPath D:\testing\test-exe.ps1 -ExecutablePath D:\testing\MODULE_test3.exe -MTA -Version 0.0.0.3 -Title "Test App" -Description "Some description" -Product "My Product"
		
		FullName                    DirectoryName Extension VersionInfo
		--------                    ------------- --------- -----------
		D:\testing\MODULE_test3.exe D:\testing    .exe      File:             D:\testing\MODULE_test3.exe...
		
		Converts the powershell script and specifies the Filename + MTA, as well as setting some of the properties on the file
	
	.NOTES
		This only works with PS4.0 and above!
#>
function Convert-PSScriptToEXE
{
	[CmdletBinding(DefaultParameterSetName = 'STA',
				   PositionalBinding = $true,
				   SupportsPaging = $false,
				   SupportsShouldProcess = $false)]
	[OutputType([System.IO.FileInfo])]
	param
	(
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 0)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ (Test-Path -Path $_ -PathType Leaf) -and ((Get-Item -Path $_).Extension -match '\.ps') })]
		[System.String]$ScriptPath,
		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 1)]
		[ValidateScript({ !(Test-Path -Path $_) -and ($_ -match '.exe$') })]
		[System.String]$ExecutablePath,
		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 2)]
		[ValidateScript({ (Test-Path -Path $_) -and ((Get-Item -Path $_).Extension -eq '.ico') })]
		[System.String]$IconPath = $DefaultIconPath,
		[Parameter(ParameterSetName = 'MTA',
				   Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 3)]
		[System.Management.Automation.SwitchParameter]$MTA,
		[Parameter(ParameterSetName = 'STA',
				   Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 3)]
		[System.Management.Automation.SwitchParameter]$STA,
		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 4)]
		[System.Management.Automation.SwitchParameter]$RequireAdmin,
		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 5)]
		[System.Management.Automation.SwitchParameter]$NoConsole,
		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 6)]
		[ValidateSet('anycpu', 'x64', 'x86')]
		[System.String]$CPUArchitecture = 'anycpu',
		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 7)]
		[System.String]$Title,
		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 8)]
		[System.String]$Description,
		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 9)]
		[System.String]$Company = 'GResearch',
		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 10)]
		[System.String]$Product,
		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 11)]
		[System.String]$Copyright = '© GResearch, All rights reserved',
		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 12)]
		[System.String]$Trademark,
		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 13)]
		[System.Version]$Version
	)
	
	BEGIN
	{
		$CreateEXEScriptBlock = {
			$TempPath = [IO.Path]::GetTempPath()
			if (($Using:RequireAdmin).IsPresent -eq $true)
			{
				$EXEName = Get-Item -Path $Using:ExecutablePath | Select-Object -ExpandProperty Name
				$ManifestPath = "$TempPath\$EXEName.win32manifest"
				$Using:Win32Manifest | Set-Content -Path $ManifestPath -Encoding UTF8
				$ConfigOptions = "/platform:$($Using:CPUArchitecture) /target:$($Using:Target) /win32icon:`"$($Using:IconPath)`" /win32manifest:`"$ManifestPath`""
			}
			else
			{
				$ConfigOptions = "/platform:$($Using:CPUArchitecture) /target:$($Using:Target) /win32icon:`"$($Using:IconPath)`""
			}
			
			$CompilerParameters = New-Object -TypeName System.CodeDom.Compiler.CompilerParameters
			$CompilerParameters.CompilerOptions = $ConfigOptions
			$CompilerParameters.OutputAssembly = $Using:ExecutablePath
			$Using:AssemblyLocations | ForEach-Object -Process { $null = $CompilerParameters.ReferencedAssemblies.Add($_) }
			$CompilerParameters.TempFiles = New-Object -TypeName System.CodeDom.Compiler.TempFileCollection ($TempPath)
			$CompilerParameters.GenerateInMemory = $false
			$CompilerParameters.GenerateExecutable = $true
			$CompilerParameters.IncludeDebugInformation = $false
			Add-Type -TypeDefinition $Using:ProgramFrame -CompilerParameters $CompilerParameters -WarningAction SilentlyContinue
		}
	}
	PROCESS
	{
		$ApartmentType = 'STA' # Default
		if ($MTA)
		{
			$ApartmentType = 'MTA'
		}
		# Execute name not required, set to same directory and replace 'ps1' with 'exe'
		if ([string]::IsNullOrEmpty($ExecutablePath))
		{
			$ExecutablePath = $ScriptPath -replace 'ps1$', 'exe'
		}
		$ProgramDetailsSplat = @{
			'Title' = $Title
			'Description' = $Description
			'Company' = $Company
			'Product' = $Product
			'Copyright' = $Copyright
			'Trademark' = $Trademark
			'Version' = $Version
		}
		$Target = 'exe'
		if ($NoConsole)
		{
			$Target = 'winexe'
		}
		try
		{
			$AssemblyLocations = Get-AssemblyLocation -Assemblies $RequiredAssemblies -NoConsole ($NoConsole.IsPresent)
			$B64InputScript = Convert-ScripttoBase64String -ScriptPath $ScriptPath
			$ProgramFrame = Get-ProgramFrame -B64InputScript $B64InputScript -ApartmentType $ApartmentType -NoConsole ($NoConsole.IsPresent) @ProgramDetailsSplat
			$null = Start-Job -Name "CompileEXE" -ScriptBlock $CreateEXEScriptBlock | Wait-Job | Remove-Job
			return (Get-Item -Path $ExecutablePath)
		}
		catch
		{
			Write-Error -Message 'Error Creating required Parameters for Executable:'
			$_
			return
		}
	}
	END { }
}