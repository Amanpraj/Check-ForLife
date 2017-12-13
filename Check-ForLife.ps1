# When evaluating if a machine is still connected to a companies network paul asked that I, check DNS for a record, Ping the machine and attempt to connect via 
# RDP. Rhis script will do all of those things and log them. It is a rough, but functional draft. There needs to be a column named machinename in a CSV named
# Machinetemplate.csv in the same folder as the script. All results get output to a CSV in the same fodler the script was run in. 
# Preferably you would run this from a server, but it requires powershell and .net later than the versions shipped with windows server 2012 and windows 8.1

#Some instantiation
$hosts = Import-Csv -Path .\MachineTemplate.CSV;
$results = @();
$startTime = [datetime]::Now
$RDPTest = $null

# This funciton calls System.Net.Sockets.TCPClient on an IP address on port 3389, this fulfills the request to attempt an RDP connection
function Get-RDPConnect ($IPString) {
    try {
        Write-host "Checking RDP Port with System.Net.Sockets.TCPClient to : " $IPString "Port 3389"  -ForegroundColor Yellow;
        #I understand this is a hack, if this throws an exception it will trigger the catch block which will set the rdptest variable to false, meaning the 
        #RDP port was not open.
        [System.Net.Sockets.TCPClient]::new($IPString, "3389");
        [bool]$script:RDPTest = $true;
    }
    catch {
        [bool]$script:RDPTest = $false;
    }
}

# This function gathers information from DNS regarding DNS FQN, DNS TTL, All DNS IP addresses and then logs them in an object.
# It also attempts an RDP connection and Pings, it does this by skipping the local hosts file. 
function Get-ConnectionData ($hostname) {
    try {
        Write-Host "I am checking " $hostname.Machinename " using resolve-DnSname, Bypassing the local hostfile";
        $DNSResults = Resolve-DnsName -Name $hostname.Machinename -QuickTimeout -NoHostsFile
        $DNSResults
        for ($ig = 0; $ig -lt $DNSResults.Count; $ig++) {
            Write-host "Current IP Address: " $DNSResults.IPAddress[$ig];
            $TTL = $DNSResults.TTL[$ig];
            $DNSName = $DNSResults.name[$ig];
            $pingCheck = Test-Connection -ComputerName $DNSResults.IPAddress[$ig] -Quiet -Count 2;
            Write-Host "IPString" $ig "is" $DNSResults.IPAddress[$ig];
            Get-RDPConnect $DNSResults.IPAddress[$ig];
            <# results block #>
            $GoodLoop = New-Object -TypeName psobject;
            # PassThrough Section
            $GoodLoop | Add-Member -NotePropertyName "Ticket" -NotePropertyValue $hostname.Ticket;
            $GoodLoop | Add-Member -NotePropertyName "Company" -NotePropertyValue $hostname.Company;
            $GoodLoop | Add-Member -NotePropertyName "LTID" -NotePropertyValue $hostname.LTID;
            $GoodLoop | Add-Member -NotePropertyName "LastCheckDate" -NotePropertyValue $hostname.LastCheckDate;
            $GoodLoop | Add-Member -NotePropertyName "Site" -NotePropertyValue $hostname.Site;
            $GoodLoop | Add-Member -NotePropertyName "Hostname" -NotePropertyValue $hostname.Machinename;
            $GoodLoop | Add-Member -NotePropertyName "Daysoffline" -NotePropertyValue $hostname.Days;
            # New information Section
            $GoodLoop | Add-Member -NotePropertyName "DNSName" -NotePropertyValue $DNSName;
            $GoodLoop | Add-Member -NotePropertyName "ResolvedIP" -NotePropertyValue $DNSResults.IPAddress[$ig];
            $GoodLoop | Add-Member -NotePropertyName "DNSTTL" -NotePropertyValue $TTL;
            $GoodLoop | Add-Member -NotePropertyName "PingPass" -NotePropertyValue $pingCheck;
            $GoodLoop | Add-Member -NotePropertyName "RDPTest" -NotePropertyValue $RDPTest;
            #Remove-Variable -ScopeScript -Name RDPTest; <- This was a mistake
            $script:results += $GoodLoop;
        }
    }
    catch {
        Write-Host "Something bad Happened in Get-ConnectionData and the catch block was triggered check errors" -ForegroundColor red;
    }
}
Function Test-Machinename ($hostname) {
    $results = @();
    $rdp
    try {
        #This is a hack to cancel the try block before it tries to Resolve-DNSname on a bad name. 
        #This is because I hod trouble triggering the catch Block with a simple error from a cmdlet
        $CatchHack = [System.Net.Dns]::GetHostAddresses($hostname.Machinename); 
        Get-ConnectionData $hostname
    } 
    catch [System.Net.Sockets.SocketException] {
        # If this block is triggered then we can be reasonably sure that the machine isnt connected. Its going to attempt a ping and RDP connect anyways 
        # and return a result.
        Write-Host "You triggered the Catch Block" -ForegroundColor Red;
        Write-Host "failed to find a Record for " $hostname.Machinename -ForegroundColor Red;
        Write-Host "Attempting to Ping Hostname anyways, This may take some time." -ForegroundColor Red;
        $pingCheck = Test-Connection -ComputerName $hostname.Machinename -Quiet -Count 2;
        Write-Host "Attempting to RDP anyways, This may take some time." -ForegroundColor Red;
        Get-RDPConnect $hostname.Machinename;
        #Object creation time
        $BadLoop = New-Object -TypeName psobject;
        # PassThrough Section
        $BadLoop | Add-Member -NotePropertyName "Ticket" -NotePropertyValue $hostname.Ticket;
        $BadLoop | Add-Member -NotePropertyName "Company" -NotePropertyValue $hostname.Company;
        $BadLoop | Add-Member -NotePropertyName "LTID" -NotePropertyValue $hostname.LTID;
        $BadLoop | Add-Member -NotePropertyName "LastCheckDate" -NotePropertyValue $hostname.LastCheckDate;
        $BadLoop | Add-Member -NotePropertyName "Site" -NotePropertyValue $hostname.Site;
        $BadLoop | Add-Member -NotePropertyName "Hostname" -NotePropertyValue $hostname.Machinename;
        $BadLoop | Add-Member -NotePropertyName "Daysoffline" -NotePropertyValue $hostname.Days;
        # New information Section
        $BadLoop | Add-Member -NotePropertyName "DNSName" -NotePropertyValue "NotFound";
        $BadLoop | Add-Member -NotePropertyName "ResolvedIP" -NotePropertyValue "NotFound";
        $BadLoop | Add-Member -NotePropertyName "DNSTTL" -NotePropertyValue "NotFound";
        $BadLoop | Add-Member -NotePropertyName "PingPass" -NotePropertyValue $pingCheck;
        $BadLoop | Add-Member -NotePropertyName "RDPTest" -NotePropertyValue $RDPTest;
        #Remove-Variable -Scope Script -Name RDPTest;
        $script:results += $BadLoop;
    }
}
# this is the loop that runs the funtions
foreach ($name in $hosts) {
    Test-Machinename $name;
}

# This should probably be its own functions?
Write-Host "You triggered the finally Block";
$endTime = [datetime]::Now;
$runTime = $startTime - $endTime;
Write-Host "Start Time: " $startTime -ForegroundColor Green;
Write-Host "End Time: " $endTime -ForegroundColor Green;
Write-Host "Run Time: " $runTime -ForegroundColor Green;
$script:results | Export-Csv .\output.CSV -NoTypeInformation -Force;
