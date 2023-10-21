# How to use bash in docker using configuration files

## Abstract

When using Docker for data science, a particular problem is to ensure that the
correct environments are loaded at all times, e.g. conda.

In order to ensure that the environment is loaded correctly at all times, it has
to be initalized when starting an interactive shell as well as when starting a
program using a run command.

In the following we will show that this can best be achieved in 2 ways: a)
Always start each interactive shell and each run command using a login shell. b)
For interactive shells define a bashrc-file and set the environemnt variable
$BASH_ENV to the same file for non-interactive shells (e.g. run commands).

## Type of shells

Before we see all this in detail, we first review how the bash shell
configuration works. For shells, there are two properties that each shell has.
It is either a _login_ or a _non-login_ shell as well as an _interactive_ or
_non-interactive_ shell.

### Login shells

A login shell is typically started when logging into a computer. In it, certain
startup scripts are sourced that can be used to set the initial values for
environment varialbles, e.g. PATH. A new bash shell can be explicitly turned
into a login shell by using the _-l_ or _--login_ options.

### Interactive shells

An interactive shell is a shell that has its input, output and error streams
connected to a terminal. This is typically the case when you start a shell
inside another shell or when starting a shell in a docker container. The typical
case of a non-interactive shell is a shell that is started in order to run a
script. The option _-i_ can be used to explicitly turn a shell into an
interactive shell.

In addition to these option there are other switches that can be used to
customize the behaviour which startup scripts get run and we will go over them
and their effects later.

## Configuration files

There are a number of different configuration files that are sourced in
different situations. Here an overview of the ones relevant for bash:

- **/etc/profile:** This system-wide script is sourced by _login_-shells at
  startup before any other files are sourced
- **/etc/profile.d:** A system-wide directory from which additional scripts are
  sourced by _login_ shells. While not formally listed in the GNU manual linked
  above, most distributions also read all scripts in this directory.
- **~/.bash_profile, ~/.bash_login, ~/.profile:** These are scripts for
  individual users that are read by _login_ shells. Only the first of these
  scripts that exists and is readable is used. If the option _--noprofile_ is
  used, none of these scripts is sourced.
- **/etc/bashrc or /etc/bash.bashrc:** A system-wide script that is sourced by
  _interactive_ shells. CentOS uses _/etc/bashrc_ whereas Debian-based systems
  use _/etc/bash.bashrc_.
- **~/.bashrc:** This user-specific script is sourced for all _interactive_
  shells. If the option _--norc_ is used, this file is not being sourced. If the
  option _--rcfile file_ is being used, _file_ is sourced instead of
  _~/.bashrc_.
- **$BASH_ENV:** If a non-interactive shell is started and the environment
  variable _BASH_ENV_ exists, then the script file referenced in _BASH_ENV_ will
  be sourced.

### Behaviour for sh

When bash is invoked with the name _sh_, then its behviour changes.

- **login:** This behviour occurs when _sh_ is started with the _--login_
  option. It sources _/etc/profile_ and _~/.profile_ in this order. The
  _--noprofile_ prevents this (clarify if it prevents reading of both files or
  only one of them).
- **interactive:** It looks for the environment variable _ENV_ and sources the
  file referenced here. The option _--rcfile_ has no effect.
- **non-interactive:**: No startup files are being sourced.

### POSIX mode:

When started in POSIX mode, only the file referenced in the variable _ENV_ is
sourced. No other files are sourced.

## The docker setup

The rules for when which configuration files are executed for which shell can be
quite challenging to remember - at least for users that don't use this
functionality every day. The setup becomes even more challenging when used
together with Docker, where it is a priori less clear which type of shell is in
use at which point.

In order to make this easier to remember we create a small docker container that
shows which configuration files are run in which order under different
conditions.

In the container, _echo_ commands specifying the name of the file being sourced
are either - added at the end of the configuration file - replace the
configuration file with the _echo_ command

The reason for these two different conditions is that by default some
configuration files by default source other files and with this setup we want to
highlight the exact connections between files.

### Bash as an interactive shell

We can of course also regularly start bash as an interactive shell in the docker
container usign the _-it_ option for the docker-run command. We also specify to
docker to log us in as _userA_.

In this case, _/etc/bash.bashrc_ and _/home/userA/.bashrc_ are being sourced
(please note that it doesn't occur as an explicit code-block here as the
interactive part does not work in a Jupyter notebook).

    docker run -it --user userA hhoeflin/shell_test:bash-append /bin/bash

    ## Source /etc/bash.bashrc
    ## Source /home/userA/.bashrc
    ## userA@55411b7d527f:/$ exit

Another option to start an interactive shell is the _-i_ option to bash. This
cannot be combined with the bash _-c_ option to run a command passed as a
string, but we can use it when executing a script. However this results in an
error

    docker run --user userA hhoeflin/shell_test:bash-append /bin/bash -i /home/userA/script.sh

    ## bash: cannot set terminal process group (-1): Inappropriate ioctl for device
    ## bash: no job control in this shell
    ## Source /etc/bash.bashrc
    ## Source /home/userA/.bashrc
    ## /home/userA

In this case, instead of _/etc/bash.bashrc_ and _/home/userA/.bashrc_, we can
force a specific file to be used with the _--rcfile_ option. We can also ensure
that for interactive shells, no configuration script is loaded with _--norc_.

### The non-interactive bash shell

Instead of the interactive shell, we however usually when running a container
are being dropped into a non-interactive, non-login shell.

    docker run hhoeflin/shell_test:bash-append /bin/bash

As we can see, this sources no files at all. But when we now set the _BASH_ENV_
variable to _/etc/profile_, we see that the script gets loaded - together with
the script file in _/etc/profile.d_.

    docker run -e BASH_ENV=/etc/profile hhoeflin/shell_test:bash-append /bin/bash

    ## Source /etc/profile.d/test.sh
    ## Source /etc/profile

Strictly speaking the script in _/etc/profile.d_ should not have been loaded -
at least we did not explicitly ask for it. The reason is that all script in
_/etc/profile.d_ get sourced by the default _/etc/profile_. We confirm this by
running the same command, but this time using the version of the configuration
scripts that got replaced with the echo commands - not appended to.

    docker run -e BASH_ENV=/etc/profile hhoeflin/shell_test:bash-replace /bin/bash

    ## Source /etc/profile

### Bash as a login shell

When running bash, we can ask for it to be a login shell using the _-l_ or
_--login_ option.

    docker run hhoeflin/shell_test:bash-append /bin/bash --login

    ## Source /etc/profile.d/test.sh
    ## Source /etc/profile

and all the profile-related scripts get sourced. When at the same time we pass
the _--noprofile_ option

    docker run hhoeflin/shell_test:bash-append /bin/bash --login --noprofile

it prevents any profile scripts from being loaded.

Now this was all so far for the root user. We can also do this for any other
user

    docker run --user userA hhoeflin/shell_test:bash-append /bin/bash --login

    ## Source /etc/profile.d/test.sh
    ## Source /etc/profile
    ## Source /home/userA/.bash_profile

in which case _~/.bash_profile_ gets loaded, as this is the first user-specific
configuration file. For _userB_ and _userC_, we can see similar results, just
with their user-specific config files. For _userD_ that has all 3
profile-configuration files, ony the first, _~/.bash_profile_ gets loaded.

## Summary

We have seen how to use login shell and interactive/non-interactive shells in a
Docker container. If the goal is to have a specific script run in interactive
shells and non-interactive shells executing a command, then there are basically
2 choices to make this happen.

The first choice is to make interactive shells as well as non-interactive shells
both login shells and put the script that should be executed into either
_/etc/profile.d_ if it should be run for all users or into _~/.profile_ if it is
intended for a specific user. This however requires to set the _-l_ option on
all shells that are run.

The second option is to set the script as _/etc/bash.bashrc_ (or _/etc/bashrc_
on CentOS). In this case, this will automatically be run for all interactive
shells. For non-interactive shells, the _BASH_ENV_ variable pointing to this
file would ensure that it is sourced in this case as well.

Overall, requiring users to always request a login shell and not include any
_bashrc_ files is overall a bit more consistent in my opinion.

## References

In order to compile this Dockerfile and writeup I used various sources on the
internet.

- A good introduction to the subject is
  [GNU - Bash Startup Files](https://www.gnu.org/software/bash/manual/html_node/Bash-Startup-Files.html).
- Another very nice post is
  [Bash interactive, login shell types](https://transang.me/bash-interactive-login-shells/)
- [Bash cheat sheet](https://www.pcwdld.com/bash-cheat-sheet) (thanks to Marc
  Wilson for the link).

## Updates

- Added bash cheat-sheet on Dec 28th 2021 on suggestion of Marc Wilson.
