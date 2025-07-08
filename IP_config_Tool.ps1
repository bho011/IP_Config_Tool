Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Adapterliste holen (nur aktive Adapter)
$adapterList = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -ExpandProperty Name

# GUI-Fenster
$form = New-Object System.Windows.Forms.Form
$form.Text = "IP-Konfiguration"
$form.Size = New-Object System.Drawing.Size(460, 480)
$form.StartPosition = "CenterScreen"

# Label: Adapterauswahl
$labelAdapter = New-Object System.Windows.Forms.Label
$labelAdapter.Text = "Netzwerkadapter"
$labelAdapter.Location = New-Object System.Drawing.Point(10, 20)
$labelAdapter.Size = New-Object System.Drawing.Size(130, 20)
$form.Controls.Add($labelAdapter)

# Dropdown-Menü für Adapter
$comboAdapters = New-Object System.Windows.Forms.ComboBox
$comboAdapters.Location = New-Object System.Drawing.Point(150, 20)
$comboAdapters.Size = New-Object System.Drawing.Size(280, 20)
$comboAdapters.DropDownStyle = "DropDownList"
$comboAdapters.Items.AddRange($adapterList)
$form.Controls.Add($comboAdapters)

# Aktuelle IP anzeigen
$labelCurrentIP = New-Object System.Windows.Forms.Label
$labelCurrentIP.Text = "Aktuelle IP:"
$labelCurrentIP.Location = New-Object System.Drawing.Point(10, 50)
$labelCurrentIP.Size = New-Object System.Drawing.Size(420, 20)
$form.Controls.Add($labelCurrentIP)

# Label & Textbox-Felder
$labels = @("IP-Adresse", "Subnetzmaske", "Gateway", "DNS1", "DNS2")
$textboxes = @()

for ($i = 0; $i -lt $labels.Count; $i++) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $labels[$i]
    $label.Location = New-Object System.Drawing.Point(10, (80 + ($i * 40)))
    $label.Size = New-Object System.Drawing.Size(130, 20)
    $form.Controls.Add($label)

    $textbox = New-Object System.Windows.Forms.TextBox
    $textbox.Location = New-Object System.Drawing.Point(150, (80 + ($i * 40)))
    $textbox.Size = New-Object System.Drawing.Size(280, 20)
    $form.Controls.Add($textbox)
    $textboxes += $textbox
}

# Checkbox IPv6
$chkIPv6 = New-Object System.Windows.Forms.CheckBox
$chkIPv6.Text = "Auch IPv6 setzen"
$chkIPv6.Location = New-Object System.Drawing.Point(150, 290)
$chkIPv6.Size = New-Object System.Drawing.Size(150, 20)
$form.Controls.Add($chkIPv6)

# Button: IP setzen
$btnSetIP = New-Object System.Windows.Forms.Button
$btnSetIP.Text = "IP setzen"
$btnSetIP.Location = New-Object System.Drawing.Point(70, 330)
$btnSetIP.Size = New-Object System.Drawing.Size(120, 30)
$btnSetIP.Add_Click({
    $adapter = $comboAdapters.SelectedItem
    $ip = $textboxes[0].Text
    $subnet = $textboxes[1].Text
    $gateway = $textboxes[2].Text
    $dns1 = $textboxes[3].Text
    $dns2 = $textboxes[4].Text

    if ($adapter -and $ip -and $subnet) {
        try {
            netsh interface ip set address name="$adapter" static $ip $subnet $gateway
            if ($dns1) { netsh interface ip set dns name="$adapter" static $dns1 primary }
            if ($dns2) { netsh interface ip add dns name="$adapter" $dns2 index=2 }

            if ($chkIPv6.Checked) {
                netsh interface ipv6 set address interface="$adapter" address=fd00::1
                netsh interface ipv6 set dnsservers interface="$adapter" source=dhcp
            }

            [System.Windows.Forms.MessageBox]::Show("IP-Konfiguration erfolgreich angewendet!", "Erfolg")
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Fehler:`n$_", "Fehler")
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("Bitte IP, Subnetz und Adapter angeben.", "Fehlende Eingaben")
    }
})
$form.Controls.Add($btnSetIP)

# Button: DHCP aktivieren
$btnDHCP = New-Object System.Windows.Forms.Button
$btnDHCP.Text = "DHCP aktivieren"
$btnDHCP.Location = New-Object System.Drawing.Point(220, 330)
$btnDHCP.Size = New-Object System.Drawing.Size(120, 30)
$btnDHCP.Add_Click({
    $adapter = $comboAdapters.SelectedItem
    if ($adapter) {
        try {
            netsh interface ip set address name="$adapter" source=dhcp
            netsh interface ip set dnsservers name="$adapter" source=dhcp
            netsh interface ipv6 set address interface="$adapter" source=dhcp
            [System.Windows.Forms.MessageBox]::Show("DHCP erfolgreich aktiviert.", "Erfolg")
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Fehler beim Setzen von DHCP:`n$_", "Fehler")
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("Bitte einen Adapter auswählen.", "Hinweis")
    }
})
$form.Controls.Add($btnDHCP)

# Adapterwechsel → aktuelle IP anzeigen
$comboAdapters.Add_SelectedIndexChanged({
    $adapter = $comboAdapters.SelectedItem
    if ($adapter) {
        try {
            $ip = (Get-NetIPAddress -InterfaceAlias $adapter -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Where-Object { $_.IPAddress -ne $null }).IPAddress
            $labelCurrentIP.Text = "Aktuelle IP: " + ($ip -join ", ")
        } catch {
            $labelCurrentIP.Text = "Aktuelle IP: (nicht ermittelbar)"
        }
    }
})

# Start GUI
$form.Topmost = $true
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()
