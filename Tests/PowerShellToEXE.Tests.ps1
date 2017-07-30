$PSVersion = $PSVersionTable.PSVersion.Major
Import-Module $PSScriptRoot\..\PowerShellToEXE -Force
<#Integration test example
Describe "Get-SEObject PS$PSVersion Integrations tests" {

    Context 'Strict mode' { 

        Set-StrictMode -Version latest

        It 'should get valid data' {
            $Output = Get-SEObject -Object sites
            $Output.count -gt 100 | Should be $True
            $Output.name -contains 'stack overflow'
        }
    }
}
#>
#Unit test example
InModuleScope PowerShellToEXE {
    Describe "Get-ProgramFrame Unit Tests" {
        $ApartmentType = 'MTA'
        $B64InputScript = 'TESTSCRIPT'
        $TestWrapper = "change: %ApartmentType% and: %b64InputScript%"
        Context 'Parameters Correct' {
            It 'should return a string' {
                $Output = Get-ProgramFrame -B64InputScript $B64InputScript -ApartmentType $ApartmentType -CSharpPowerShellEXEwrapper $TestWrapper
                $Output | Should BeOfType System.String
            }
            It 'should replace % Vars in string' {
                $Output = Get-ProgramFrame -B64InputScript $B64InputScript -ApartmentType $ApartmentType -CSharpPowerShellEXEwrapper $TestWrapper
                $Output | Should Match $ApartmentType
                $Output | Should Match $B64InputScript
                $Output | Should Not Match '%'
            }
        }
        Context "Test Parameter Validation" {
            $ParamTests = @()
            $ParamTests += New-Object -TypeName PSObject -Property @{'ApartmentType' = $ApartmentType; 'B64InputScript' = $B64InputScript; 'TestWrapper' = $Testwrapper; 'Result' = 'SUCCEED'}
            $ParamTests += New-Object -TypeName PSObject -Property @{'ApartmentType' = $ApartmentType; 'B64InputScript' = $B64InputScript; 'TestWrapper' = ''; 'Result' = 'THROW'}
            $ParamTests += New-Object -TypeName PSObject -Property @{'ApartmentType' = $ApartmentType; 'B64InputScript' = ''; 'TestWrapper' = $Testwrapper; 'Result' = 'THROW'}
            $ParamTests += New-Object -TypeName PSObject -Property @{'ApartmentType' = 'WRONG'; 'B64InputScript' = $B64InputScript; 'TestWrapper' = $Testwrapper; 'Result' = 'THROW'}
            foreach ($Test in $ParamTests)
            {
                It ("Should {3} with the following Params: ApartmentType='{0}' B64InputScript='{1}' Wrapper='{2}'" -f $Test.ApartmentType, $Test.B64InputScript,$Test.Testwrapper,$Test.Result) {
                    Switch ($Test.Result)
                    {
                        'SUCCEED'
                        {
                            $Output = Get-ProgramFrame -B64InputScript $Test.B64InputScript -ApartmentType $Test.ApartmentType -CSharpPowerShellEXEwrapper $Test.TestWrapper
                            $Output | Should BeOfType System.String
                        }
                        'THROW'
                        {
                            {Get-ProgramFrame -B64InputScript $Test.B64InputScript -ApartmentType $Test.ApartmentType -CSharpPowerShellEXEwrapper $Test.TestWrapper} | Should throw
                        }
                    }
                }
            }
        }
    }
    Describe "Get-CSHarpCodeProvider Unit Tests" {
        It 'should return an object of type [Microsoft.CSharp.CSharpCodeProvider]' {
            $Output = Get-CSHarpCodeProvider
            $Output | Should BeOfType Microsoft.CSharp.CSharpCodeProvider
        }
    }
    Describe "Get-AssemblyLocation Unit Tests" {
        $RequiredAssemblies = @()
        $RequiredAssemblies += New-Object -typename psobject -property @{'Name' = "System.dll";'String' = "System, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089"}
        $RequiredAssemblies += New-Object -typename psobject -property @{'Name' = "Microsoft.PowerShell.ConsoleHost.dll"; 'String' = "Microsoft.PowerShell.ConsoleHost, Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35"}
        Context 'Parameters Correct' {

            $Output = [System.Collections.ArrayList](Get-AssemblyLocation -Assemblies $RequiredAssemblies)
            It 'should return Assembly location' {
                $Output[0] | Should BeExactly 'C:\Windows\Microsoft.Net\assembly\GAC_MSIL\System\v4.0_4.0.0.0__b77a5c561934e089\System.dll'
            }
            It 'should be of type [System.Collections.ArrayList]' {
                ,$Output | Should BeOfType System.Collections.ArrayList
            }
        }
        Context "Test Parameter Validation" {
            $ParamTests = @()
            $ParamTests += New-Object -TypeName PSObject -Property @{'Assemblies' = $RequiredAssemblies; 'Result' = 'SUCCEED'}
            $ParamTests += New-Object -TypeName PSObject -Property @{'Assemblies' = @(); 'Result' = 'THROW'}
            foreach ($Test in $ParamTests)
            {
                It ("Should {1} with the following Params: Assembly Count ='{0}'" -f ($Test.Assemblies | Measure).Count, $Test.Result) {
                    Switch ($Test.Result)
                    {
                        'SUCCEED'
                        {
                            $Output = Get-AssemblyLocation -Assemblies $Test.Assemblies
                            ($Output | Measure-Object).Count | Should BeExactly ($Test.Assemblies | Measure).Count
                        }
                        'THROW'
                        {
                            {Get-AssemblyLocation -Assemblies $Test.Assemblies} | Should throw
                        }
                    }
                }
            }
        }
    }
    Describe "New-EXECompiler Unit Tests" {
        $RequiredAssemblies = @()
        $RequiredAssemblies += New-Object -typename psobject -property @{'Name' = "System.dll";'String' = "System, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089"}
        $RequiredAssemblies += New-Object -typename psobject -property @{'Name' = "Microsoft.PowerShell.ConsoleHost.dll"; 'String' = "Microsoft.PowerShell.ConsoleHost, Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35"}
        $TestNoExistPath = 'D:\BadPaath'
        $TestExistPath = 'D:\'
        Context 'Parameters Correct' {
            $Output = New-EXECompiler -AssemblyLocations $AssemblyLocations -EXEOutputPath $TestNoExistPath -EXEIconPath $TestExistPath
            It 'should return compiler of type [System.CodeDom.Compiler.CompilerParameters]' {
                $Output | Should BeOfType System.CodeDom.Compiler.CompilerParameters
            }
        }
    }
}