# AstrBot Dual DM v1.0

Dedicated distribution branch for the AstrBot plugin package.

- Binary: `astrbot_plugin_dual_dm_v1.0.zip`
- SHA256: `60c6c0b38ba31db7f5a6cf4d19e493e1688fde68ec1aeb192c0bb83c1d751bd1`
- Target: AstrBot 4.29.3
- Features: D&D 5e 2014/2024 basic mechanics, Daggerheart duality dice, QQ player identities, save/load, original beginner adventures, `/dm help`
- Limits: This package does not include full commercial rulebooks or implement all rules, spells and combat.

## Server installation

```bash
cd ~/bots/qq
curl -fL --retry 3 'https://cdn.jsdelivr.net/gh/AntiO2/scripts_lib@astrbot-dual-dm-v1/astrbot_plugin_dual_dm_v1.0.zip' -o astrbot_plugin_dual_dm_v1.0.zip
echo '60c6c0b38ba31db7f5a6cf4d19e493e1688fde68ec1aeb192c0bb83c1d751bd1  astrbot_plugin_dual_dm_v1.0.zip' | sha256sum -c -
unzip -oq astrbot_plugin_dual_dm_v1.0.zip -d data/plugins/
sudo docker restart astrbot
```

Use `/dm help` in QQ after loading the plugin.

This file is published on a separate branch to avoid changing the default branch's content.
