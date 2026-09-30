Install-WindowsFeature -Name Web-Server -IncludeManagementTools

Set-Content -Path "C:\inetpub\wwwroot\index.html" -Value "<h1>CloudXeus Dev Web Server - $env:COMPUTERNAME</h1>"
