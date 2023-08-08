# Development environment using Spack

*August 2023*

In this post we will look at another package manager
that can be used in situations where the user doesn't have root --
[Spack](https://github.com/spack/spack).

`Spack` is actually a Python-based software installation 
solution developed for HPC environments (similar to other projects 
in this space such as [EasyBuild](https://easybuild.io/)). As such
it is very powerful and has many options that are necessary for the 
purpose, such as the ability to pick the exact compiler, processor
architecture, various configuration options etc. It is also capable
of installing several versions of a software at the same time 
as well as make them available using environment modules. 

Installation procedures for packages are written as Python-classes
that implement methods that control how an installation is performed
and how the modules are being created. For many scientific applications
as well as common tools packages already exist.

A lot of information about `Spack` can be found in the
[manual](https://spack.readthedocs.io/en/latest/index.html) but
also the [tutorials](https://spack-tutorial.readthedocs.io/en/latest/).
It also has a nice section about using it as a 
[homebrew/conda replacement](https://spack.readthedocs.io/en/latest/replace_conda_homebrew.html),
which is similar to what we intend to do. So this is a good read as well.


## Basic setup

### Prerequisites and installation

The system requirements are pretty lightweight and should be easily satisfied.
A complete list can be found 
[here](https://spack.readthedocs.io/en/latest/getting_started.html#system-prerequisites).

Most of these should come pre-installed on a common OS, or for Debian and RHEL systems,
installation commands for the necessary prerequisites are provided.

For the installation of Spack itself, we just follow along in
[Getting started - Installation](https://spack.readthedocs.io/en/latest/getting_started.html#installation).

It in general has a lot of very detailed descriptions on what you can do with the tool, 
but we don't need anything beyond the basic:

```bash
git clone -c feature.manyFiles=true https://github.com/spack/spack.git
. spack/share/spack/setup-env.sh
```

and we are ready to get started with specifying the environment we want to have.

### Specifying the applications

As Spack comes with a large number of existing applications, we will create an environment
using those as much as possible for now, before we later look into writing our own packages.

The way we describe such an `environment` is explained in
[Environments](https://spack.readthedocs.io/en/latest/environments.html).

For now, we just specify an environment with only tmux 
as the only application (to make testing it out faster).

```yaml title="spack.yaml"
spack:
    specs:
        - tmux
    concretizer:
        unify: when_possible
```

### Configuration options

For us, we want to install the software in a our home directory in `~/.local/spack`. For
this we specify a configuration yaml file with the necessary settings. The 
list of possible settings is at 
[config.yaml](https://spack.readthedocs.io/en/latest/config_yaml.html).

For us, at first we simply create a new `config.yaml` file in our local directory
and specify the desired install location. However do look at the default configuration
as there are many other potentially interesting settings to try out.

```yaml title="config.yaml"
config:
    install_tree:
        root: ~/.local/spack
```

Here note how the top-level entry is `config`. This is done so that all different
`Spack` configuration files are easily composable. 

### Environment modules

In our case, we only want to create a module hierarchy with a prefix of `home` to 
distinguish it from the other module that we have in our system. We also don't need
any hashes at the end of our modules and only want them for the `lmod` system, not
`tcl`. Therefore we set 

```yaml title="modules.yaml"
modules:
    default:
        enable:
            - lmod
        roots:
            lmod: "~/.local/spack_modules"
        lmod:
            hash_length: 0
            projections:
                all: "home/{name}/{version}"
            all:
                conflict:
                    - "{name}"
```

This way it will be easy later to also inject our own custom modules into the 
hierarchy that has some adaptations, such as the setting of aliases etc.

### Performing the installation

The installation consists of two separate steps -  the concretization which
determines all the applications and their dependencies to install - as well as the
actual installation. This is done by calling `spack concretize` (possibly with -f to
force a re-evaluation) and `spack install`.

Note that using the `--config-scope` or `-C` switch (right after the `spack` command)
we can define custom scopes, such as settings that differ by the location we want to 
install our environment in (see 
[Custom scopes](https://spack.readthedocs.io/en/latest/configuration.html#configuration-scopes)).
With `-e` we specify the location of the relevant environment (the directory that contains 
the `spack.yaml` file).

When we are in the directory with our file, we can do something like:
```bash
spack -C . -e . concretize -f 
spack -C . -e . install
```

## Adding your own packages

Instead of adding packages to the default location, we specify our own
package repository location for this build. To do this, we need to specify
a custom `repos.yaml` (see also
[repos.yaml](https://spack.readthedocs.io/en/latest/repositories.html#repos-yaml)).

```yaml title="repos.yaml"
repos:
    - <absolute repo_dir>
```

Using this we can now use a created repository with our special packages
(which we can keep in a separate git repository).

### Creating new packages

First the repository needs to be created. This can be done with the 

```bash
spack repo create
```
command (see also 
[spack repo create](https://spack.readthedocs.io/en/latest/repositories.html#spack-repo-create)).

In this new folder, under `packages`, create a folder with the name of the 
package and inside a `package.py` file. There are many examples in the 
builtin repository under `<spack_dir>/var/spack/repos/builtin`. For example
creating a package for `mambaforge` is easy using the `conda` package
as an example. Usually, the best starting point is to pick an existing
recipe using the same build-system and to work from there.

### Adjusting existing packages

In certain situations it can also be wanted to adjust an already existing package. 
In this case, in order to retain all the upstream adjustements, we can directly
[inherit packages](https://groups.google.com/g/spack/c/yeceTzEdq5w/m/lP1AXcuHCwAJ)

## Other customizations
 
### Using special compilers

In an HPC environment with older OSes (such as CentOS 7), it may
be necessary to use compilers that are installed and provided using modules.

Spack also allows you to specify other compilers, even if environment
modules are needed to use them. For more on this see
[Compiler configuration](https://spack.readthedocs.io/en/latest/getting_started.html#compiler-configuration).

### Creating Docker containers

An additional nice feature of *Spack* is its ability to create docker as well
as singularity containers for existing environments 
(see [container images](https://spack.readthedocs.io/en/latest/containers.html)).

Using this recipe it is really easy to create a custom docker container for a number
of different linux operating systems. It is then of course also an option to 
copy the compiled binaries out of the container so that they don't have to be compiled
from scratch every time you need to set up a development environment. 

## Post-processing the modules

In the current way that modules are being created by Spack, it does not directly
support modules that need to call scripts or need to set shell-functions. Therefore
in there cases we need to perform a post-processing.

There are basically 2 options how to handle this. The first option is to
append additional script statements to existing modules. The disadvantage of this
is that during a module refresh, these changes would be overwritten.

The second approach is to provide additional modules that are custom-made and provide
the necessary steps to set shell functions or read scripts. Contrary to the first
approach, this would not be overwritten during a refresh, however now a different module
has to be loaded to achieve full functionality.

## Summary

With some minor adjustments, Spack is a very good tool and can be used to create custom development
environments. The only issue is the lack of complete configurability of the environment
modules, but this can easily be worked around.

## Other

### Package permissions

In order to set the package permissions so that we can't accidentially
change things, one can follow the instructions at 
[Package permissions](https://spack.readthedocs.io/en/latest/build_settings.html#package-permissions).


