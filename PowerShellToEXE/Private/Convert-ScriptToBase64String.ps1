<#
	.SYNOPSIS
		Converts script to base 64 string
	
	.DESCRIPTION
		Takes a path and converts the contents to a single base 64 string
	
	.PARAMETER ScriptPath
		Path to the script
	
	.EXAMPLE
				PS C:\> Convert-ScriptToBase64String -ScriptPath 'D:\test-exe.ps1'
				V3JpdGUtSG9zdCAiVEVTVElORyBTQ1JJUFQhIiAtZm9yZWdyb3VuZGNvbG9yIFJlZA==
	.NOTES
		None
#>
function Convert-ScriptToBase64String
{
	[CmdletBinding(PositionalBinding = $true,
				   SupportsPaging = $false,
				   SupportsShouldProcess = $false)]
	[OutputType([String])]
	param
	(
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 0)]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
		[System.String]$ScriptPath
	)
	
	BEGIN { }
	PROCESS
	{
		[System.String]$content = (Get-Content -LiteralPath ($ScriptPath) -Encoding UTF8) -join "`r`n"
		[System.String]$B64script = [System.Convert]::ToBase64String(([System.Text.Encoding]::UTF8.GetBytes($content)))
		return $B64script
	}
	END { }
}