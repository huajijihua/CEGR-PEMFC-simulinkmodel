$env:ENABLE_MATLAB_MCP = '1'
Remove-Item Env:\CODEX_SKIP_MATLAB_MCP -ErrorAction SilentlyContinue
$env:AGENT_MATLAB_ROLE = 'claude'
$env:AGENT_MATLAB_MCP_APPDATA = 'C:\Users\ADMIN\AppData\Roaming\MATLABMCP-Claude'
$env:AGENT_COMSOL_ENABLE = '1'
$env:AGENT_COMSOL_MLI_ROOT = 'D:\COMSOL63\Multiphysics\mli'
$env:AGENT_COMSOL_AUTO_CONNECT = '1'
$env:AGENT_COMSOL_SERVER_HOST = '127.0.0.1'
$env:AGENT_COMSOL_SERVER_PORT = '2036'

$matlabExe = 'D:\matlab2025b\bin\matlab.exe'
$workspace = 'E:\agentwork_pemfc_cEGR_0519'

Write-Host ''
Write-Host '=== CLAUDE MATLAB MCP GUI launcher ==='
Write-Host 'This MATLAB GUI is reserved for Claude MCP attach.'
Write-Host 'MATLAB Command Window should show: MATLAB MCP session for CLAUDE.'
Write-Host 'MCP session root: C:\Users\ADMIN\AppData\Roaming\MATLABMCP-Claude'
Write-Host 'COMSOL LiveLink bootstrap: enabled'
Write-Host 'COMSOL target server: 127.0.0.1:2036'
Write-Host 'Do not attach Codex to this MATLAB GUI.'
Write-Host ''

Start-Process -FilePath $matlabExe -ArgumentList @('-desktop', '-sd', $workspace) -WindowStyle Normal
