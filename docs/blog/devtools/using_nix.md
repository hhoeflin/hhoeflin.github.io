# Nix and Home-manager in custom directory

_February 2022_

## Introduction

A few months ago I was looking for a way to create a setup for tools and
software in my home-folder that was easy and fast to deploy in a new location.
After some searching, I discovered [Nix](https://nixos.org) and
[Home-Manager](https://github.com/nix-community/home-manager).

From their [wiki](https://nixos.wiki/wiki/NixOS), NixOS is a Linux distribution
based on the Nix package manager and build system. It supports reproducible and
declarative system-wide configuration management as well as atomic upgrades and
rollbacks, although it can additionally support imperative package and user
management. In NixOS, all components of the distribution — including the kernel,
installed packages and system configuration files — are built by Nix from pure
functions called Nix expressions.

Home-Manager complements the Nix package manager by providing a system to manage
a users configuration for the home folder.

These tools have a relatively steep learning curve, but after a few months using
it I have to say that it is very worth the investment of time. Nix is a very
principled way to approach software deployment and its ideas provide a fresh
perspective on how reproducible configuration of software can be done that
provides multiple versions at the same time.

### Installation

Nix is very easy to install and instructions are provided on the homepage.
However this is only true under the assumption that the user has `sudo`
permissions or an administrator performs certain setup steps. If these
conditions are not met, deploying nix is a lot trickier. In the rest of the post
I will outline how to deploy nix using home-manager in the home folder without
sudo.

The biggest drawback of the route I have chosen is that the Nix binary cache
does not work, which can mean long compile times when deploying new software
(long can mean 10+ hours). This can be tricky when trying to install software
ad-hoc, but for me is an ok tradeoff for deploying home-folder software where
the setup changes much more slowly. Additionally, not every program works
without error when compiled from scratch so that ocassionally an override patch
is necessary.

#### Nix-portable

[Nix-portable](https://github.com/DavHau/nix-portable) is a wrapper that allows
nix to be used in a users home folder without sudo permissions while still being
able to use the binary cache. Please go the its website to read about some of
the requirements and missing features of this approach.

In my case, it does not support sufficient features to deploy a Home-Manager
setup so that I decided not to use it.

### Why not use some other tool?

Before going into more details of the setup, I briefly wanted to talk about some
of the other tools that could be used for similar purposes.

#### Homebrew

[Homebrew](https://brew.sh/), often called the missing package manager for MacOS
(and later also linux), is a tool to easily install software in a user's home
directory. Its big advantage is that it can be run without sudo and that a very
large amount of packages is available for installation.

It is a very good tool, however it does not provide the same level of
independence of the host system as Nix does, so incompatibilities from one OS to
the other can happen. Furthermore, it also does not a manager for home-folder
configurations such as Home-Manager

#### Spack or Easybuild

Both [Spack](https://spack.readthedocs.io/en/latest/) and
[Easybuild](https://docs.easybuild.io/en/latest/) are tools to install software
on HPC systems. As such they have the ability to install multiple versions of
the same software side by side and allow the user to activate them on-demand
(e.g. by using environment modules).

Both these systems are very sophisticated and are more targeted towards HPC
admins than individual users. In general, availablility of packages and latest
versions is lower than for Nix and they also don't provide a complete solution
for managing the home-folder configurations.

## The build process

Now let us move on to the actual installation process.

### Requirements

It is necessary to have a linux distribution available with sudo permissions so
that nix can be deployed as described in the user manual. In the following it is
assumed that a nix installation is available with nix version >= 2.4.

### Setting environment variables

In order to install in a custom location, it is possible to change the
directories used by Nix with environment variables. These need to be sourced
before the build process.

```title='nix_vars.sh'
--8<-- "nix/home/nix_vars.sh"
```

This corresponds to a nix installation where `storedir=${PREFIX}/nix/store`,
`localstatedir=${PREFIX}/nix/var/` and `sysconfdir=${PREFIX}/nix/etc`, where
`storedir`, `localstatedir` and `sysconfdir` are defined in the nix installation
in nixpkgs defined in
[nix/default.nix](https://github.com/NixOS/nixpkgs/blob/master/pkgs/tools/package-management/nix/default.nix)
and the details for the environment variables in
[local.mk](https://github.com/NixOS/nix/blob/master/src/libstore/local.mk)

### The flake

At first for practice we write a flake for only compiling nix itself. In this
flake we need to override some attributes in order to set the custom variables
as well as add some patches (on linux, the sandbox test is broken for
non-default directories, so we disable it). A basic flake could be

```nix title='flake.nix'
--8<-- "nix/basic/flake.nix"
```

with patch

```title='nix_patch_2_5.patch'
--8<-- 'nix/basic/nix_patch_2_5.patch'
```

With this flake, we can just build a version of nix with `nix build .#nix`.

## Flake for home-manager

We also want to use this in home-manager of course. A minimal flake to set this
up is below, together with a minimal `home.nix` that just requires `nix` itself
and ensures the environment variables are loaded in the profile. As of this
writing, the current version of nix was 2.5.1.

```title='flake.nix'
--8<-- 'nix/home/flake.nix'
```

As home-manager depends on nix-2.3, we also create a patch that disables sandbox
testing for that version.

```title='nix_patch_2_3.patch'
--8<-- 'nix/home/nix_patch_2_3.patch'
```

For defining the home-folder environment itself, we need a `home.nix` file that
we import in the configuration. This one is quite minimal, defining `nix` itself
as the only read dependency. We also set the `profile` for the account so that
all scripts in `profile.d` directory in the home-folder are being read, where we
then set the script to read the environment variables.

```title='home.nix'
--8<-- 'nix/home/home.nix'
```

As to having nix in home-manager itself, it is not necessary and up to the end
user. Having it in there automatically upgrades nix on new deployments, and
builds it in one go when building home-manager but it also makes initial
deployment trickier, as the first time nix itself has to be uninstalled from the
user environment.

Typical steps for installing this new would be:

```bash
# set the PATH explicitly to the installed nix
export PATH=$(dirname $(readlink $(which nix))):$PATH

# we remove nix itself that comes pre-installed from the user profile
nix-env -e nix

# build the flake for the testuser
nix build .#testuser

# run the activate script
./result/activate
```

## Discussion

In the setup before, even after compiling nix with a different state and store
directory, we still have to load the environment variables for it to work
reliably. The reason is that home-manager used incorrect directories e.g. for
lock files if they were not set. Setting the environment variables fixed the
issue, but I did not track down which particular variable is necessary.

Another observation is that compilation of nix and libraries works very well, up
to minor issues like the error in the sandbox tests of nix. I am not sure if
this is due to the OS where I compiled it (Ubuntu) or due to the custom
nix-store paths.

I had also trouble confirming the new store and state-paths were correctly
picked up by nix. Commands like `nix show-config` for example don't list any of
these directories, making it hard to confirm what they are using (but probably,
as I am still very new to this, I don't know how to do this correctly).

I hope this was helpful, but please let me know in the comments below.

## Other resources

My starting point was a Github repository that compiles nix for HPC at
[danielbarter/hpc-nix](https://github.com/danielbarter/hpc-nix).
