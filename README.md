Looking for an excuse to learn how to program the Commodore 64 and learn Zig, I found the following excellent projects
* https://github.com/kassane/zig-mos-bootstrap
* https://llvm-mos.org/
* https://github.com/MEGA65/mega65-examples/
* https://github.com/kassane/zig-mos-examples

The latter contains an impressive list of examples for a large number of 8-bit consoles.  As a learning exercise, since I was only interested in the
c64 portion of it, I stripped down the build.zig from that project to keep only the c64 relevant portions in an attempt to make the build.zig small
as possible.  I'm not an expert in Zig nor c64 programming, so I'm sure there are ways to make the build.zig more concise.  Let me know ;)

I tried to adapt the build.zig from the mega65 examples but I was unable to print to the screen for some reason. (Again I'm learning).

There are two files that I copied from the zig-mos-examples repo: panic.zig and mem.s. I don't know if they are absolutely necessary to include or not
 (at least for this very simple example).

The example in this repo is a simple hello world.

Zig is an interesting language that positions itself as a safer C alternative.  C64 programming seems like a appropriate use case for learning it.
