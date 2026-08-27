# Performance Configurations (Optional)

Tick rate and bandwidth tuning genuinely matter for reducing desync and rubber-banding - but there's no single "correct" number that works for every server. This file used to recommend fixed values (`NetServerMaxTickRate=120`, `MaxClientRate=104857600`) as if they were settled facts. They aren't - those specific numbers are widely copy-pasted across hosting-provider guides, but don't hold up well under scrutiny: real admin reports show `120` producing as low as 23 FPS even on strong hardware (dual Xeon E5-2680 v4, 192GB RAM), because Palworld's simulation only meaningfully uses ~3-4 cores regardless of total core count - the actual bottleneck is single-thread CPU headroom, not raw core count.

This version explains the real tradeoff and how to find the right number for *your* hardware, instead of asking you to trust someone else's box.

### 1. Locate the Engine.ini File

    nano /home/your_username/pw_server/Pal/Saved/Config/LinuxServer/Engine.ini

### 2. Start Conservative, Then Measure

Append the following as a starting point - not a final answer:

```ini
[/script/onlinesubsystemutils.ipnetdriver]
LanServerMaxTickRate=30
NetServerMaxTickRate=30
MaxClientRate=100000
MaxInternetClientRate=100000
```

> [!Note]
> `MaxClientRate`/`MaxInternetClientRate=100000` (~100KB/s per client) matches values used in documented, technically-detailed hosting guides - not the `104857600` (100MB/s) figure that used to be here, which has no real precedent behind it and doesn't add benefit past what real client connections and the engine's own packet serialization can actually use.

### 3. Test Under Real Load, Then Raise Incrementally

30 is Unreal Engine's safe, well-supported baseline - not a ceiling. The right approach is:

1. Restart the server with the conservative values above.
2. Play or have your regular player count online for a real session.
3. Check the server's actual tick performance directly rather than guessing - either from the local server console (`screen -r Palworld`) if the binary reports it, or via RCON if you have `RCONEnabled=True` set in `PalWorldSettings.ini`.
4. If the server is comfortably keeping up (no dropped ticks, no CPU pinned near 100% on the cores Palworld actually uses), raise `NetServerMaxTickRate`/`LanServerMaxTickRate` in small steps - `30 → 45 → 60` - re-testing at each step.
5. Stop raising it the moment you see it stop making a real difference, or see performance get *worse* instead of better. More than one admin has reported exactly that pattern with `120`.

> [!Caution]
> `60` is the highest value multiple independent, technically-detailed sources treat as reliably supported. Going higher isn't wrong by definition, but treat it as an experiment specific to your own hardware and player count - not a default to reach for because a hosting-provider guide lists it.

**A rough rule of thumb**, from real community testing on comparable hardware: your realistic sustainable tick rate scales with `(your server's actual usable CPU headroom) / (player count)` - not a fixed universal number. A box that's fine at `60` with 4 players may not be fine at `60` with 20.

### 4. Frame Rate Settings Are Likely Inert Here

Settings like `bSmoothFrameRate`, `SmoothedFrameRateRange`, and `MinDesiredFrameRate` govern *rendering* frame rate. A dedicated server has no renderer running (it's headless) - these settings very likely have nothing to act on in this context, regardless of what value they're set to. They're left out of the block above rather than included on unverified faith.

### ⚠️ Notes

* Always back up your original `Engine.ini` before applying changes.
* For changes to take effect, recycle the server using your management scripts:

  ```bash
  /home/your_username/.scripts/stop_server.sh
  /home/your_username/.scripts/start_server.sh
  ```
