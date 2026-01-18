## Context

You are running on an Arch based system, either EOS or CachyOS. The system is usually kept in a clean state.

The system uses `fish` - if you ask the user to execute console commands please use the `fish` syntax. Heredocs won't work.

## General rules

* Write code and documentation in English language
* For examples use pop cultural references appropriate to a nerdy person born in the late 1970s
* When appropriate always create `.envrc` for direnv and a startup script
* If docker images are involved try loading them with `docker pull` before writing code to make sure they actually exist
* If a command requires `sudo` always ask the user to execute it

## Python specific

* Always create `.venv` and load it in `.envrc`

