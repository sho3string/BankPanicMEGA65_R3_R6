Bank Panic for MEGA65
=====================

Bank Panic is a classic arcade game released by Sega in 1984. In this Western-themed shooter, you play as a sheriff tasked with defending a bank from a gang of outlaws. The game features twelve doors, and you must quickly react to open each door and shoot the bandits before they rob the bank. Be careful not to harm innocent customers!

Gameplay is fast-paced and requires quick reflexes, as you have to distinguish between outlaws and innocent people while keeping an eye on all the doors. It's a fun and challenging game that captures the spirit of the Old West.

This core is based on the
[Pierre Cornier](https://github.com/sho3string/Arcade-BankPanic_MiSTer)
Bank Panic core which
itself is based on the wonderful work of [Pierre Cornier](AUTHORS).

The core uses the [MiSTer2MEGA65](https://github.com/sy2002/MiSTer2MEGA65)
framework and [QNICE-FPGA](https://github.com/sy2002/QNICE-FPGA) for
FAT32 support (loading ROMs, mounting disks) and for the
on-screen-menu.

How to install on your MEGA65
---------------------------------------------
Download the powershell or shell script depending on your preferred platform ( Windows, Linux/Unix and MacOS supported )

Run the script: a) First extract all the files within the zip to any working folder.

b) Copy the powershell or shell script to the same folder and execute it to create the following files.

**Ensure the following files are present and sizes are correct**
![image](https://github.com/user-attachments/assets/4a9f60c9-cb60-45fc-9fb8-f8d4e2b44fdf)

For Windows run the script via PowerShell - bankp_rom_installer.ps1  
Simply select the script and with the right mouse button select the Run with Powershell  
![image](https://github.com/user-attachments/assets/ba35d495-18dd-4794-8dcc-2961ad8e15c2)  
For Linux/Unix/MacOS execute ./bankp_rom_installer.sh  

The script will automatically create the /arcade/bankp folder where the generated ROMs will reside.  

Copy or move "arcade/bankp" to your MEGA65 SD card: You may either use the bottom SD card tray of the MEGA65 or the tray at the backside of the computer (the latter has precedence over the first).  

