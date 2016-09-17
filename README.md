# PowerShell

Misc scripts to interact with TFS REST API, deploy SSIS projects, set IIS properties, upload logs to FTP site, etc.

### AggregateTFSCodeCoverageResults.ps1

Script to aggregate TFS 2015 build code coverage results for specified build definition.
SSRS reports do not work with new web-based build system (non XAML) to provide this info as of Update 2. 

### UpdateTFSWorkItemsWithBuildLink.ps1

Adds build link to associated work items.
Runs as the last step in TFS 2015 web-based (non XAML) build definitions. 

### GetCommitAssociatedToBuild.ps1

Gets Git commit hash from last successful build from specified TFS build defintion, returns value in variable to be used in other build steps.

### SSISDeploy.ps1
Script to deploy SSIS package (ISPAC) 

### SetIISPropertiesForFasterStartup.ps1
Sets IIS properties for faster load times.

### RegisterGACAssemblies.ps1
UnRegisters/Registers list of assemblies to GAC.

### UndeliverableMessageExport.ps1

This script uses ExportOSCEXOEmailMessage PowerShell module (in addition to the Exchange Web API) to connect to the O365 X mailbox, 
search for emails according to X criteria during the last week, exports them, 
filters the emails for email addresses and saves them to undeliverableEmailList.txt, then sends email with attachment
