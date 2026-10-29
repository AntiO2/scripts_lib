# AstrBot Natural DM v2.0

Independent natural-language tabletop GM plugin for QQ groups with AstrBot 4.29.3

- Binary: `astrbot_plugin_natural_dm_v2.0.zip`
- SHA256: `6b0c9a90bb4e06c655278e560e8372ba48b39577b7c18a5bf6367ad8f53f2ac9`
- Activate: @ the bot and say 开始游戏; afterward no mentions required
- D&D 5e 2014/2024 12 Chinese class names; Daggerheart 9 core classes
- Two original beginner adventures, per-QQ-ID party, auto d20/duality dice, scene progress and persistence
- `/dm help` for optional management commands
- Existing surfing persona remains unchanged in AstrBot; its V4 snapshot is shipped as a style reference
- Does **not** implement full commercial rulebooks, full character sheets, spells, or all combat rules
- Not yet tested against the user's live QQ instance

### Installation on Ubuntu

```bash
cd ~/bots/qq
mkdir -p backup
if [ -d data/plugins/astrbot_plugin_dual_dm ]; then sudo mv data/plugins/astrbot_plugin_dual_dm backup/; fi
curl -fL --retry 3 'https://cdn.jsdelivr.net/gh/AntiO2/scripts_lib@astrbot-natural-dm-v2/astrbot_plugin_natural_dm_v2.0.zip' -o astrbot_plugin_natural_dm_v2.0.zip
echo '6b0c9a90bb4e06c655278e560e8372ba48b39577b7c18a5bf6367ad8f53f2ac9  astrbot_plugin_natural_dm_v2.0.zip' | sha256sum -c -
sudo unzip -oq astrbot_plugin_natural_dm_v2.0.zip -d data/plugins/
sudo docker restart astrbot
```
