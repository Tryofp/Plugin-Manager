# Tryo Developer Panel

Standalone control panel for the public Plugin Manager.

## Load

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Tryofp/Plugin-Manager/refs/heads/developer/Main.lua"))()
```

## Scope

- Developer UI is loaded only from the `developer` branch.
- Public feature definitions and source files are read from `main`.
- Maintenance and badge changes use the existing Google Sheets Apps Script backend.
- Version History, Stable Backup and restore actions target `main`.
- This branch does not contain the public Loader, Plugin files, Tools or Infinite Yield bootstrap plugin.

The panel requires the authorized Roblox account and the server-side Developer Admin Key for protected actions.
