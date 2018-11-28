1. 安装 driver 依赖
    1. `git clone https://github.com/biaocy/sushy`
    2. `cd sushy`
    3. `pip install .`
2. 复制 iBMC driver 相关文件
    1. 确认 ironic 安装目录
    2. 假设 ironic 安装目录在`/usr/lib/python2.7/dist-package`，在脚本根目录运行`tar -xf patch_for_rocky.tar -C /usr/lib/python2.7/dist-package`
3. 修改 ironic 配置文件`/etc/ironic/ironic.conf`
    1. 将`enabled_hardware_types`的值修改为`ibmc`
    2. 将`enabled_management_interfaces`的值修改为`ibmc`（若无该配置项，请在`enabled_hardware_types`配置项下一行添加）
    3. 将`enabled_power_interfaces`的值修改为`ibmc`（若无该配置项，请在`enabled_hardware_types`配置项下一行添加）
4. 重启 ironic-conductor 服务
    1. `sudo systemctl restart ironic-conductor`