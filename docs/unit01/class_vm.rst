Using Your Class Virtual Machine 
=================================

Every student in the class will have their own virtual machine (VM) to do work. We highly recommend 
that you use your class VM to work on the in-class exercises and take-home projects. The VMs have 
the Linux OS and and other software installed for you that will make getting started easier. Also, 
we (the teaching staff) have access to all of the VMs and can help you in case something goes 
very wrong. 

SSH Access To Your VM
----------------------
Once you have provides the instructors with your TACC account and your VM has been created, 
you can ssh to it using its IP address and your TACC credentials.

.. code-block:: console
   :emphasize-lines: 1-3,35,37

    [local]$ ssh <yout_tacc_username>@<your_IP_address>
    (username@your_IP_address) Password: 
    (username@your_IP_address) TACC_Token: 
        Welcome to Ubuntu 24.04.3 LTS (GNU/Linux 6.8.0-90-generic x86_64)

        * Documentation:  https://help.ubuntu.com
        * Management:     https://landscape.canonical.com
        * Support:        https://ubuntu.com/pro


Working With VSCode and the VM
------------------------------

We will be writing code in VSCode this semester, a modern Interactive Development 
Environment (IDE) with many advanced features for software engineering such as 
syntax highlighting, code completion and interactive debugging. 
Our setup will involve having VSCode running on your local laptop while all the 
actual code we write and execute will run on your dedicated VM. In this setup, 
you can think of VSCode somewhat like a "web browser" with the actual source code living 
on the VM.

There are a few advantages to this approach, including: 

 1) Your code can be accessed remotely from different computers, and different individuals 
    can access the running code (including the instructors and TAs, who can help troubleshoot issues); 
 2) All students code will execute in the same environment (Linux OS with the same CPU cores and memory, 
    etc.)

Installing VSCode on Your Laptop
--------------------------------
Hopefully everyone had a chance to install VSCode onto their computer last time. If not, here are instructions again,
for Windows, Mac, and Linux:

 * Linux -- Follow the instructions `here. <https://code.visualstudio.com/docs/setup/linux>`_
 * Mac -- Follow the instructions `here. <https://code.visualstudio.com/docs/setup/mac>`_
 * Windows -- Follow the instructions `here. <https://code.visualstudio.com/docs/setup/windows>`_

Remember, you only need to follow the first step to install the actual VSCode application. 

Installing the RemoteSSH VSCode Extension
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
After installing VSCode, you will also want to install the RemoteSSH extension. 
It provides support for developing code on remote servers using an SSH connection which 
will allow you to work with code and processes running on your TACC VM. 

Open the Extensions view by either clicking Extensions from the left navbar (the icon with two 
squares and a diamond) or by using the Ctrl+Shift+X (Linux/Windows) or Cmd+Shift+X (Mac) key combination. 
You will see the extensions organized into listed of "Installed", "Recommended", etc. You can also 
search for extensions by typing into the search box. Install the Remote-SSH (from Microsoft) 
extension. 

