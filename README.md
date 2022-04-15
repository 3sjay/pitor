# pitor

Turn Raspbery Pi into a TOR router. After the setup is complete you can just plug it into a routing device and attach to a power adapter. Then the raspberry will spin up a new AP and all traffic will be routed through TOR.


## HOWTO

- Download raspbian lite
- Create bootable pen drive (e.g. /dev/sdc)
```
sudo dd if=raspbian.iso of=/dev/sdc bs=4M status=progress
sync
mkdir boot
sudo mount /dev/sdc1 boot
sudo touch boot/ssh
sync
sudo umount boot
```

- The above steps make sure that the ssh server is started on boot.
    Then login with pi:raspberry and change the password afterwards

Then copy the setup.sh script onto the Pi and run it as root. You will be prompted for several variables. Afterwards the configuration will be saved and will be applied even if the Pi reboots.
