if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type)
{
$certCallback = @"
    using System;
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public class ServerCertificateValidationCallback
    {
        public static void Ignore()
        {
            if(ServicePointManager.ServerCertificateValidationCallback ==null)
            {
                ServicePointManager.ServerCertificateValidationCallback += 
                    delegate
                    (
                        Object obj, 
                        X509Certificate certificate, 
                        X509Chain chain, 
                        SslPolicyErrors errors
                    )
                    {
                        return true;
                    };
            }
        }
    }
"@
    Add-Type $certCallback
 }
[ServerCertificateValidationCallback]::Ignore()

#This is the main function for the playback backup utility 
#Setup some varibles 
$configuration_file=#Add configuration file name
$working_path="" #Add working path 

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
        
        #We have a free job slot, lets call the working script 
        $job_counter += 1
        $backupFolder="$($config.backup_folder)"
        Start-Job -Name "ipcamJob$($job_counter)" -ScriptBlock {
             #Generate the camera array from configuration 
             $c=($using:camera).split(',')
             #Import module
             Import-Module "$($using:working_path)\workers\$($c[5])\worker.ps1" -Force
             #Create new worker 
             $g=[worker]::new($c[0], $c[1], $c[2], $c[3], $c[4], $using:d, $using:backupFolder, "$($using:working_path)")
             #Run backup
             $g.RunBackup()
        }
    }
}
