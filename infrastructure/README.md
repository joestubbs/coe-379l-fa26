# COE 379L Fall 2026 Class Infrastructure Orchestration

Instructions for building student vms, configuring PAM access, and installing/configuring NIX.

## Class roster

Create a roster in a spreadsheet with the following tables:

```
Name	TACC Username	IP Address	Added to Allocation
```
Students should enter their names and TACC usernames here. Add the students to an allocation, and then note this in the allocation column.

## VM deployment

Vms are deployed in the Jetstream 2 TACC region under Openstack project "ENG230008TACC". This is best done using the [web gui](js2.jetstream-cloud.org).

Deploy the required amount of VMs with the following features:

Name: coe379
Image: Featured-Minimal-Ubuntu24
Flavor: m3.medium
Network: sharednet1
Security group: ssh-icmp-login
Keypair: Upload /root/.ssh/id_ecdsa.pub from host cic05

Once servers are deployed, create a file with uids of all VMs, and a separate file with uids of the same amount of floating IPs assigned to the project.

With a project scoped application credential, run this script to attach the floating IPs the the VMs.

```
$ ./addips.sh <IPs file> <VMs file>
```
You can now use the `openstack server list` command to view the servers, and copy the IPs into the class roster to assign VMs to students.

## PAM login configuration 

In order to configure the hosts to use TACC's MFA ssh login process, we run NSO's baseline playbook.

Modify the coe379 inventory in /root/rodeo2/ansible-inventories/cic-general/hosts. Then run as root:

```
$ ansible-playbook /root/rodeo2/nso-baseline/baseline.yml  -i /root/rodeo2/ansible-inventories/cic-general/hosts -u ubuntu -l coe379 
```

## Nix configuration

Copy the first 3 columns into a new spreadsheet. 

Insert an email column between `Name` and `Username` and populate each row with `user@email.com`. Then in an empty cell in row 1, enter `~=CONCATENATE("""",A1,"""")` and drag down the length of the table. Copy the quoted names as text into the first column.

The first 4 columns can now be pasted into an inventory file named `user-inventory` for configuring Nix on the VMs. Place this file into the same directory as the setup playbook.

Finally, run:

```
ansible-playbook -f 10 coesetup.yaml
``` 
