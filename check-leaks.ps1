# 注意：本文件必须保存为 UTF-8 with BOM。PowerShell 5.1 会把无 BOM 的 .ps1 按 ANSI 解析，中文会直接报语法错。
<#
  发布前敏感词检索（powered by check-leaks.ps1）
  用法：
    .\check-leaks.ps1                        自动读取上级目录的 _leak-terms.txt
    .\check-leaks.ps1 -TermsFile ..\terms.txt
    .\check-leaks.ps1 -Terms "aaa","bbb"     临时指定几个词
  退出码：0 = 干净，可发布；1 = 有命中；2 = 参数或读取错误
#>
param(
  [string[]]$Terms,
  [string]$TermsFile,
  [string]$Root
)

$ErrorActionPreference = 'Stop'
$skipExt = @('.png','.jpg','.jpeg','.gif','.webp','.ico','.zip','.7z','.pdf','.mp4','.mov','.woff','.woff2','.ttf')

if (-not $Root) { $Root = $PSScriptRoot }
$Root = [IO.Path]::GetFullPath($Root)
if (-not (Test-Path -LiteralPath $Root)) { Write-Host "目录不存在：$Root"; exit 2 }

if (-not $Terms -or $Terms.Count -eq 0) {
  if (-not $TermsFile) {
    $parent = [IO.Path]::GetDirectoryName($Root)
    $guess = Join-Path $parent '_leak-terms.txt'
    if (Test-Path -LiteralPath $guess) { $TermsFile = $guess }
  }
  if (-not $TermsFile) {
    Write-Host "没有提供检索词。"
    Write-Host "本脚本不内置词表：要核对的词本身就是需要剥离的内容，写进仓库等于自己泄露一次。"
    Write-Host '用法：.\check-leaks.ps1 -Terms "词A","词B"   或   -TermsFile <文件路径>'
    exit 2
  }
  $full = [IO.Path]::GetFullPath($TermsFile)
  if (-not (Test-Path -LiteralPath $full)) { Write-Host "检索词文件不存在：$full"; exit 2 }
  $enc0 = New-Object Text.UTF8Encoding($false, $true)
  try { $raw = [IO.File]::ReadAllText($full, $enc0) }
  catch { Write-Host "检索词文件不是合法 UTF-8：$full"; exit 2 }
  $Terms = $raw -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') }
}

if (-not $Terms -or $Terms.Count -eq 0) { Write-Host "检索词为空。"; exit 2 }

$enc = New-Object Text.UTF8Encoding($false, $true)
$hits = 0
$scanned = 0

$files = Get-ChildItem -LiteralPath $Root -Recurse -File -Force |
  Where-Object { $_.FullName -notlike '*\.git\*' -and $skipExt -notcontains $_.Extension.ToLower() }

foreach ($f in $files) {
  $scanned++
  try { $lines = [IO.File]::ReadAllLines($f.FullName, $enc) }
  catch { Write-Host ("跳过（编码异常或非文本）：" + $f.FullName.Replace($Root,'')); continue }
  for ($i = 0; $i -lt $lines.Count; $i++) {
    foreach ($t in $Terms) {
      if ($lines[$i].IndexOf($t, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $hits++
        Write-Host ("命中「" + $t + "」 " + $f.FullName.Replace($Root,'') + " 第 " + ($i+1) + " 行")
      }
    }
  }
}

Write-Host ""
if ($hits -eq 0) {
  Write-Host ("扫描 " + $scanned + " 个文件 / " + $Terms.Count + " 个检索词 —— 0 命中，可以发布。")
  exit 0
} else {
  Write-Host ("扫描 " + $scanned + " 个文件 —— 共 " + $hits + " 处命中，先改掉再发布。")
  exit 1
}
