# Compare the "MON" lines (Scripts/COOP/Monitor.lua) of the server log and a client log and list
# where the client disagrees with the server. The two game clocks differ, so it compares the last
# -Window seconds of each side by entity id, not line by line.
# Usage: games\far-cry\tools\mon-diff.ps1 [-Server <log>] [-Client <log>] [-Window 10]
param(
  [string]$Server = 'D:\SteamLibrary\steamapps\common\FarCry\log_WinSV.txt',
  [string]$Client = 'D:\SteamLibrary\steamapps\common\FarCry\log.txt',
  [int]$Window = 10
)

function Read-Mon($path, $side) {
  $rows = foreach ($l in (Select-String -Path $path -Pattern "^MON $side " -Encoding Default).Line) {
    if ($l -match '^MON \w t=(\S+) ([PAV]) (\d+) (.*?) ?pos=(\S+),(\S+),(\S+) (.*)$') {
      [pscustomobject]@{ t = [double]$Matches[1]; k = $Matches[2]; id = $Matches[3]; name = $Matches[4]
        x = [double]$Matches[5]; y = [double]$Matches[6]; z = [double]$Matches[7]; rest = $Matches[8] }
    }
  }
  if (-not $rows) { return @{} }
  # keep only the last map: _time restarts on every map load, so cut at the last time jump back
  $start = 0
  for ($i = 1; $i -lt $rows.Count; $i++) { if ($rows[$i].t -lt $rows[$i - 1].t - 1) { $start = $i } }
  $rows = $rows[$start..($rows.Count - 1)]
  $tEnd = $rows[-1].t
  $by = @{}
  foreach ($r in $rows | Where-Object { $_.t -gt $tEnd - $Window }) {
    if (-not $by[$r.id]) { $by[$r.id] = [System.Collections.ArrayList]@() }
    [void]$by[$r.id].Add($r)
  }
  $by
}

function Moved($list) { # path length in metres
  $d = 0.0
  for ($i = 1; $i -lt $list.Count; $i++) {
    $a = $list[$i - 1]; $b = $list[$i]
    $d += [math]::Sqrt(($a.x - $b.x) * ($a.x - $b.x) + ($a.y - $b.y) * ($a.y - $b.y) + ($a.z - $b.z) * ($a.z - $b.z))
  }
  $d
}

$ServerRows = Read-Mon $Server 'S'
$ClientRows = Read-Mon $Client 'C'
if (-not $ServerRows.Count) { "no MON S lines in $Server"; return }
if (-not $ClientRows.Count) { "no MON C lines in $Client"; return }

$out = foreach ($id in $ServerRows.Keys) {
  $s = $ServerRows[$id]; $c = $ClientRows[$id]; $sl = $s[-1]
  $row = [ordered]@{ kind = $sl.k; id = $id; name = $sl.name; problem = ''; server = ''; client = '' }
  $ms = Moved $s
  if (-not $c) {
    $row.problem = 'not on client (or out of client range)'
    $row.server = "moved $([math]::Round($ms,1)) m"
  } else {
    $cLast = $c[-1]; $mc = Moved $c
    $gap = [math]::Sqrt(($sl.x - $cLast.x) * ($sl.x - $cLast.x) + ($sl.y - $cLast.y) * ($sl.y - $cLast.y) + ($sl.z - $cLast.z) * ($sl.z - $cLast.z))
    $p = @()
    if ($ms -gt 3 -and $mc -lt 0.5) { $p += 'FROZEN on client' }
    elseif ($gap -gt 5) { $p += "position off by $([math]::Round($gap,1)) m" }
    $sf = @{}; $cf = @{}
    foreach ($kv in $sl.rest -split ' ') { $n, $v = $kv -split '=', 2; $sf[$n] = $v }
    foreach ($kv in $cLast.rest -split ' ') { $n, $v = $kv -split '=', 2; $cf[$n] = $v }
    foreach ($f in 'hp', 'w', 'veh', 'drv') {
      if ($sf.ContainsKey($f) -and $cf.ContainsKey($f) -and $sf[$f] -ne $cf[$f]) { $p += "$f $($sf[$f]) vs $($cf[$f])" }
    }
    $row.problem = $p -join '; '
    $row.server = "moved $([math]::Round($ms,1)) m, $($sl.rest)"
    $row.client = "moved $([math]::Round($mc,1)) m, $($cLast.rest)"
  }
  [pscustomobject]$row
}

"== problems (last $Window s of the current map) =="
$bad = $out | Where-Object problem | Sort-Object kind, name
if ($bad) { $bad | Format-Table kind, id, name, problem, server, client -AutoSize -Wrap | Out-String -Width 220 }
else { "none: $($out.Count) entities agree" }
"== last events =="
"-- server"; (Select-String -Path $Server -Pattern '^MON S \S+ E ' -Encoding Default | Select-Object -Last 8).Line
"-- client"; (Select-String -Path $Client -Pattern '^MON C \S+ E ' -Encoding Default | Select-Object -Last 8).Line
