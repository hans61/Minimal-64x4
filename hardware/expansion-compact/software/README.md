# Software for Expansion Compact

initexpansion.asm

Mutes the SN76489 and gives a short feedback by flashing the LEDs.
Cannot be called from the console as it terminates with RTS.
It must be included in the autostart file to be executed on a reset.

test-joystick.asm

Tests a Kempston compatible joystick on the port and outputs pressed keys.

![joystick test](picture/tstjoystick.jpg)

vgcplay.asm

Plays a vgm file for the SN76489. The data must be in a special format,
identified by the file extension vgc.

![play vgc](picture/vgcplay.jpg)

## SD card support

The low-level functions consist of initializing the SD card, sending commands and receiving responses.
As well as reading and writing a sector from the SD card. These work now, and I based them on this:

http://www.rjhcoding.com/avrc-tutorials-home.php

When it comes to file system support, I have initially limited myself to FAT32 and based my decision on this:

https://github.com/gfoot/sdcard6502/tree/master

Currently, the software only supports reading files. Only 8+3 file names are supported.
Files can be read into memory in their entirety, or byte by byte up to the end of the file.

sd_dir_root.asm

Shows the root directory of an SD card. The size of a file is displayed in hexadecimal.
System files and hidden files are hidden.

![dir sd card](picture/sd_dir_root.jpg)

sd_read_fat32.asm

Opens a directory on the SD card and reads a file in the directory into memory.
There must be a directory "SUBFOLDR" in the root and this directory must contain a file called
"DEEPFILE.TXT".

![open file](picture/open-dir-read-file.jpg)


