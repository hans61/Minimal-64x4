# Backplane and Prototyp

These are drafts to make testing easier for me. And to gain new insights.
They are not final goals and are really only intended for me.
Since the decoding of the I/O address is a recurring task, I have outsourced it to a “backplane”.
I have tested it with and without bus drivers and have not noticed any difference so far.
I don't know whether the drivers could have a negative effect on the timing.

So far I have successfully tested 74HC574 registers and the 82C55 I/O chip.
A test with the W65C22 was not successful so far.

The backplane decodes the I/O range 0xfe00..0xfeff and generates the INH signal.
It also generates chip select signals for the following address ranges:

| areas          |
|----------------|
| 0xfe80..0xfe8f |
| 0xfe90..0xfe9f |
| 0xfea0..0xfeaf |
| 0xfeb0..0xfebf |
| 0xfec0..0xfecf |
| 0xfed0..0xfedf |
| 0xfee0..0xfeef |
| 0xfef0..0xfeff |

I limited the internal bus to 1x20 pin. Only the addresses A0..A3 (for 8255, 6522,...) are available on the "internal bus".
In the future I would tend towards a 1x40 pin "internal bus" that contains all address lines.

![only for me](first-pcb.jpg)