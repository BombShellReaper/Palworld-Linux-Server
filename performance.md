# Performance Configurations (Optional)

To optimize your server's tick rate, eliminate network rubber-banding during high-speed flying transitions, and maximize packet throughput, you can append advanced networking engine drivers directly to your configuration.

### 1. Locate the Engine.ini File
Open your active server engine configuration file via `nano`. Make sure to replace `your_username` with the actual non-sudo user account name you created in Step 4:

```bash
nano /home/your_username/pw_server/Pal/Saved/Config/LinuxServer/Engine.ini
```

### 2. Append the Performance Blocks
Scroll to the absolute bottom of the file, create a new blank line, and paste the following parameters exactly:

```ini
[/script/onlinesubsystemutils.ipnetdriver]
LanServerMaxTickRate=120
NetServerMaxTickRate=120

[/script/engine.player]
ConfiguredInternetSpeed=104857600
ConfiguredLanSpeed=104857600

[/script/socketsubsystemepic.epicnetdriver]
MaxClientRate=104857600
MaxInternetClientRate=104857600

[/script/engine.engine]
bSmoothFrameRate=true
bUseFixedFrameRate=false
SmoothedFrameRateRange=(LowerBound=(Type=Inclusive,Value=60.000000),UpperBound=(Type=Exclusive,Value=120.000000))
MinDesiredFrameRate=60.000000
NetClientTicksPerSecond=120
```

### 🔍 Why These Settings are Optimized for 1.0:
* **`NetServerMaxTickRate=120`**: Cranking this up from `80` to `120` matches the tick rate changes required by the updated 1.0 base engine mechanics [0.0]. It makes Pal interactions, sphere catching, and combat tracking feel drastically more responsive.
* **`LowerBound=60.000000`**: Raising the frame rate smoothing boundary floor to `60` ensures that your system resources prioritize keeping the server running fluidly without allowing sudden drop-offs below standard refresh targets.
* **`MaxInternetClientRate=104857600`**: This expands the available bandwidth pipe to 100 Megabits per player slot. This is crucial for the new version updates because the 1.0 map size expansion means players flying on fast mounts will load map chunks much faster, which would trigger extreme rubber-banding on default, throttled server limits.

### ⚠️ Notes:
* Always back up your original `Engine.ini` file before applying new custom blocks.
* For the configuration updates to take effect, recycle your server process using your management scripts:
  ```bash
  /home/your_username/name/palworld_stop.sh
  /home/your_username/name/palworld.sh
  ```
