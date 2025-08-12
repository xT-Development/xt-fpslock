<div align="center">
  <h1>xt-fpslock</h1>
  <a href="https://dsc.gg/xtdev"> <img align="center" src="https://user-images.githubusercontent.com/101474430/233859688-2b3b9ecc-41c8-41a6-b2e3-a9f1aad473ee.gif"/></a><br>
</div>

# Features
- Accurate real-time FPS measurment using configurable buffer size
- Server defined FPS limit with configurable tolerance
- Violation warnings for sustained excessive FPS
- Configurable violation limits, dropping the player when they receive max FPS violations
- Helper commands:
    - `fpshelp` - Show instructions to cap FPS via Nvidia, AMD, RTSS, Vsync
    - `whatsmyfps` - Display your current FPS and server FPS cap

# Usage / Exports
```lua
exports['xt-fpslock']:getAverageFPS()       -- returns player average fps. this is the raw average. apply math.ceil/floor for integer value
exports['xt-fpslock']:getOverSustainTime()  -- returns how long the player has been over the fps limit
```

# Dependencies
- [ox_lib](https://github.com/CommunityOx/ox_lib/releases)