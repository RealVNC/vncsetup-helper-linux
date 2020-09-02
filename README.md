This vncsetup.sh script is designed to help users of RealVNC's VNC Server (6.x) license and perform basic server configuration on Linux systems.

### INSTRUCTIONS

1.  On the computer running VNC Server, open a terminal window

2.  Run the below command
```sh
cd ~/Downloads && curl --retry 3 "https://raw.githubusercontent.com/andrewwoodhouse/vncsetup-helper-linux/master/vncsetup.sh" -o vncsetup.sh && chmod 0755 vncsetup.sh
```
3.  Execute the script:
```sh
sudo ./vncsetup.sh
```
