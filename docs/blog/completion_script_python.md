# Completion in python CLIs

One of the nice features of a CLI is context specific TAB-completion that is provided by most shells.
Many of the standard python CLI tools provide such completion (e.g. `typer`). In this blog we want 
to look into how this is being done and in which way we want to implement this for `thermite`.

As an introduction to the topic, a very good blog post is at 
[bash-completion](https://julienharbulot.com/bash-completion.html). In there we see the basics 
of calling a completion for a program using a shell script that itself calls a python
script. 
