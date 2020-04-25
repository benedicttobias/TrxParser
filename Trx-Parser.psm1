<#
 .Synopsis
  Displays a visual representation of a calendar.

 .Description
  Displays a visual representation of a calendar. This function supports multiple months
  and lets you highlight specific date ranges or days.

 .Parameter Start
  The first month to display.

 .Parameter End
  The last month to display.

 .Parameter FirstDayOfWeek
  The day of the month on which the week begins.

 .Parameter HighlightDay
  Specific days (numbered) to highlight. Used for date ranges like (25..31).
  Date ranges are specified by the Windows PowerShell range syntax. These dates are
  enclosed in square brackets.

 .Parameter HighlightDate
  Specific days (named) to highlight. These dates are surrounded by asterisks.

 .Example
   # Show a default display of this month.
   Show-Calendar

 .Example
   # Display a date range.
   Show-Calendar -Start "March, 2010" -End "May, 2010"

 .Example
   # Highlight a range of days.
   Show-Calendar -HighlightDay (1..10 + 22) -HighlightDate "December 25, 2008"
#>


function ReadTestResult($TestResultFilePath){
    [xml]$FileContent = Get-Content -Path $TestResultFilePath
    return $FileContent
}

function ProcessTestResultSummary {
    $TestResultSummary = New-Object -TypeName PsObject    
    $TestResultSummary | Add-Member -MemberType NoteProperty -Name TrxFile -Value $TestResultFilePath
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
    $TestSettings = New-Object -TypeName PsObject    
    $TestSettings | Add-Member -MemberType NoteProperty -Name Name -Value $FileContent.TestRun.TestSettings.name
    $TestSettings | Add-Member -MemberType NoteProperty -Name Id $FileContent.TestRun.TestSettings.id
    $TestSettings | Add-Member -MemberType NoteProperty -Name Description $FileContent.TestRun.TestSettings.Description

    return $TestSettings
}
function ProcessTestTimes {
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
 
    Write-Verbose "Match with unit test definition"
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
    # All test parser
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



function Get-TestResult {
    param(
        [string]
        [alias('p')]
        $TestResultFilePath,

        [string]
        [alias('ns')]
        $NameSpace = "http://microsoft.com/schemas/VisualStudio/TeamTest/2010"
    )

    Write-Verbose "I found that $TestResultFilePath to be the last file being written. I am going to use this."
    $FileContent = ReadTestResult($TestResultFilePath)
    return ProcessTestResult($FileContent)
}

Export-ModuleMember -Function Get-TestResult
