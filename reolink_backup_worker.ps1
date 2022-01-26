Param([Parameter(Mandatory=$true)][string] $camera_ip,
        [Parameter(Mandatory=$true)][string] $username,
        [Parameter(Mandatory=$true)][string] $password,
        [Parameter(Mandatory=$true)][string] $name,
        [Parameter(Mandatory=$true)][string] $owner,
        [Parameter(Mandatory=$true)][string] $year,
        [Parameter(Mandatory=$true)][string] $month,
        [Parameter(Mandatory=$true)][string] $backup_path,
        [Parameter(Mandatory=$true)][string] $day
)

add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

#A funciton to get a list of files ready to download
function Get-Files{
    Param([Parameter(Mandatory=$true)][string] $url,
         [Parameter(Mandatory=$true)][string] $token,
         [Parameter(Mandatory=$true)][string] $year,
         [Parameter(Mandatory=$true)][string] $month,
         [Parameter(Mandatory=$true)][string] $day
    )

    $body = '[{"cmd": "Search","param": {"Search": {"channel": 0,"onlyStatus": 0,"streamType": "sub","StartTime": {"year": '+$($year)+',"mon": '+$($month)+',"day": '+$($day)+',"hour": 00,"min": 00,"sec": 1},"EndTime": {"year": '+$($year)+',"mon": '+$($month)+',"day": '+$($day)+',"hour": 23,"min": 59,"sec": 59}}}}]'
    $url_search = $url+"Search&token=$($token)"
    try
    {
        $res = Invoke-RestMethod -Uri $url_search -Method POST -Body $body -ErrorAction SilentlyContinue
        if ($res.value.SearchResult.File.Count -lt 1)
        {
            #Why we have no files ?!?! 
            return $false, "There seems to be no files that are ready to be downloaded : "+$res.value.SearchResult.File
        }
        else
        {
            return $true, $res.value.SearchResult.File
        }
    }
    catch 
    {
        #Opps .. Something is wrong .. 
        $message = $_
        return $false, "Message is $message"
    }
}

#Funciton to login to camera and get Token 
function Get-Token{
    Param([Parameter(Mandatory=$true)][string] $url,
         [Parameter(Mandatory=$true)][string] $username,
         [Parameter(Mandatory=$true)][string] $password
    )
    $result = @()
    $url_login = $url+'Login&token=null'
    $body = '[{"cmd":"Login","param":{"User":{"userName":"'+$($username)+'","password":"'+$($password)+'"}}}]'
    try
    {
        $res = Invoke-RestMethod -Uri $url_login -Method POST -Body $body -ErrorAction SilentlyContinue
        if ($res.value.Token.name.Length -gt 3)
        {
            return $true,$res.value.Token.name
        }
        else
        {
            return $false, "Error, Token is not in right format : $($res.value.Token.name)" 
        }
    }
    catch 
    {
        #Opps .. Something is wrong .. 
        $message = $_
        return $false, "Message is $message"
    }
}

#Write Log funciton 
function Write-Log{
    Param([Parameter(Mandatory=$true)][string] $Message,
          [Parameter(Mandatory=$true)][string] $camera_name,
          [Parameter(Mandatory=$false)][string] $level = "Error")
    
    $logfile = "D:\google_drive\backup\Guy\reolink_powershell_scripts\download_playback$($camera_name).log"
    $d = Get-Date -Format "yyyyMMddHHmm"
    $line = "$($d)|$($level)|$Message"
    $line | Out-File -Append -FilePath $logfile 
}


#Start of script: 


#Base Path
$base_path = "$($backup_path)$($owner)\$($name)"

#Base URL
$baseurl = "https://$($camera_ip)/cgi-bin/api.cgi?cmd="

#Login 
$token = Get-Token -url $baseurl -username $username -password $password
if ($token[0] -eq $false)
{
    #We are unable to generate toekn , write and exit 
    Write-Log -Message "Unable to generate token : $($token[1])" -camera_name $camera[3]
    Exit 1
}
else
{
    Write-Log -Message "Received the following token $($token[1])" -level "Debug" -camera_name $camera[3]
}

#wait..
Start-Sleep -Milliseconds 500

#Get list of avilable files 
$files = Get-Files -token $token[1] -day $day -month $month -year $year -url $baseurl

if ($files[0] -eq $false)
{
    #We are unable to get a list of available files , write and exit
    Write-Log -Message "Unable to get a lit of available files" -camera_name $camera[3]
    Exit 2
}
else
{
    Write-Log -Message "Received a list of files " -level "Debug" -camera_name $camera[3]
}

$newday_path="$($base_path)$($year)$($month)$($day)\"
#Create new day path 
If(!(test-path $newday_path))
{
    try
    {
        New-Item -ItemType Directory -Force -Path $newday_path
    }
    catch 
    {
        #What , we are unable to create a simple directory ..
        Write-Log -Message "Error while creating a folder : $_" -camera_name $camera[3]
        Exit 3 
    }
}

$file = $files[1][0]
#Start downloading 
foreach ($file in $files[1])
{
    try
    {
        $title = $file.name
        $output = $title.replace('/','_')
            
        Write-Log -Message "About to download file : $($output)" -level "Info" -camera_name $camera[3]
        $url = $baseurl+"Download&source=$($title)&output=$($title)&token=$($token[1])"

        $path = "$($newday_path)$($output)"
        #Check if file already here ...
        if (!(Test-Path -Path $path -PathType Leaf))
        {
            Invoke-WebRequest -Uri $url -OutFile $path
        }
        #wait until next file .. 
        Start-Sleep -Milliseconds 100 
    }
    catch 
    {
        #We might missed 1 file .. 
        Write-Log -Message "Error downloading or saving a file : $_" -camera_name $camera[3]
    }
}
