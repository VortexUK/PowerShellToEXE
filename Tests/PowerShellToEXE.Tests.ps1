Import-Module $PSScriptRoot\..\PowerShellToEXE -Force
InModuleScope PowerShellToEXE {
    Describe "Get-ProgramFrame Unit Tests" {
        $ApartmentType = 'MTA'
        $B64InputScript = 'TESTSCRIPT'
        Context 'Parameters Correct' {
            It 'should return a string' {
                $Output = Get-ProgramFrame -B64InputScript $B64InputScript -ApartmentType $ApartmentType -NoConsole $false
                $Output | Should BeOfType System.String
            }
            It 'should contain Apartment Type and b64 script' {
                $Output = Get-ProgramFrame -B64InputScript $B64InputScript -ApartmentType $ApartmentType -NoConsole $false
                $Output | Should Match $ApartmentType
                $Output | Should Match $B64InputScript
            }
        }
        Context "Test Parameter Validation" {
            $ParamTests = @()
            $ParamTests += New-Object -TypeName PSObject -Property @{'ApartmentType' = $ApartmentType; 'B64InputScript' = $B64InputScript; 'NoConsole' = $false; 'Result' = 'SUCCEED'}
            $ParamTests += New-Object -TypeName PSObject -Property @{'ApartmentType' = $ApartmentType; 'B64InputScript' = ''; 'NoConsole' = $false; 'Result' = 'THROW'}
            $ParamTests += New-Object -TypeName PSObject -Property @{'ApartmentType' = 'WRONG'; 'B64InputScript' = $B64InputScript; 'NoConsole' = $false; 'Result' = 'THROW'}
            foreach ($Test in $ParamTests)
            {
                It ("Should {3} with the following Params: ApartmentType='{0}' B64InputScript='{1}' Wrapper='{2}'" -f $Test.ApartmentType, $Test.B64InputScript,$Test.NoConsole,$Test.Result) {
                    Switch ($Test.Result)
                    {
                        'SUCCEED'
                        {
                            $Output = Get-ProgramFrame -B64InputScript $Test.B64InputScript -ApartmentType $Test.ApartmentType -NoConsole $Test.NoConsole
                            $Output | Should BeOfType System.String
                        }
                        'THROW'
                        {
                            {Get-ProgramFrame -B64InputScript $Test.B64InputScript -ApartmentType $Test.ApartmentType -NoConsole $Test.NoConsole} | Should throw
                        }
                    }
                }
            }
        }
    }
    Describe "Get-AssemblyLocation Unit Tests" {
        $RequiredAssemblies = @()
		$RequiredAssemblies += New-Object -typename psobject -property @{ 'Name' = "System.dll"; 'String' = "System, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089"; "NoConsole" = $false; "Required" =$true }
		$RequiredAssemblies += New-Object -typename psobject -property @{ 'Name' = "Microsoft.PowerShell.ConsoleHost.dll"; 'String' = "Microsoft.PowerShell.ConsoleHost, Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35"; "NoConsole" = $false; "Required" = $true }
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
	Describe "Convert-ScriptToBase64String Unit Tests" {
        $ScriptPath = "C:\Windows\setupact.log" # Just need to get past param validation...
        Mock -CommandName Get-Content -MockWith {return "This is a test script"}
        Context 'Parameters Correct' {
            It 'should return a string' {
                $Output = Convert-ScripttoBase64String -ScriptPath $ScriptPath
                $Output | Should BeOfType System.String
            }
        }
        Context "Test Parameter Validation" {
            $ScriptPath = "Badpath"
            It ("Should THROW when Script path is invalid " ) {
                {Convert-ScripttoBase64String -ScriptPath $ScriptPath} | Should throw
            }
        }
    }
}