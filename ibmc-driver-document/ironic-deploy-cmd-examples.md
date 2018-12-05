0. prepare env

开启 `iscsid` 
systemctl restart iscsid.service

环境变量
export OS_URL=http://127.0.0.1:6385
export OS_TOKEN=fake

1. Create Node
```
baremetal_name="112.93.129.9"
baremetal_deploy_kernel="file:///var/lib/ironic/http/deploy/coreos_production_pxe.vmlinuz"
baremetal_deploy_ramdisk="file:///var/lib/ironic/http/deploy/coreos_production_pxe_image-oem.cpio.gz"
baremetal_ibmc_addr="https://112.93.129.9"
baremetal_ibmc_user="*****"
baremetal_ibmc_pass="****"
baremetal_ibmc_sys="/redfish/v1/Systems/1"
NODE=$(openstack baremetal node create --name "$baremetal_name" --driver "ibmc" --power-interface "ibmc" --management-interface "ibmc" --boot-interface "pxe" --deploy-interface "iscsi" --driver-info ibmc_address="$baremetal_ibmc_addr" --driver-info ibmc_username="$baremetal_ibmc_user" --driver-info ibmc_password="$baremetal_ibmc_pass" --driver-info ibmc_system_id="$baremetal_ibmc_sys" --driver-info ibmc_verify_ca="False" --driver-info deploy_kernel="$baremetal_deploy_kernel" --driver-info deploy_ramdisk="$baremetal_deploy_ramdisk" -f value -c uuid)
```

创建完成后，通过如下命令查询已创建的Node列表：
```
openstack baremetal node list
```

2. Create Port

```
baremetal_mac="****" # 对应裸金属机器的网卡MAC
openstack baremetal port create --node $NODE "$baremetal_mac"
```

以 .9 为例：

```
openstack baremetal port create --node $NODE "58:F9:87:7A:A9:73"
openstack baremetal port create --node $NODE "58:F9:87:7A:A9:74"
openstack baremetal port create --node $NODE "58:F9:87:7A:A9:75"
openstack baremetal port create --node $NODE "58:F9:87:7A:A9:76"
```

3. Update Node image info

```
baremetal_image="http://10.0.1.100/images/ubuntu-xenial-16.04.qcow2"
# 可以通过 md5sum /var/lib/ironic/http/images/ubuntu-xenial-16.04.qcow2 来计算
baremetal_image_checksum="f3e563d5d77ed924a1130e01b87bf3ec" 

openstack baremetal node set "$NODE"
--instance-info image_source="$baremetal_image"
--instance-info image_checksum="$baremetal_image_checksum"
--instance-info root_gb="10"
```

> 设置完成后，可以通过以下命令来进行节点配置确认：
```
openstack baremetal node show $NODE -f json
```

4. Deploy Node 
```
openstack baremetal node manage "$NODE" &&
openstack baremetal node provide "$NODE" &&
openstack baremetal node deploy $NODE 
```

5. Query Boot Order

- 1. 查询节点自定义命令

```
$ openstack baremetal node passthru list 506aa36a-29aa-4cda-b0af-009ea9b55d1d -f json

[
  {
    "Response is attachment": false, 
    "Async": false, 
    "Name": "boot_up_seq", 
    "Supported HTTP methods": "GET", 
    "Description": "Returns a dictionary containing the key \"BootTypeOrderN\", its value is boot type of the node, where \"N\" is the order of boot type"
  }
]
```

- 2. 查询启动顺序

```
$ openstack baremetal node passthru call --http-method GET $NODE boot_up_seq
```


