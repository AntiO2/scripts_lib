# SCRIPTS_LIB

个人使用的脚本库

使用方式： 在 `~/.zshrc` 或 `~/.bashrc` 中添加

```zsh
source ${PROJECT_DIR}/entry.sh ${PROFILE_NAME} 
```

系统加载环境 `env/${PROFILE_NAME}` 覆盖默认加载的 `default.env`

例如

```bash
# cd scripts_lib

PROFILE_NAME="cds"
ENTRY_SCRIPT_PATH=`readlink -f entry.sh`

echo "source ${ENTRY_SCRIPT_PATH} ${PROFILE_NAME}" >> ~/.zshrc
source ~/.zshrc
```