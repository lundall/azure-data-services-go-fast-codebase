
function SetServiceName($RootElement)
{
    $PostFixHash = [Environment]::GetEnvironmentVariable(($RootElement + "_ApplyNamePostFix"))
    $Value = [Environment]::GetEnvironmentVariable(($RootElement + "_Name"))
    if ($PostFixHash -eq "True")
    {
        $Value = $Value #+  $env:AdsOpts_CD_ResourceGroup_Hash
    }
    PersistEnvVariable -Name ($RootElement + "_Name") -Value $Value
}

function PersistEnvVariable($Name, $Value)
{
    Write-Host "Writing $Name to env file"
    echo "$Name=$Value" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
    #Also Push Variables to the Session Env Variables for local testing
    [Environment]::SetEnvironmentVariable($Name, "$Value")

}


function ParseEnvFragment([object]$Json, [string]$NamePrefix)
{   
    $Json
    foreach($p in ($Json.psobject.properties.where({$_.MemberType -eq "NoteProperty"})))
    { 
        $Name = $p.Name
        Write-Host "Parsing $($Name)"
        if($NamePrefix -ne "")
        {
            Write-Host "Prefix is $NamePrefix"
            $Name =  $NamePrefix + "_" + $p.Name
        } 
        $Value =  $p.Value   
        if($p.TypeNameOfValue -ne "System.Management.Automation.PSCustomObject")
        {

            PersistEnvVariable -Name $Name -Value $Value

            ##Push Variables to the GitHub Actions Compatible Store
            #Write-Host "Writing $Name to env file"
            #Write-Host $p.TypeNameOfValue
            #echo "$Name=$Value" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
            ##Also Push Variables to the Session Env Variables for local testing
            #[Environment]::SetEnvironmentVariable($Name, "$Value")
        }
        else {
            Write-Host "Further Parsing of $Name required"
            $JsonString = $p.Value #| ConvertTo-Json
            ParseEnvFragment -Json $JsonString -NamePrefix $Name
        }
    }
}


function ParseEnvFile ($EnvFile)
{
    if ($null -eq $Env:GITHUB_ENV) 
    {
        [Environment]::SetEnvironmentVariable("GITHUB_ENV","..\bin\GitEnv.txt")
        $FileNameOnly = Split-Path $env:GITHUB_ENV -leaf
        $PathOnly =  Split-Path $env:GITHUB_ENV
        if ((Test-Path $env:GITHUB_ENV))
        {      
        #    Remove-Item -Path $env:GITHUB_ENV
        }
        else 
        {
        
            New-Item -Path $PathOnly -Name $FileNameOnly -type "file" -value ""
        }
        
    }

    $Json = Get-Content -Path "..\environments\$($EnvFile).json"  | ConvertFrom-Json
    ParseEnvFragment -Json $Json -NamePrefix ""

    ParseSecretsFile ($SecretFile)

}

function ParseSecretsFile ($SecretFile)
{

    $Json = Get-Content -Path "..\bin\Secrets.json"  | ConvertFrom-Json
    ParseEnvFragment -Json $Json -NamePrefix "secrets"

}