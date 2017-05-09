# Remote agent update kit

This guide will take you through manually updating the Ardexa agent remotely.

For older versions of the agent (earlier than 1.6.0), the additional `disown` binary is required.  Versions since 1.6.0 have disown built into the agent.

## Compile disown
```
g++ disown.c -o disown
```

* transfer the `disown` to the target using `SEND FILES`
* make sure `disown` is executable and in the `$PATH`

Using the "Remote Shell":
```
chmod +x /home/ardexa/disown
mv /home/ardexa/disown /usr/local/bin
```

## Preparation

* transfer `ardexa-update.sh` to the target

Using the "Remote Shell":
```
chmod +x /home/ardexa/ardexa-update.sh
```

* transfer the new agent binary to the target and unzip it (you can download just the agent binary from https://app.ardexa.com/devices, click "Update Agent", tick "download only" and click "Download")

Using the "Remote Shell":
```
unzip -d /home/ardexa /home/ardexa/ardexa.armhf.zip
```

## [OPTIONAL] Start the SSH tunnel

This will create a backup SSH tunnel into the destination device

### Launch bastion host (with public IP)

**Google Compute Engine**
```
gcloud compute instances create ssh-endpoint --machine-type "f1-micro" --image-project debian-cloud --image-family debian-8 --tags ssh
```

### Generate the keys on the agent

This is a one time process. If you already have a public key on the target machine, please skip this step.

Using the "Remote Shell":
```
mkdir -m 700 /root/.ssh
ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ''
```

### Prepare the bastion

Get a copy of the target machine's public key

Using the "Remote Shell":
```
cat /root/.ssh/id_rsa.pub
```

Add the Key to the `.ssh/authorized_keys` file on the bastion SSH server

```
gcloud compute ssh ssh-endpoint
echo $PUB_KEY_FROM_TARGET >> .ssh/authorized_keys
```

Get the target host to open an SSH Tunnel to the bastion

Using the "Remote Shell":
```
disown 'ssh -o StrictHostKeyChecking=no -fNnR 2222:localhost:22 mohrd@104.154.64.58'
```

You can check the status of the ssh process using the following commands. `CGroup` should equal `/system.slice`

Using the "Remote Shell":
```
ps -ef | grep ssh
systemctl status <pid_of_ssh_tunnel> | grep -i cgroup 
```

## Update the agent

Once all the necessary files are in place, either launch the update using disown (Agents prior to 1.6.0)

Using the "Remote Shell":
```
disown '/home/ardexa/ardexa-update.sh --newfile /home/ardexa/ardexa.armhf'
```

Or, make sure the `disown` option is ticked in "Remote Shell -> Advanced Settings"

Using the "Remote Shell":
```
/home/ardexa/ardexa-update.sh --newfile /home/ardexa/ardexa.armhf
```
