function Get-AssemblyLocation
{
    [OutputType([System.Collections.ArrayList])]
    PARAM
    (
        [parameter(Mandatory=$true,
            Position=0,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
            [ValidateNotNullOrEmpty()]
        [System.Collections.ArrayList]$Assemblies
    )
    BEGIN
    {
        $AssemblyLocations = New-Object -TypeName System.Collections.ArrayList($null)
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
            $Location = $LoadedAssemblies | Where-Object -FilterScript {$_.ManifestModule.Name -eq $Assembly.Name} | Select-Object -First 1 -ExpandProperty Location
            $null = $AssemblyLocations.Add($Location)
        }
        return $AssemblyLocations
    }
    END {}
}