<#
  .Synopsis
  Parse .trx file to PsCustomObject

 .Description
  Parse .trx file that generated from MsTest (Visual Studio) into PsCustomObject

 .Parameter Path
  File path of the test result file path. It has to be a .trx file from MsTest.

 .Parameter NameSpace
  String of namespace of the .trx in the file.

 .EXAMPLE
   # Parse the .trx file
   Get-MsTestResult -Path ".\testResult.trx"

 .Example
   # Parse the .trx file with different namespace
   Get-MsTestResult -Path ".\testResult.trx" -NameSpace "http://microsoft.com/schemas/VisualStudio/TeamTest/2020"
#>


function ReadTestResult($Path){
    Write-Debug "Reading $Path and parse as XML"
    [xml]$FileContent = Get-Content -Path $Path
    return $FileContent
}

function ProcessTestResultSummary {
    Write-Debug "Begin processing TestResultSummary tag"
    $TestResultSummary = New-Object -TypeName PsObject
    $TestResultSummary | Add-Member -MemberType NoteProperty -Name TrxFile -Value $Path
    $TestResultSummary | Add-Member -MemberType NoteProperty -Name Outcome -Value $FileContent.TestRun.ResultSummary.outcome
    $TestResultSummary | Add-Member -MemberType NoteProperty -Name Total -Value $FileContent.TestRun.ResultSummary.Counters.total
    $TestResultSummary | Add-Member -MemberType NoteProperty -Name Passed -Value $FileContent.TestRun.ResultSummary.Counters.passed
    $TestResultSummary | Add-Member -MemberType NoteProperty -Name Error -Value $FileContent.TestRun.ResultSummary.Counters.error
    $TestResultSummary | Add-Member -MemberType NoteProperty -Name Failed -Value $FileContent.TestRun.ResultSummary.Counters.failed
    $TestResultSummary | Add-Member -MemberType NoteProperty -Name Timeout -Value $FileContent.TestRun.ResultSummary.Counters.timeout
    $TestResultSummary | Add-Member -MemberType NoteProperty -Name Aborted -Value $FileContent.TestRun.ResultSummary.Counters.aborted
    $TestResultSummary | Add-Member -MemberType NoteProperty -Name Inconclusive -Value $FileContent.TestRun.ResultSummary.Counters.inconclusive
    $TestResultSummary | Add-Member -MemberType NoteProperty -Name PassedButRunAborted -Value $FileContent.TestRun.ResultSummary.Counters.passedButRunAborted
    $TestResultSummary | Add-Member -MemberType NoteProperty -Name NotRunnable -Value $FileContent.TestRun.ResultSummary.Counters.notRunnable
    $TestResultSummary | Add-Member -MemberType NoteProperty -Name NotExecuted -Value $FileContent.TestRun.ResultSummary.Counters.notExecuted
    $TestResultSummary | Add-Member -MemberType NoteProperty -Name Disconnected -Value $FileContent.TestRun.ResultSummary.Counters.disconnected
    $TestResultSummary | Add-Member -MemberType NoteProperty -Name Warning -Value $FileContent.TestRun.ResultSummary.Counters.warning
    $TestResultSummary | Add-Member -MemberType NoteProperty -Name Completed -Value $FileContent.TestRun.ResultSummary.Counters.completed
    $TestResultSummary | Add-Member -MemberType NoteProperty -Name InProgress -Value $FileContent.TestRun.ResultSummary.Counters.inProgress
    $TestResultSummary | Add-Member -MemberType NoteProperty -Name Pending -Value $FileContent.TestRun.ResultSummary.Counters.pending

    return $TestResultSummary
}

function ProcessTestSettings {
    Write-Debug "Begin processing TestSettings tag"
    $TestSettings = New-Object -TypeName PsObject
    $TestSettings | Add-Member -MemberType NoteProperty -Name Name -Value $FileContent.TestRun.TestSettings.name
    $TestSettings | Add-Member -MemberType NoteProperty -Name Id $FileContent.TestRun.TestSettings.id
    $TestSettings | Add-Member -MemberType NoteProperty -Name Description $FileContent.TestRun.TestSettings.Description

    return $TestSettings
}
function ProcessTestTimes {
    Write-Debug "Begin processing Times tag"
    $TestTimes = New-Object -TypeName PsObject

    $StartTime = [datetime]::ParseExact($FileContent.TestRun.Times.start, "yyyy-MM-ddTHH:mm:ss.FFFFFFFK", $null)
    $EndTime = [datetime]::ParseExact($FileContent.TestRun.Times.finish, "yyyy-MM-ddTHH:mm:ss.FFFFFFFK", $null)

    $TestTimes | Add-Member -MemberType NoteProperty -Name StartTime -Value $StartTime
    $TestTimes | Add-Member -MemberType NoteProperty -Name EndTime -Value $EndTime
    $TestTimes | Add-Member -MemberType NoteProperty -Name ElapsedTime -Value ($EndTime - $StartTime)

    return $TestTimes
}

function ProcessFailedTests {
    # Failed test
    Write-Debug "Begin processing failed test..."
    $FailedTests = @()
    foreach($UnitTestResult in $FileContent.SelectNodes('//ns:UnitTestResult[@outcome="Failed"]', $ns)) {
        $FailedTest = New-Object -TypeName PsObject

        $FailedTest | Add-Member -MemberType NoteProperty -Name ExecutionId -Value $UnitTestResult.executionId
        $FailedTest | Add-Member -MemberType NoteProperty -Name Message -Value $UnitTestResult.Output.ErrorInfo.Message
        $FailedTest | Add-Member -MemberType NoteProperty -Name StackTrace -Value $UnitTestResult.Output.ErrorInfo.StackTrace

        $CompleteStackTrace = $UnitTestResult.Output.ErrorInfo.Message + "`n" + $UnitTestResult.Output.ErrorInfo.StackTrace
        $FailedTest | Add-Member -MemberType NoteProperty -Name CompleteStackTrace -Value $CompleteStackTrace

        $FailedTests += ,@($FailedTest)
    }

    Write-Debug "Match with unit test definition..."
    foreach($FailedTest in $FailedTests){
        $XPath = "//ns:UnitTest/ns:Execution[@id='" + $FailedTest.ExecutionId + "']"
        $TestDefinition = $FileContent.SelectNodes($XPath, $ns)
        $CodeBase = $TestDefinition.NextSibling.codeBase
        $TestName = $TestDefinition.NextSibling.name

        $FailedTest | Add-Member -MemberType NoteProperty -Name CodeBase -Value $CodeBase
        $FailedTest | Add-Member -MemberType NoteProperty -Name TestName -Value $TestName
    }

    return $FailedTests
}

function ProcessNotFailedTest {
    Write-Debug "Begin processing non-failed test..."
    # All test result
    $Results = @()
    foreach($UnitTestResult in $FileContent.SelectNodes('//ns:UnitTestResult[@outcome!="Failed"]', $ns)) {
        $Result = New-Object -TypeName PsObject

        $Result | Add-Member -MemberType NoteProperty -Name ExecutionId -Value $UnitTestResult.executionId
        $Result | Add-Member -MemberType NoteProperty -Name TestName -Value $UnitTestResult.testName
        $Result | Add-Member -MemberType NoteProperty -Name Duration -Value $UnitTestResult.duration
        $Result | Add-Member -MemberType NoteProperty -Name Outcome -Value $UnitTestResult.outcome

        $Results += ,@($Result)
    }

    return $Results
}

function ProcessTestResult($FileContent){
    Write-Debug "Build MsTestResult object..."
    $ns = new-object Xml.XmlNamespaceManager $FileContent.NameTable
    $ns.AddNamespace("ns", $NameSpace)

    return @{
        TestSettings = ProcessTestSettings
        TestTimes = ProcessTestTimes
        TestResultSummary = ProcessTestResultSummary
        FailedTests = ProcessFailedTests
        NonFailedTests = ProcessNotFailedTest
    }
}

function Get-MsTestResult {
    <#
    .Synopsis
    Parse .trx file to PsCustomObject

    .Description
    Parse .trx file that generated from MsTest (Visual Studio) into PsCustomObject

    .Parameter Path
    File path of the test result file path. It has to be a .trx file from MsTest.

    .Parameter NameSpace
    String of namespace of the .trx in the file.

    .EXAMPLE
    # Parse the .trx file
    Get-MsTestResult -Path ".\testResult.trx"

    .Example
    # Parse the .trx file with different namespace
    Get-MsTestResult -Path ".\testResult.trx" -NameSpace "http://microsoft.com/schemas/VisualStudio/TeamTest/2020"
    #>

    param(
        [string]
        [alias('p')]
        [Parameter(Position=0,mandatory=$true)]
        $Path,

        [string]
        [alias('ns')]
        [Parameter(Position=1,mandatory=$false)]
        $NameSpace = "http://microsoft.com/schemas/VisualStudio/TeamTest/2010"
    )

    if ((Test-Path -Path $Path) -ne "True"){
        throw "Cannot find test result file in $Path"
    }

    Write-Debug "Using $Path as the file to be read."
    $FileContent = ReadTestResult($Path)
    Write-Debug "File has been read. Processing the file content..."
    ProcessTestResult($FileContent)
}

Export-ModuleMember -Function Get-MsTestResult