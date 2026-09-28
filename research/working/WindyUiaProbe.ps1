Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$root = [System.Windows.Automation.AutomationElement]::RootElement
$windows = $root.FindAll([System.Windows.Automation.TreeScope]::Children,[System.Windows.Automation.Condition]::TrueCondition)
for ($i=0; $i -lt $windows.Count; $i++) {
    $window=$windows.Item($i)
    if ($window.Current.Name -notmatch '(?i)Windy') { continue }
    Write-Output ("Windy window: " + $window.Current.Name)
    $condition=[System.Windows.Automation.PropertyCondition]::new([System.Windows.Automation.AutomationElement]::ControlTypeProperty,[System.Windows.Automation.ControlType]::Edit)
    $edits=$window.FindAll([System.Windows.Automation.TreeScope]::Descendants,$condition)
    for ($j=0; $j -lt $edits.Count; $j++) {
        $edit=$edits.Item($j)
        $value=''
        try {$value=$edit.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.Value} catch {}
        Write-Output ("edit name='{0}' value='{1}'" -f $edit.Current.Name,$value)
    }
}
