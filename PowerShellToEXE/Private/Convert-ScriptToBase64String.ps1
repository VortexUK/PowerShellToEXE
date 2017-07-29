function Convert-ScriptToBase64String
{
    [OutputType([String])]
    PARAM
    (
        [parameter(Mandatory=$true,
            Position=0,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
            [ValidateScript({Test-Path -Path $_ -PathType Leaf })]
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