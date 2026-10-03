#requires -Version 5.1
# TagClip for Windows —— 把文件/文件夹路径绑定成标签，点击即复制到剪贴板（CF_HDROP），
# 在微信 / QQ / 邮件里 Ctrl+V 就能当附件发送。
# 零依赖：Windows 10/11 自带的 Windows PowerShell 5.1 即可运行。

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

$ErrorActionPreference = 'Stop'

$script:DataDir  = Join-Path $env:APPDATA 'TagClip'
$script:DataFile = Join-Path $script:DataDir 'tags.json'
if (-not (Test-Path -LiteralPath $script:DataDir)) {
    New-Item -ItemType Directory -Path $script:DataDir -Force | Out-Null
}
$script:Tags  = @()
$script:Timers = New-Object System.Collections.ArrayList

function Get-Paths($tag) {
    if ($null -eq $tag) { return @() }
    return @($tag.filePaths | Where-Object { $null -ne $_ -and "$_" -ne '' } | ForEach-Object { [string]$_ })
}

function Load-Tags {
    $script:Tags = @()
    if (-not (Test-Path -LiteralPath $script:DataFile)) { return }
    try {
        $raw = Get-Content -LiteralPath $script:DataFile -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) { return }
        $obj = ConvertFrom-Json $raw
        if ($obj -is [System.Array]) { $items = $obj }
        elseif ($obj.PSObject.Properties['tags']) { $items = $obj.tags }
        else { $items = $obj }

        $out = New-Object System.Collections.ArrayList
        foreach ($t in @($items)) {
            if ($null -eq $t) { continue }
            $paths = @($t.filePaths | Where-Object { $null -ne $_ -and "$_" -ne '' } | ForEach-Object { [string]$_ })
            [void]$out.Add([PSCustomObject]@{
                id        = [string]$t.id
                name      = [string]$t.name
                filePaths = $paths
            })
        }
        $script:Tags = @($out)
    } catch {
        $script:Tags = @()
    }
}

function Save-Tags {
    if (@($script:Tags).Count -eq 0) {
        $json = '{ "version": 1, "tags": [] }'
    } else {
        $json = ConvertTo-Json -InputObject @{ version = 1; tags = @($script:Tags) } -Depth 6
    }
    Set-Content -LiteralPath $script:DataFile -Value $json -Encoding UTF8
}

function Export-Data {
    $sfd = New-Object System.Windows.Forms.SaveFileDialog
    $sfd.Title = '导出标签数据'
    $sfd.Filter = 'JSON 文件 (*.json)|*.json'
    $sfd.FileName = "TagClip-tags-$((Get-Date).ToString('yyyyMMdd')).json"
    if ($sfd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    try {
        if (@($script:Tags).Count -eq 0) {
            $json = '{ "version": 1, "tags": [] }'
        } else {
            $json = ConvertTo-Json -InputObject @{ version = 1; tags = @($script:Tags) } -Depth 6
        }
        Set-Content -LiteralPath $sfd.FileName -Value $json -Encoding UTF8
        [System.Windows.Forms.MessageBox]::Show("已导出 $(@($script:Tags).Count) 个标签。", 'TagClip') | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show("导出失败：$($_.Exception.Message)", 'TagClip', 'OK', 'Error') | Out-Null
    }
}

function Import-Data {
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Title = '导入标签数据'
    $ofd.Filter = 'JSON 文件 (*.json)|*.json'
    $ofd.Multiselect = $false
    if ($ofd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    try {
        $raw = Get-Content -LiteralPath $ofd.FileName -Raw -Encoding UTF8
        $obj = ConvertFrom-Json $raw
        if ($obj -is [System.Array]) { $items = $obj }
        elseif ($obj.PSObject.Properties['tags']) { $items = $obj.tags }
        else { $items = $obj }

        $out = New-Object System.Collections.ArrayList
        foreach ($t in @($items)) {
            if ($null -eq $t) { continue }
            $paths = @($t.filePaths | Where-Object { $null -ne $_ -and "$_" -ne '' } | ForEach-Object { [string]$_ })
            [void]$out.Add([PSCustomObject]@{
                id        = [string]$t.id
                name      = [string]$t.name
                filePaths = $paths
            })
        }
        $script:Tags = @($out)
        Save-Tags
        Update-List
        [System.Windows.Forms.MessageBox]::Show("导入成功，共 $(@($script:Tags).Count) 个标签。`r`n（已覆盖当前数据）", 'TagClip') | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show("导入失败：文件格式无法识别。`r`n$($_.Exception.Message)", 'TagClip', 'OK', 'Error') | Out-Null
    }
}

function Add-Tag($name, $paths) {
    $script:Tags += [PSCustomObject]@{
        id        = [guid]::NewGuid().ToString()
        name      = $name
        filePaths = @($paths)
    }
    Save-Tags
    Update-List
}

function Update-Tag($id, $name, $paths) {
    foreach ($t in @($script:Tags)) {
        if ($t.id -eq $id) {
            $t.name = $name
            $t.filePaths = @($paths)
            break
        }
    }
    Save-Tags
    Update-List
}

function Remove-Tag($id) {
    $script:Tags = @($script:Tags | Where-Object { $_.id -ne $id })
    Save-Tags
    Update-List
}

function Copy-TagFiles($tag) {
    $paths = @(Get-Paths $tag | Where-Object { Test-Path -LiteralPath $_ })
    $skipped = @(Get-Paths $tag).Count - $paths.Count
    if ($paths.Count -eq 0) {
        [System.Media.SystemSounds]::Beep.Play()
        [System.Windows.Forms.MessageBox]::Show("标签「$($tag.name)」绑定的文件都不存在了。`r`n请编辑标签重新绑定，或检查文件是否被移动 / 删除。", 'TagClip') | Out-Null
        return
    }
    $col = New-Object System.Collections.Specialized.StringCollection
    foreach ($p in $paths) { [void]$col.Add($p) }
    # 剪贴板可能被别的进程占用，短暂重试
    for ($i = 0; $i -lt 5; $i++) {
        try {
            [System.Windows.Forms.Clipboard]::SetFileDropList($col)
            if ($skipped -gt 0) {
                [System.Windows.Forms.MessageBox]::Show("已复制 $($paths.Count) 个文件，$skipped 个文件不存在已被跳过。`r`n可在聊天窗口直接 Ctrl+V 发送。", 'TagClip') | Out-Null
            } else {
                [System.Media.SystemSounds]::Asterisk.Play()
            }
            return
        } catch {
            Start-Sleep -Milliseconds 80
        }
    }
    [System.Windows.Forms.MessageBox]::Show('复制到剪贴板失败，请重试。', 'TagClip') | Out-Null
}

function Start-CardFlash($card) {
    if ($null -eq $card) { return }
    $card.BackColor = [System.Drawing.Color]::FromArgb(219, 234, 254)
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1200
    $timer.Add_Tick({
        $card.BackColor = [System.Drawing.Color]::White
        $this.Stop()
        $this.Dispose()
    }.GetNewClosure())
    [void]$script:Timers.Add($timer)
    $timer.Start()
}

function Show-Editor($tag) {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = if ($null -ne $tag) { '编辑标签' } else { '新建标签' }
    $dlg.Size = New-Object System.Drawing.Size(560, 470)
    $dlg.StartPosition = 'CenterParent'
    $dlg.FormBorderStyle = 'FixedDialog'
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false
    $dlg.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)

    $lblName = New-Object System.Windows.Forms.Label
    $lblName.Text = '标签名称'
    $lblName.Location = New-Object System.Drawing.Point(18, 16)
    $lblName.AutoSize = $true
    [void]$dlg.Controls.Add($lblName)

    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Location = New-Object System.Drawing.Point(18, 40)
    $txt.Size = New-Object System.Drawing.Size(506, 26)
    if ($null -ne $tag) { $txt.Text = [string]$tag.name }
    [void]$dlg.Controls.Add($txt)

    $lblFiles = New-Object System.Windows.Forms.Label
    $lblFiles.Location = New-Object System.Drawing.Point(18, 78)
    $lblFiles.AutoSize = $true
    [void]$dlg.Controls.Add($lblFiles)

    $lst = New-Object System.Windows.Forms.ListBox
    $lst.Location = New-Object System.Drawing.Point(18, 102)
    $lst.Size = New-Object System.Drawing.Size(506, 250)
    $lst.SelectionMode = 'MultiExtended'
    $lst.HorizontalScrollbar = $true
    [void]$dlg.Controls.Add($lst)

    $files = New-Object System.Collections.ArrayList
    if ($null -ne $tag) {
        foreach ($p in (Get-Paths $tag)) { [void]$files.Add($p) }
    }

    $refresh = {
        $lst.Items.Clear()
        foreach ($p in $files) {
            $leaf = Split-Path -Leaf $p
            [void]$lst.Items.Add("$leaf    —    $p")
        }
        $lblFiles.Text = "绑定的文件（$($files.Count) 个）"
    }.GetNewClosure()

    $btnAdd = New-Object System.Windows.Forms.Button
    $btnAdd.Text = '添加文件'
    $btnAdd.Location = New-Object System.Drawing.Point(18, 362)
    $btnAdd.Size = New-Object System.Drawing.Size(90, 30)
    $btnAdd.Add_Click({
        $ofd = New-Object System.Windows.Forms.OpenFileDialog
        $ofd.Multiselect = $true
        $ofd.Title = '选择要绑定到这个标签的文件'
        if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            foreach ($f in $ofd.FileNames) {
                if (-not $files.Contains($f)) { [void]$files.Add($f) }
            }
            & $refresh
        }
    }.GetNewClosure())
    [void]$dlg.Controls.Add($btnAdd)

    $btnDir = New-Object System.Windows.Forms.Button
    $btnDir.Text = '添加文件夹'
    $btnDir.Location = New-Object System.Drawing.Point(116, 362)
    $btnDir.Size = New-Object System.Drawing.Size(100, 30)
    $btnDir.Add_Click({
        $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
        $fbd.Description = '选择要绑定到这个标签的文件夹'
        if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            if (-not $files.Contains($fbd.SelectedPath)) { [void]$files.Add($fbd.SelectedPath) }
            & $refresh
        }
    }.GetNewClosure())
    [void]$dlg.Controls.Add($btnDir)

    $btnRemove = New-Object System.Windows.Forms.Button
    $btnRemove.Text = '移除选中'
    $btnRemove.Location = New-Object System.Drawing.Point(224, 362)
    $btnRemove.Size = New-Object System.Drawing.Size(90, 30)
    $btnRemove.Add_Click({
        $idxs = @($lst.SelectedIndices) | Sort-Object -Descending
        foreach ($i in $idxs) { $files.RemoveAt($i) }
        & $refresh
    }.GetNewClosure())
    [void]$dlg.Controls.Add($btnRemove)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = '取消'
    $btnCancel.Location = New-Object System.Drawing.Point(334, 362)
    $btnCancel.Size = New-Object System.Drawing.Size(88, 30)
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    [void]$dlg.Controls.Add($btnCancel)

    $btnSave = New-Object System.Windows.Forms.Button
    $btnSave.Text = '保存'
    $btnSave.Location = New-Object System.Drawing.Point(430, 362)
    $btnSave.Size = New-Object System.Drawing.Size(94, 30)
    $btnSave.Add_Click({
        $name = $txt.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($name)) {
            [System.Windows.Forms.MessageBox]::Show('请填写标签名称。', 'TagClip') | Out-Null
            return
        }
        if ($null -ne $tag) {
            Update-Tag $tag.id $name @($files)
        } else {
            Add-Tag $name @($files)
        }
        $dlg.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $dlg.Close()
    }.GetNewClosure())
    [void]$dlg.Controls.Add($btnSave)

    $dlg.AcceptButton = $btnSave
    $dlg.CancelButton = $btnCancel

    & $refresh
    [void]$dlg.ShowDialog()
    $dlg.Dispose()
}

function Update-List {
    $script:Flow.Controls.Clear()

    if (@($script:Tags).Count -eq 0) {
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = "还没有标签`r`n`r`n点击左上角「＋ 新建标签」，绑定你要发送的文件。`r`n之后在聊天窗口里 Ctrl+V 即可当附件发送。"
        $lbl.TextAlign = 'MiddleCenter'
        $lbl.ForeColor = [System.Drawing.Color]::Gray
        $lbl.AutoSize = $false
        $lbl.Size = New-Object System.Drawing.Size(($script:Flow.ClientSize.Width - 40), 220)
        $lbl.Margin = New-Object System.Windows.Forms.Padding(20, 60, 20, 20)
        [void]$script:Flow.Controls.Add($lbl)
        return
    }

    foreach ($tag in @($script:Tags)) {
        $card = New-Object System.Windows.Forms.Panel
        $card.Size = New-Object System.Drawing.Size(200, 92)
        $card.Margin = New-Object System.Windows.Forms.Padding(8)
        $card.BackColor = [System.Drawing.Color]::White
        $card.BorderStyle = 'FixedSingle'
        $card.Cursor = [System.Windows.Forms.Cursors]::Hand

        $paths = Get-Paths $tag

        $title = New-Object System.Windows.Forms.Label
        $title.Text = [string]$tag.name
        $title.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10, [System.Drawing.FontStyle]::Bold)
        $title.Location = New-Object System.Drawing.Point(12, 12)
        $title.AutoSize = $false
        $title.Size = New-Object System.Drawing.Size(176, 22)
        $title.AutoEllipsis = $true
        $title.Cursor = [System.Windows.Forms.Cursors]::Hand

        $sub = New-Object System.Windows.Forms.Label
        if ($paths.Count -eq 0) { $sub.Text = '未绑定文件' } else { $sub.Text = "$($paths.Count) 个文件" }
        $sub.ForeColor = [System.Drawing.Color]::Gray
        $sub.Location = New-Object System.Drawing.Point(12, 38)
        $sub.AutoSize = $true
        $sub.Cursor = [System.Windows.Forms.Cursors]::Hand

        $hint = New-Object System.Windows.Forms.Label
        $hint.Text = '点击复制'
        $hint.ForeColor = [System.Drawing.Color]::FromArgb(150, 150, 150)
        $hint.Location = New-Object System.Drawing.Point(12, 62)
        $hint.AutoSize = $true
        $hint.Cursor = [System.Windows.Forms.Cursors]::Hand

        [void]$card.Controls.Add($title)
        [void]$card.Controls.Add($sub)
        [void]$card.Controls.Add($hint)

        $click = {
            $paths = Get-Paths $tag
            if ($paths.Count -eq 0) {
                [System.Media.SystemSounds]::Beep.Play()
                return
            }
            Copy-TagFiles $tag
            Start-CardFlash $card
        }.GetNewClosure()

        $card.Add_Click($click)
        $title.Add_Click($click)
        $sub.Add_Click($click)
        $hint.Add_Click($click)

        $menu = New-Object System.Windows.Forms.ContextMenuStrip
        $miEdit = $menu.Items.Add('编辑')
        $miEdit.Add_Click({
            Show-Editor $tag
        }.GetNewClosure())
        $miDel = $menu.Items.Add('删除')
        $miDel.Add_Click({
            $r = [System.Windows.Forms.MessageBox]::Show("确定删除标签「$($tag.name)」？", 'TagClip', 'YesNo', 'Question')
            if ($r -eq [System.Windows.Forms.DialogResult]::Yes) { Remove-Tag $tag.id }
        }.GetNewClosure())
        $card.ContextMenuStrip = $menu
        $title.ContextMenuStrip = $menu
        $sub.ContextMenuStrip = $menu
        $hint.ContextMenuStrip = $menu

        [void]$script:Flow.Controls.Add($card)
    }
}

function Show-MainWindow {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'TagClip'
    $form.Size = New-Object System.Drawing.Size(700, 560)
    $form.MinimumSize = New-Object System.Drawing.Size(520, 400)
    $form.StartPosition = 'CenterScreen'
    $form.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
    $form.BackColor = [System.Drawing.Color]::FromArgb(245, 246, 248)

    $bar = New-Object System.Windows.Forms.Panel
    $bar.Dock = 'Top'
    $bar.Height = 52
    $bar.BackColor = [System.Drawing.Color]::White

    $btnNew = New-Object System.Windows.Forms.Button
    $btnNew.Text = '＋ 新建标签'
    $btnNew.Location = New-Object System.Drawing.Point(12, 10)
    $btnNew.Size = New-Object System.Drawing.Size(120, 32)
    $btnNew.Add_Click({ Show-Editor $null })
    [void]$bar.Controls.Add($btnNew)

    $btnExport = New-Object System.Windows.Forms.Button
    $btnExport.Text = '导出'
    $btnExport.Size = New-Object System.Drawing.Size(64, 32)
    $btnExport.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
    $btnExport.Location = New-Object System.Drawing.Point(($form.ClientSize.Width - 148), 10)
    $btnExport.Add_Click({ Export-Data })
    [void]$bar.Controls.Add($btnExport)

    $btnImport = New-Object System.Windows.Forms.Button
    $btnImport.Text = '导入'
    $btnImport.Size = New-Object System.Drawing.Size(64, 32)
    $btnImport.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
    $btnImport.Location = New-Object System.Drawing.Point(($form.ClientSize.Width - 76), 10)
    $btnImport.Add_Click({ Import-Data })
    [void]$bar.Controls.Add($btnImport)

    $tip = New-Object System.Windows.Forms.Label
    $tip.Text = '点击卡片复制文件，在微信 / QQ / 邮件里 Ctrl+V 发送'
    $tip.ForeColor = [System.Drawing.Color]::Gray
    $tip.AutoSize = $true
    $tip.Location = New-Object System.Drawing.Point(140, 18)
    [void]$bar.Controls.Add($tip)

    [void]$form.Controls.Add($bar)

    $script:Flow = New-Object System.Windows.Forms.FlowLayoutPanel
    $script:Flow.Dock = 'Fill'
    $script:Flow.AutoScroll = $true
    $script:Flow.Padding = New-Object System.Windows.Forms.Padding(8)
    $script:Flow.BackColor = [System.Drawing.Color]::FromArgb(245, 246, 248)
    [void]$form.Controls.Add($script:Flow)
    $script:Flow.BringToFront()

    $form.Add_Shown({
        Update-List
        [System.Windows.Forms.Application]::DoEvents()
    })

    [void]$form.ShowDialog()
}

try {
    Load-Tags
    Show-MainWindow
} catch {
    [System.Windows.Forms.MessageBox]::Show("TagClip 启动失败：`r`n`r`n$($_.Exception.Message)", 'TagClip', 'OK', 'Error') | Out-Null
}
