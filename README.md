# milkv-duo Go template

Go template for building programs for the Milk-V Duo (RISC-V 64, Linux)
and deploying them to the board over the network.

## Requirements

- Go 1.27 or newer
- `rsync` and `ssh`
- A Milk-V Duo reachable over SSH

## Configuration

Edit the variables at the top of `build.sh`:

    APP_NAME      name of the produced executable
    REMOTE_USER   account on the board
    REMOTE_HOST   address of the board
    REMOTE_DIR    directory the binary is copied into

The SSH password/passphrase is prompted for interactively on `--deploy`/`--run`
and piped through an `SSH_ASKPASS` helper so `rsync`/`ssh` don't wait for terminal prompt.

## Usage

    ./build.sh                 build, debug (unoptimized, for delve)
    ./build.sh release         build, release (stripped binary)
    ./build.sh clean           remove this mode's build directory first
    ./build.sh --deploy        build, then copy the binary to the board
    ./build.sh --run           deploy, then execute it on the board
    ./build.sh --help

Arguments combine, e.g: `./build.sh release clean --run`.

The binary is written to `build/<mode>/<APP_NAME>`, cross-compiled with
`GOOS=linux GOARCH=riscv64`.

### Windows

`build.ps1` is a 1:1 PowerShell port for local iteration. `rsync` isn't
native to Windows, so the deploy step shells out to `wsl rsync`; password
handling is manual.

## Layout
    go.mod, go.sum   module definition
    template.go      program source
    build.sh         build, deploy and run (bash)
    build.ps1        build, deploy and run (PowerShell)