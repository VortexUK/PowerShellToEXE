<#
	.SYNOPSIS
		Returns the required assemblies the compiler must add
	
	.DESCRIPTION
		Depending on weather the app is a console application or not will determine which assemblies are required. This returns a String based array list of the full path locations of the required assemblies
	
	.PARAMETER Assemblies
		List of Assemblies with the format:
		Name          	String         																NoConsole       Required
		------			------																		------			-----
		System.dll		System, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089	false			true
	
	.PARAMETER NoConsole
		Is the app a console application? If so this should be false. If not it should be true
	
	.EXAMPLE
				PS C:\> Get-AssemblyLocation -Assemblies $RequiredAssemblies
				C:\Windows\Microsoft.Net\assembly\GAC_MSIL\System\v4.0_4.0.0.0__b77a5c561934e089\System.dll
	
	.NOTES
		None
#>
function Get-AssemblyLocation
{
	[CmdletBinding(PositionalBinding = $true,
				   SupportsPaging = $false,
				   SupportsShouldProcess = $false)]
	[OutputType([System.Collections.ArrayList])]
	param
	(
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 0)]
		[ValidateNotNullOrEmpty()]
		[System.Collections.ArrayList]$Assemblies,
		[Parameter(Mandatory = $false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 1)]
		[System.Boolean]$NoConsole = $false
	)
	
	BEGIN
	{
		$AssemblyLocations = New-Object -TypeName System.Collections.ArrayList($null)
		$Assemblies = $Assemblies | Where-Object -FilterScript { $_.NoConsole -eq $NoConsole -or $_.Required -eq $true }
	}
	PROCESS
	{
		$LoadedAssemblies = [System.AppDomain]::CurrentDomain.GetAssemblies()
		foreach ($Assembly in $Assemblies)
		{
			if ($LoadedAssemblies.ManifestModule.Name -notcontains $Assembly.Name)
			{
				$AssemblyName = new-object -TypeName System.Reflection.AssemblyName($Assembly.String)
				$null = [System.AppDomain]::CurrentDomain.Load($AssemblyName)
				$LoadedAssemblies = [System.AppDomain]::CurrentDomain.GetAssemblies()
			}
			$Location = $LoadedAssemblies | Where-Object -FilterScript { $_.ManifestModule.Name -eq $Assembly.Name } | Select-Object -First 1 -ExpandProperty Location
			$null = $AssemblyLocations.Add($Location)
		}
		return $AssemblyLocations
	}
	END { }
}