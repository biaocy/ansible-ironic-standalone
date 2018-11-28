1. 安装 driver 依赖
    1. `git clone https://github.com/biaocy/sushy`
    2. `cd sushy`
    3. `pip install .`
2. 配置 iBMC driver 相关文件
    1. 确认 ironic 安装目录
    2. 假设 ironic 安装目录在`/usr/lib/python2.7/dist-packages`，在脚本根目录运行`tar -xf patch_for_rocky.tar -C /usr/lib/python2.7/dist-packages`
    3. 修改 ironic `entry_points.txt`（该文件会在 ironic 安装目录的 ironic-<版本号>.egg-info 文件夹下）
        1. 在`[ironic.hardware.interfaces.management]`节点的最后一行，添加`ibmc = ironic.drivers.modules.ibmc.management:IBMCManagement`
        2. 在`[ironic.hardware.interfaces.power]`节点的最后一行，添加`ibmc = ironic.drivers.modules.ibmc.power:IBMCPower`
        3. 在`[ironic.hardware.types]`节点的最后一行，`ibmc = ironic.drivers.ibmc:IBMCHardware`
3. 修改 ironic 配置文件`/etc/ironic/ironic.conf`
    1. 将`enabled_hardware_types`的值修改为`ibmc`
    2. 将`enabled_management_interfaces`的值修改为`ibmc`（若无该配置项，请在`enabled_hardware_types`配置项下一行添加）
    3. 将`enabled_power_interfaces`的值修改为`ibmc`（若无该配置项，请在`enabled_hardware_types`配置项下一行添加）
4. 重启 ironic-conductor 服务
    1. `sudo systemctl restart ironic-conductor`