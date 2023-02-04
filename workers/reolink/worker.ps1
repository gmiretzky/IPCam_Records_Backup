Class worker {
#region Class parameters 
    [string] $camera_ip
    [string] $username
    [string] $password
    [string] $name
    [string] $owner
    [int] $day_of_backup
    [string] $backup_path
    [string] $working_path
#endregion
    
#region constructor function     
    worker ([string]$t_camera_ip,[string]$t_username,[string]$t_password,[string]$t_name,[string]$t_owner,[int]$t_day_of_backup,[string]$t_backup_path,[string]$t_working_path) {
        
        $this.camera_ip=$t_camera_ip
        $this.username=$t_username
        $this.password=$t_password
        $this.name=$t_name
        $this.owner=$t_owner
        $this.day_of_backup=$t_day_of_backup
        $this.backup_path=$t_backup_path
        $this.working_path=$t_working_path
    }

#endregion 

#region WriteLog function 
    WriteLog([string]$Message, [string]$camera_name){    
        $level="Error"
        $logfile = "$($this.working_path)\logs\download_playback_$($camera_name).log"
        $d = Get-Date -Format "yyyyMMddHHmm"
        $line = "$($d)|$($level)|$Message"
        $line | Out-File -Append -FilePath $logfile 
    }
#endregion

#region GetFiles function     
    [Array]GetFiles([string]$url,[string]$token,[string]$year,[string]$month,[string]$day){
        $body = '[{"cmd": "Search","param": {"Search": {"channel": 0,"onlyStatus": 0,"streamType": "sub","StartTime": {"year": '+$($year)+',"mon": '+$($month)+',"day": '+$($day)+',"hour": 0,"min": 0,"sec": 1},"EndTime": {"year": '+$($year)+',"mon": '+$($month)+',"day": '+$($day)+',"hour": 23,"min": 59,"sec": 59}}}}]'
        $url_search = $url+"Search&token=$($token)"
        try
        {
            $res = Invoke-RestMethod -Uri $url_search -Method POST -Body $body -ErrorAction SilentlyContinue -SkipCertificateCheck
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
#endregion

#region GetToken function 
    [Array]GetToken([string]$url,[string]$username,[string]$password){
        $url_login = $url+'Login&token=null'
        $body = '[{"cmd":"Login","param":{"User":{"userName":"'+$($username)+'","password":"'+$($password)+'"}}}]'
        try
        {
            $res = Invoke-RestMethod -Uri $url_login -Method POST -Body $body -ErrorAction SilentlyContinue -SkipCertificateCheck 
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
#endregion

#region main function to start backup 
    RunBackup() {
        #Start of script: 
        #Base Path
        $base_path = "$($this.backup_path)\$($this.owner)\$($this.name)"

        #Base URL
        $baseurl = "https://$($this.camera_ip)/cgi-bin/api.cgi?cmd="

        #Initial day of backup parameters
        $year = ((Get-Date).AddDays($this.day_of_backup*(-1))).Year
        $month = ((Get-Date).AddDays(($this.day_of_backup*-1))).Month
        $day = ((Get-Date).AddDays(($this.day_of_backup*-1))).Day

        #Login 
        $token = $this.GetToken($baseurl,$this.username,$this.password)
        if ($token[0] -eq $false)
        {
            #We are unable to generate toekn , write and exit 
            $this.WriteLog("Unable to generate token" ,$this.name)
            Exit 1
        }
        else
        {
            $this.WriteLog("Received the following token $token",$this.name)
        }


        #wait..
        Start-Sleep -Milliseconds 500

        #Get list of avilable files 
        $files = $this.GetFiles($baseurl, $token[1],$year, $month, $day)

        if ($files[0] -eq $false)
        {
            #We are unable to get a list of available files , write and exit
            $this.WriteLog("Unable to get a list of available files" ,$this.name)
            Exit 2
        }
        else
        {
            $this.WriteLog("Received a list of files ",$this.name)
        }

        $newday_path="$($base_path)\$($year)$($month)$($day)\"
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
                $this.WriteLog("Error while creating a folder : $_", $this.name)
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
            
                $this.WriteLog("About to download file : $($output)", $this.name)
                $url = $baseurl+"Download&source=$($title)&output=$($title)&token=$($token[1])"

                $path = "$($newday_path)$($output)"
                $this.WriteLog("Going to save file in $path", $this.name)
                #Check if file already here ...
                if (!(Test-Path -Path $path -PathType Leaf))
                {
                    Invoke-WebRequest -Uri $url -OutFile $path -SkipCertificateCheck 
                }
                #wait until next file .. 
                Start-Sleep -Milliseconds 100 
            }
            catch 
            {
                #We might missed 1 file .. 
                $this.WriteLog("Error downloading or saving a file : $_" , $this.name)
                start-sleep -Seconds 10
            }
        }
    }
#endregion
}
