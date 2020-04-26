. $PSScriptRoot\TrxParser.psm1

Describe 'Get-MsTestResult' {
    It "Given invalid path, should run time exception" {
        {Get-MsTestResult -Path "aaaa"} 
            | Should -Throw "Cannot find test result file in aaaa"
    }
}