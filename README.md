Cacti 服务器设置向导 <br>

此脚本需要 安装 git<br>

脚本使用 <br>
git clone https://github.com/bmfmancini/cacti-auto-install.git <br>
cd cacti-auto-install <br>
chmod +x cacti-setup-wizard.sh <br>
./cacti-setup-wizard.sh <br>
以 root 身份运行脚本


该脚本也适用于 RHEL，但是您必须在运行脚本之前启用 EPEL 并确保其正常工作
要启用 RHEL EPEL 报告，您可以使用以下命令
```
yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
```


- 特点是

-下载选择的或最新版本的仙人掌<br>
- 使用默认值或选择凭据自动配置数据库<br>
-auto 使用 cacti 推荐设置调整 MariaDB<br>
-自动填充仙人掌数据库<br>
-下载仙人掌安装所需的所有软件包<br>
-询问您是否要安装spine，如果是，它将自动编译它<br>
-添加系统用户并为文件夹分配权限<br>
-下载和安装插件<br>

调试
添加更多插件以下载选项<br>
添加选项以从列表中选择特定插件<br>
文档脚本


BUGS

##  无法在centos8上运行







