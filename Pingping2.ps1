Add-Type -AssemblyName System.Windows.Forms 
Add-Type -AssemblyName System.Windows.Forms.DataVisualization 

# --- Configuration ---
$global:target1 = "8.8.8.8"
$global:target2 = "1.1.1.1"
$global:discordUrl = "https://discordstatus.com"
$threshold = 50
$maxPoints = 100
$global:isPaused1 = $false
$global:isPaused2 = $false
$global:soundEnabled1 = $true
$global:soundEnabled2 = $true
$global:sizeMode = 1

# --- Logic Initializers ---
$global:pingSender = New-Object System.Net.NetworkInformation.Ping
$global:wc = New-Object System.Net.WebClient

function Reset-Stats1 {
    $global:sent1 = 0; $global:lost1 = 0; $global:min1 = 9999; $global:max1 = 0; $global:totalMs1 = 0; $global:successCount1 = 0
    if ($series1) { $series1.Points.Clear() }
}
function Reset-Stats2 {
    $global:sent2 = 0; $global:lost2 = 0; $global:min2 = 9999; $global:max2 = 0; $global:totalMs2 = 0; $global:successCount2 = 0
    if ($series2) { $series2.Points.Clear() }
}

# --- UI Setup ---
$form = New-Object Windows.Forms.Form
$form.Text = "NetMon Pro Duo"
$form.Size = "450,550"
$form.BackColor = "#1E1E1E"
$form.ForeColor = "White"
$form.FormBorderStyle = "FixedSingle"
$form.TopMost = $true

$layout = New-Object Windows.Forms.TableLayoutPanel
$layout.Dock = "Fill"
$layout.RowCount = 5; $layout.ColumnCount = 1
$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 35))) 
$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 45))) 
$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 45))) 
$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 85))) 
$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100))) 
$form.Controls.Add($layout)

# Hex-based Icons
$icoOn = [char]0xD83D + [char]0xDD0A 
$icoOff = [char]0xD83D + [char]0xDD07 
$checkMark = [char]0x2713
$crossMark = [char]0x2717

# 1. Utility Bar
$utilPanel = New-Object Windows.Forms.Panel
$utilPanel.Dock = "Fill"; $layout.Controls.Add($utilPanel, 0, 0)
$btnSize = New-Object Windows.Forms.Button
$btnSize.Text = "CHANGE SIZE"; $btnSize.SetBounds(5, 5, 100, 25); $btnSize.FlatStyle = "Flat"; $btnSize.BackColor = "#444444"
$btnSize.Add_Click({
    $global:sizeMode = ($global:sizeMode + 1) % 3
    if($global:sizeMode -eq 0) { 
        $form.Size = "350,300"; $layout.RowStyles[1].Height = 0; $layout.RowStyles[2].Height = 0; $layout.RowStyles[3].Height = 50 
    } elseif ($global:sizeMode -eq 1) { 
        $form.Size = "450,550"; $layout.RowStyles[1].Height = 45; $layout.RowStyles[2].Height = 45; $layout.RowStyles[3].Height = 85 
    } else { 
        $form.Size = "900,700"; $layout.RowStyles[1].Height = 45; $layout.RowStyles[2].Height = 45; $layout.RowStyles[3].Height = 85 
    }
})
$utilPanel.Controls.Add($btnSize)

$discordIcon = New-Object Windows.Forms.Label
$discordIcon.Text = "?"; $discordIcon.ForeColor = "Gray"; $discordIcon.Font = New-Object Drawing.Font("Segoe UI Symbol", 12, [Drawing.FontStyle]::Bold)
$discordIcon.SetBounds(115, 5, 25, 25); $utilPanel.Controls.Add($discordIcon)

$discordLabelText = New-Object Windows.Forms.Label
$discordLabelText.Text = "DISCORD"
$discordLabelText.Font = New-Object Drawing.Font("Segoe UI", 7, ([Drawing.FontStyle]::Bold + [Drawing.FontStyle]::Underline))
$discordLabelText.ForeColor = "#AAAAAA"
$discordLabelText.SetBounds(140, 10, 60, 20)
$discordLabelText.Cursor = [System.Windows.Forms.Cursors]::Hand
$discordLabelText.Add_Click({
    $discordLabelText.ForeColor = "#007ACC"
    try { $global:wc.DownloadStringAsync((New-Object System.Uri($global:discordUrl))) } catch {}
    $timerWait = New-Object Windows.Forms.Timer
    $timerWait.Interval = 800
    $timerWait.Add_Tick({ $discordLabelText.ForeColor = "#AAAAAA"; $this.Stop() })
    $timerWait.Start()
})
$utilPanel.Controls.Add($discordLabelText)

# --- Row 1 ---
$p1 = New-Object Windows.Forms.Panel
$p1.Dock = "Fill"; $layout.Controls.Add($p1, 0, 1)
$in1 = New-Object Windows.Forms.TextBox
$in1.Text = $global:target1; $in1.SetBounds(5, 10, 80, 20); $in1.BackColor = "#333333"; $in1.ForeColor = "White"; $p1.Controls.Add($in1)
$bSet1 = New-Object Windows.Forms.Button
$bSet1.Text = "SET"; $bSet1.SetBounds(90, 8, 55, 24); $bSet1.FlatStyle = "Flat"; $bSet1.BackColor = "#007ACC"; $p1.Controls.Add($bSet1)
$bSet1.Add_Click({ $global:target1 = $in1.Text; Reset-Stats1 })
$bPause1 = New-Object Windows.Forms.Button
$bPause1.Text = "PAUSE"; $bPause1.SetBounds(150, 8, 55, 24); $bPause1.FlatStyle = "Flat"; $bPause1.BackColor = "#444444"; $p1.Controls.Add($bPause1)
$bPause1.Add_Click({ $global:isPaused1 = !$global:isPaused1; $this.Text = if($global:isPaused1){"RUN"}else{"PAUSE"} })
$bSnd1 = New-Object Windows.Forms.Button
$bSnd1.Text = $icoOn; $bSnd1.SetBounds(210, 8, 55, 24); $bSnd1.FlatStyle = "Flat"; $bSnd1.BackColor = "#444444"; $bSnd1.Font = New-Object Drawing.Font("Segoe UI Symbol", 10); $p1.Controls.Add($bSnd1)
$bSnd1.Add_Click({ $global:soundEnabled1 = !$global:soundEnabled1; $this.Text = if($global:soundEnabled1){$icoOn}else{$icoOff} })
$bRes1 = New-Object Windows.Forms.Button
$bRes1.Text = "RESET"; $bRes1.SetBounds(270, 8, 55, 24); $bRes1.FlatStyle = "Flat"; $bRes1.BackColor = "#444444"; $p1.Controls.Add($bRes1)
$bRes1.Add_Click({ Reset-Stats1 })

# --- Row 2 ---
$p2 = New-Object Windows.Forms.Panel
$p2.Dock = "Fill"; $layout.Controls.Add($p2, 0, 2)
$in2 = New-Object Windows.Forms.TextBox
$in2.Text = $global:target2; $in2.SetBounds(5, 10, 80, 20); $in2.BackColor = "#333333"; $in2.ForeColor = "White"; $p2.Controls.Add($in2)
$bSet2 = New-Object Windows.Forms.Button
$bSet2.Text = "SET"; $bSet2.SetBounds(90, 8, 55, 24); $bSet2.FlatStyle = "Flat"; $bSet2.BackColor = "#FF4500"; $p2.Controls.Add($bSet2)
$bSet2.Add_Click({ $global:target2 = $in2.Text; Reset-Stats2 })
$bPause2 = New-Object Windows.Forms.Button
$bPause2.Text = "PAUSE"; $bPause2.SetBounds(150, 8, 55, 24); $bPause2.FlatStyle = "Flat"; $bPause2.BackColor = "#444444"; $p2.Controls.Add($bPause2)
$bPause2.Add_Click({ $global:isPaused2 = !$global:isPaused2; $this.Text = if($global:isPaused2){"RUN"}else{"PAUSE"} })
$bSnd2 = New-Object Windows.Forms.Button
$bSnd2.Text = $icoOn; $bSnd2.SetBounds(210, 8, 55, 24); $bSnd2.FlatStyle = "Flat"; $bSnd2.BackColor = "#444444"; $bSnd2.Font = New-Object Drawing.Font("Segoe UI Symbol", 10); $p2.Controls.Add($bSnd2)
$bSnd2.Add_Click({ $global:soundEnabled2 = !$global:soundEnabled2; $this.Text = if($global:soundEnabled2){$icoOn}else{$icoOff} })
$bRes2 = New-Object Windows.Forms.Button
$bRes2.Text = "RESET"; $bRes2.SetBounds(270, 8, 55, 24); $bRes2.FlatStyle = "Flat"; $bRes2.BackColor = "#444444"; $p2.Controls.Add($bRes2)
$bRes2.Add_Click({ Reset-Stats2 })

$statsLabel = New-Object Windows.Forms.Label
$statsLabel.Dock = "Fill"; $statsLabel.TextAlign = "MiddleCenter"; $statsLabel.Font = New-Object Drawing.Font("Segoe UI", 8, [Drawing.FontStyle]::Bold)
$layout.Controls.Add($statsLabel, 0, 3)

$chart = New-Object Windows.Forms.DataVisualization.Charting.Chart
$chart.Dock = "Fill"; $chart.BackColor = "#1E1E1E"
$chartArea = New-Object Windows.Forms.DataVisualization.Charting.ChartArea
$chartArea.BackColor = "#252526"; $chartArea.AxisY.LabelStyle.ForeColor = "White"
$chartArea.AxisX.LabelStyle.Enabled = $false; $chartArea.AxisY.MajorGrid.LineColor = "#333333"
$chart.ChartAreas.Add($chartArea)
$series1 = New-Object Windows.Forms.DataVisualization.Charting.Series
$series1.ChartType = "Line"; $series1.BorderWidth = 2; $series1.Color = "#007ACC"
$chart.Series.Add($series1)
$series2 = New-Object Windows.Forms.DataVisualization.Charting.Series
$series2.ChartType = "Line"; $series2.BorderWidth = 2; $series2.Color = "#FF4500"
$chart.Series.Add($series2)
$layout.Controls.Add($chart, 0, 4)

Reset-Stats1; Reset-Stats2

# --- DISCORD LOGIC CHECK ---
$onWebComplete = {
    param($s, $e)
    try {
        if ($e.Error) { $discordIcon.Text = "?"; $discordIcon.ForeColor = "Orange" }
        elseif ($e.Result -match "All Systems Operational") { 
            $discordIcon.Text = $checkMark; $discordIcon.ForeColor = "LimeGreen" 
        }
        else { 
            $discordIcon.Text = $crossMark; $discordIcon.ForeColor = "Red" 
            if ($global:soundEnabled1 -or $global:soundEnabled2) { [System.Console]::Beep(800, 500) }
        }
    } catch {}
}
$global:wc.Add_DownloadStringCompleted($onWebComplete)

$pingTimer = New-Object Windows.Forms.Timer
$pingTimer.Interval = 500
$pingTimer.Add_Tick({
    $v1 = 0; $v2 = 0
    if (!$global:isPaused1) {
        try {
            $rep1 = $global:pingSender.Send($global:target1, 450)
            $global:sent1++; if ($rep1.Status -eq "Success") {
                $v1 = $rep1.RoundtripTime; $global:successCount1++; $global:totalMs1 += $v1
                if($v1 -lt $global:min1){$global:min1=$v1}; if($v1 -gt $global:max1){$global:max1=$v1}
                if($v1 -gt $threshold -and $global:soundEnabled1){ [System.Console]::Beep(800, 25) }
            } else { $global:lost1++; if($global:soundEnabled1){[System.Console]::Beep(400, 25)} }
        } catch {}
    }
    if (!$global:isPaused2) {
        try {
            $rep2 = $global:pingSender.Send($global:target2, 450)
            $global:sent2++; if ($rep2.Status -eq "Success") {
                $v2 = $rep2.RoundtripTime; $global:successCount2++; $global:totalMs2 += $v2
                if($v2 -lt $global:min2){$global:min2=$v2}; if($v2 -gt $global:max2){$global:max2=$v2}
                if($v2 -gt $threshold -and $global:soundEnabled2){ [System.Console]::Beep(880, 25) }
            } else { $global:lost2++; if($global:soundEnabled2){[System.Console]::Beep(440, 25)} }
        } catch {}
    }
    $series1.Points.AddY($v1); if($series1.Points.Count -gt $maxPoints){$series1.Points.RemoveAt(0)}
    $series2.Points.AddY($v2); if($series2.Points.Count -gt $maxPoints){$series2.Points.RemoveAt(0)}
    
    $peak = 0
    foreach ($pt in $series1.Points) { if($pt.YValues[0] -gt $peak) { $peak = $pt.YValues[0] } }
    foreach ($pt in $series2.Points) { if($pt.YValues[0] -gt $peak) { $peak = $pt.YValues[0] } }
    $chartArea.AxisY.Maximum = if($peak -gt 0){ [math]::Ceiling($peak * 1.2) } else { 10 }
    
    $a1 = if($global:successCount1 -gt 0){[math]::Round($global:totalMs1/$global:successCount1,1)}else{0}
    $a2 = if($global:successCount2 -gt 0){[math]::Round($global:totalMs2/$global:successCount2,1)}else{0}
    $m1 = if($global:min1 -eq 9999){0}else{$global:min1}; $m2 = if($global:min2 -eq 9999){0}else{$global:min2}
    $statsLabel.Text = "BLUE: AVG: $a1 ms | LOW: $m1 ms | HIGH: $global:max1 ms | DROPS: $global:lost1`nORANGE: AVG: $a2 ms | LOW: $m2 ms | HIGH: $global:max2 ms | DROPS: $global:lost2"
})

$discordTimer = New-Object Windows.Forms.Timer
$discordTimer.Interval = 60000
$discordTimer.Add_Tick({ try { $global:wc.DownloadStringAsync((New-Object System.Uri($global:discordUrl))) } catch {} })

$form.Add_Load({ $pingTimer.Start(); $discordTimer.Start(); try { $global:wc.DownloadStringAsync((New-Object System.Uri($global:discordUrl))) } catch {} })
$form.Add_FormClosing({ $global:pingSender.Dispose(); $global:wc.Dispose() })
$form.ShowDialog()
