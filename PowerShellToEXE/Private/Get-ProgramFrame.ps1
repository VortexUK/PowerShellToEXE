function Get-ProgramFrame
{
    [OutputType([System.String])]
    PARAM
    (
        [parameter(Mandatory=$true,
            Position=0,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
            [ValidateNotNullOrEmpty()]
        [System.String]$B64InputScript,
        [parameter(Mandatory=$true,
            Position=1,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
            [ValidateNotNullOrEmpty()]
        [System.String]$CSharpPowerShellEXEwrapper,
        [parameter(Mandatory=$true,
            Position=2,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
            [ValidateSet('STA','MTA')]
        [System.String]$ApartmentType
    )
    BEGIN {}
    PROCESS
    {
        [System.String]$programframe = $CSharpPowerShellEXEwrapper -replace '%ApartmentType%',$ApartmentType -replace '%B64InputScript%',$B64InputScript
        return $programFrame
    }
    END {}
}