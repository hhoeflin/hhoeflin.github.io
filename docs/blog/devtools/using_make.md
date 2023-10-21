# Using makefiles and environment modules for tools in home folder

_August 2023_

## Introduction

In a previous post in [Nix in home folder](./using_nix.md) I talked about how to
set up development tools in ones home-folder without root using the Nix package
manager. While that affords very high reproducibility, it also required a large
amount of maintenance as well as time for compiling the tools. For practical
purposes, this turned out not to be feasible in the cases where needed most --
i.e. when working on systems without root access.

Therefore, looking for a simpler and more maintanable solution that also works
well on shared HPC systems, I set up a repository that only uses `make` as well
as `lmod` environment models together with standard build-tools such as wget,
autotools and gcc.

## Setup

The setup can be seen in
[Makefiles](https://github.com/hhoeflin/machine_setup/tree/master/makefiles). In
here, the global `Makefile` just calls the makefiles included in the
subdirectories, where each program has a subdirectory. This rule is only not
true for applications that use `Rust` or `Golang` and are so standardized in
their installation that a general makefile-recipe can be used with minor
adjustments using environment variables.

When installing software, most applications follow relatively closely a standard
recipe, but occasionally some adjustments are necessary. In order to allow for
this flexibility, I defined a set of standard variables and recipes, that are
however easy to override (see
[default.mk](https://github.com/hhoeflin/machine_setup/tree/master/makefiles/default.mk)).

In a typical application makefile, recipes for downloading the application
source as well as the compilation are defined, whereas recipes for `clean` or
`uninstall` as well as the creation of environment modules for use with `lmod`
are usually the default. This setup overall makes it simple to install the
application into a pre-defined directory hierarchy of type
<application>/<version>.

For `Rust`-based apps, typically it is enough to use a single standard makefile
that is configured only using environment variables (see
[rust_app](https://github.com/hhoeflin/machine_setup/tree/master/makefiles/rust_app)).
Similary I use application written in `Golang` with a single recipe. From this
mechanism I deviate for things like `exa`, an `ls` replacement, as there
additional aliases are defined in the `module_template` file and it therefore
needs further customization that the simple recipe cannot define.

The makefile also has the option to use certein environment modules that are
provided by the platform (such as compilers) and those can be specified in the
environment variable `GLOBAL_MODULES` where all modules that should be used can
be listed (space separated). This can be seen at the end of `default.mk`.

## Summary

Overall, this provides for a simple, lightweight setup that is

- easy to maintain
- easy to debug
- can use certain libraries or applications that are typically installed

The added bonus is that it uses environment modules, so individual programs can
quickly be loaded or unloaded and the modules can be set up to provide
additional features such as aliases that can be helpful (and then don't have to
be specified in the `.bashrc`, where they would be useless when the application
gets unloaded).
