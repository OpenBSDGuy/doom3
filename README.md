# Doom 3

## Installation

It's possible to play Doom3 on OpenBSD using dhewm3:

```bash
$ doas pkg_add dhewm3
```

After that, check the guide under:

```bash
$ cat /usr/local/share/doc/pkg-readmes/dhewm3
```

## Copy game data

Create dhewm3 directory under `$HOME`:

```bash
$ mkdir -p ~/.config/dhewm3/base
```

Copy the game data (`*.pk4`) to the `base` directory.

## Copy CD key

create a file under `~/.config/dhewm3/base/doomkey` and add your CD key to it.

## Apply the patch

If your game data is from Steam or your game is already patched to version 1.3.1, skip this step.

Otherwise, download the `patch.sh` script, and run it:

```bash
$ chmod a+x patch.sh
$ ./patch
```

Once the script is executed, you should see an output like this:

```bash

```

## Run the game

Before running the game, it's better to export this environment variable:

```bash
$ export SDL_VIDEO_X11_DGAMOUSE=0
```

Then run the game

```bash
$ dhewm3
```

Happy Dooming! :-D
