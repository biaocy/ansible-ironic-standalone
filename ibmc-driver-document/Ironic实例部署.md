#### 请先完成 `Ironic iBMC driver 配置`

1. 假设现在部署一台名为`test-ibmc`，指定IP为`10.0.0.160`的实例
2. 在环境搭建时用的inventory配置文件中（即`inventory/inventory.test.ini`）的`[baremetal]`节点下，添加`test-ibmc ansible_host=10.0.0.160`
3. 在`inventory/host_vars`下创建与实例名称相对应的裸机配置文件和`cloud-init`配置文件
    1. 创建裸机配置文件：`inventory/host_vars/test-ibmc`
    2. 创建`cloud-init`配置文件：`inventory/host_vars/test-ibmc.cloudconfig`，通过`cloud-init`方式可以进一步细化配置裸机，相关配置请参考[Cloud config](https://cloudinit.readthedocs.io/en/latest/topics/examples.html)
4. 准备裸机镜像相关文件
    1. 镜像制作：请参照[packer-ironic-images](https://github.com/biaocy/packer-ironic-images)
    2. 镜像制作完成后，将制作好的qcow2文件与meta文件上传至`nginx`（即`4.1`链接文档里Usage的第四步)
    3. 修改裸机镜像配置文件：若制作其他版本镜像OS，请按需修改`baremetal_image`(根据`3.1`文件中的配置`baremetal_os`默认是`xenial`，所以镜像配置文件为`vars/test/images/xenial.yml`)
5. 部署实例
    1. 在脚本根目录执行`ansible-playbook -vvvv -i inventory/inventory.test.ini add-baremetal-ibmc.yml`（若当前用户不是root用户，且root用户需要密码，则在参数`-vvvv`前添加参数`-K`）
    2. 在`Server Name`提示输入实例名，即`test-ibmc`
    3. `Deploy the server(y) or enroll (n)?[y]`提示询问是否创建实例后自动部署至裸机，回车输入默认是
