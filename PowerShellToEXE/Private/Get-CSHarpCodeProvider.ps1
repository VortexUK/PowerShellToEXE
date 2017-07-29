function Get-CSHarpCodeProvider
{
    [OutputType([Microsoft.CSharp.CSharpCodeProvider])]
    PARAM ( )
    BEGIN { }
    PROCESS 
    {
        [System.Reflection.TypeInfo]$type = ('System.Collections.Generic.Dictionary`2') -as "Type"
        $type = $type.MakeGenericType( @( ("System.String" -as "Type"), ("system.string" -as "Type") ) )
        $constructor = [Activator]::CreateInstance($type)
        $null = $constructor.Add("CompilerVersion", "v4.0")
        $CSharpCodeProvider = New-Object -TypeName Microsoft.CSharp.CSharpCodeProvider($constructor)
        return $CSharpCodeProvider
    }
    END { }
}