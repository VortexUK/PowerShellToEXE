function Convert-PSScriptToEXE
{
    [CmdletBinding(DefaultParameterSetName="STA")] 
    PARAM
    (
        [parameter(Mandatory=$true,
            Position=0,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
            [ValidateNotNullOrEmpty()]
            [ValidateScript({Test-Path -Path $_})]
        [System.String]$ScriptPath,
        [parameter(Mandatory=$false,
            Position=1,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
            [ValidateScript({!(Test-Path -Path $_)})]
        [System.String]$ExecutablePath,
        [parameter(Mandatory=$false,
            Position=2,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
            [ValidateScript({Test-Path -Path $_})]
        [System.String]$IconPath = $DefaultIconPath,
        [parameter(Mandatory=$false,
            Position=3,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            ParameterSetName='MTA')]
        [System.Management.Automation.SwitchParameter]$MTA,
        [parameter(Mandatory=$false,
            Position=3,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            ParameterSetName='STA')]
        [System.Management.Automation.SwitchParameter]$STA
    )
    BEGIN 
    {
         $ApartmentType = 'STA' # Default
         if ($MTA)
         {
            $ApartmentType = 'MTA'
         }
         # Execute name not required, set to same directory and replace 'ps1' with 'exe'
         if ([string]::IsNullOrEmpty($ExecutablePath))
         {
            $ExecutablePath = $ScriptPath -replace 'ps1$','exe'
         }
    }
    PROCESS 
    {
        $B64InputScript = Convert-ScripttoBase64String -ScriptPath $ScriptPath
        $ProgramFrame = Get-ProgramFrame -B64InputScript $B64InputScript -ApartmentType $ApartmentType -NoConsole $false -Title "TESTING!" -Version '0.0.0.2' 
        $Compiler = New-EXECompiler -AssemblyLocations $AssemblyLocations -EXEOutputPath $ExecutablePath -EXEIconPath $IconPath
        [System.CodeDom.Compiler.CompilerResults]$CompiledResult = $CSharpCodeProvider.CompileAssemblyFromSource($Compiler, $programFrame)
        return $CompiledResult
    }
    END { }
}