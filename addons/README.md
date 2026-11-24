# Vendored add-ons

Third-party code for development, copied at a pinned version. This is tooling, not
game content (the game uses no third-party assets, see `CLAUDE.md`). Don't edit it
beyond the patches listed; to change behaviour, wrap it from `src/`.

| Add-on | Version | Source | License | Local patches |
|---|---|---|---|---|
| `godot_mcp` | 0.6.1 | [tomyud1/godot-mcp](https://github.com/tomyud1/godot-mcp) tag `v0.6.1` (copied from the author's godotDEMO project) | MIT | `runtime/mcp_runtime.gd` `_ready()` returns early unless the `editor` feature is present |
| `gut` | 9.7.1 | [bitwes/Gut](https://github.com/bitwes/Gut) tag `v9.7.1` | MIT | none |

## godot_mcp

- The editor plugin talks to `godot-mcp-server` (started by `.mcp.json`) on
  `ws://127.0.0.1:6505`. Keep the npm version in `.mcp.json` equal to the plugin version.
- `MCPRuntime` (the in-game half: screenshots, input, live node reads) is registered by
  hand in `project.godot`. The patch stops it outside editor builds, so an exported
  game never dials localhost.
