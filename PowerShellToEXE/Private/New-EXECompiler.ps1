function New-EXECompiler
{
    [OutputType([System.CodeDom.Compiler.CompilerParameters])]
    PARAM
    (
        [parameter(Mandatory=$true,
            Position=0,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
            [ValidateNotNullOrEmpty()]
        [System.Collections.ArrayList]$AssemblyLocations,
        [parameter(Mandatory=$true,
            Position=1,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
            [ValidateScript({!(Test-Path -Path $_)})]
        [System.String]$EXEOutputPath,
        [parameter(Mandatory=$true,
            Position=2,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
            [ValidateScript({Test-Path -Path $_})]
        [System.String]$EXEIconPath
    )
    BEGIN { }
    PROCESS
    {
        $Compiler = New-Object -TypeName System.CodeDom.Compiler.CompilerParameters($AssemblyLocations, $EXEOutputPath)
        $Compiler.GenerateInMemory = $false
        $Compiler.GenerateExecutable = $true
        $Compiler.CompilerOptions = "/platform:x64 /target:exe /win32icon:$($EXEIconPath)"
        $Compiler.IncludeDebugInformation = $true
        return $Compiler
    }
    END {}
}