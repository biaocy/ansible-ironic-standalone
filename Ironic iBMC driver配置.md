1. 安装 driver 依赖
    1. `git clone https://github.com/biaocy/sushy`
    2. `cd sushy`
    3. `pip install .`
2. 打 iBMC driver 补丁
    1. `sudo ./patch_ibmc_driver.sh patch`
3. 修改 ironic 配置文件`/etc/ironic/ironic.conf`
    1. 将`enabled_hardware_types`的值修改为`ibmc`
    2. 将`enabled_management_interfaces`的值修改为`ibmc`（若无该配置项，请在`enabled_hardware_types`配置项下一行添加）
    3. 将`enabled_power_interfaces`的值修改为`ibmc`（若无该配置项，请在`enabled_hardware_types`配置项下一行添加）
    4. 将`enabled_vendor_interfaces`的值修改为`ibmc`（若无该配置项，请在`enabled_hardware_types`配置项下一行添加）
4. 重启 ironic-conductor 服务
    1. `sudo systemctl restart ironic-conductor`
    2. `ironic-conductor`服务重启之后，执行`openstack baremetal driver list`，若列表中存在`ibmc`driver类型，即打补丁成功
5. 若重启 ironic-conductor 服务失败，可执行`sudo ./patch_ibmc_driver.sh undo`以撤销 iBMC driver 补丁