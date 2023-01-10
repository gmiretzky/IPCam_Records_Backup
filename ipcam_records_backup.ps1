#This is the main function for the playback backup utility 
#Setup some varibles 
param (
    [Parameter(Mandatory=$true)][string]$working_path,
    [Parameter(Mandatory=$true)][string]$configuration_file
)

#start 
#Get configuration from file 
$config = @{}
foreach ($l in (Get-Content "$($working_path)\$($configuration_file)" | Where-Object{$_ -ne "" -and $_ -notlike "#*"}))
{
    $config.Add(($l.split('='))[0].trim(),($l.split('='))[1].trim())
}

#Get a list of cameras 
$cameras = (Get-Content -Path "$($working_path)\$($config.camera_list)" | Where-Object {$_ -ne "" -and $_ -notlike "#*"})

#Start jobs , First we remove old working jobs 
Get-Job | Stop-Job
Get-Job | Remove-Job

$job_counter = 0
#Now, for each day from the configuration , we will check each camera for backups 
foreach ($d in 1..$config.days_to_download)
{
    foreach ($camera in $cameras)
    {
        #get number of working jobs 
        $running_jobs = Get-Job | Where-Object {$_.State -eq "Running"}

        #check to see if we can start another job
        while($running_jobs.count -ge $config.max_jobs){
            Start-Sleep -Seconds $config.jobs_sleep_seconds
            #Check again for free job slot
            $running_jobs = Get-Job | Where-Object {$_.State -eq "Running"}
        }
        
        #Generate the camera array. 
        $c = $camera.split(',')
        #We have a free job slot, lets call the working script 
        $job_counter += 1
        $argum ="$($working_path)\workers\$($c[5])\worker.ps1 -camera_ip $($c[0]) -username $($c[1]) -password $($c[2]) -name $($c[3]) -owner $($c[4]) -day_of_backup $($d) -backup_path " + '"'+"$($config.backup_folder)"+'" -working_path '+'"'+"$($working_path)"+'"'
        Start-Job -Name "ipcamJob$($job_counter)" -ScriptBlock {
           Start-Process pwsh.exe -ArgumentList $Using:argum -Wait
        }
    }
}
