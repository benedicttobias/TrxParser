Import-Module .\TrxParser.psm1 -Force

Describe 'Get-MsTestResult' {
    It 'Given invalid path, should run time exception' {
        {Get-MsTestResult -Path 'aaaa'}
            | Should -Throw 'Cannot find test result file in aaaa'
    }

    It 'Given valid path, but return null content, should run time exception' {
        Mock Test-Path {return  'True'} -ParameterFilter { $Path -eq 'validButEmpty.trx'}
        Mock Get-Content {return  $null} -ParameterFilter { $Path -eq 'validButEmpty.trx'}

        {Get-MsTestResult -Path 'validButEmpty.trx'}
            | Should -Throw 'validButEmpty.trx is null'
    }

    It 'Given valid trx file, should parse test settings correctly' {
        $Result = Get-MsTestResult -Path '.\TestFile.trx'
            
        $Result.TestSettings 
            | Should -Not -BeNullOrEmpty
        
            $Result.TestSettings.Name | Should -Be 'Local'
            $Result.TestSettings.Id | Should -Be '421f36c9-36a2-45c4-80e0-4202d2e75ce0'
            $Result.TestSettings.Description | Should -Be 'These are default test settings for a local test run.'
    }
}