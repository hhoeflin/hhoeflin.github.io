# Completion in python CLIs

One of the nice features of a CLI is context specific TAB-completion that is provided by most shells.
Many of the standard python CLI tools provide such completion (e.g. `typer`). In this blog we want 
to look into how this is being done and in which way we want to implement this for `thermite`.

## A simple first version

As an introduction to the topic, a very good blog post is at 
[bash-completion](https://julienharbulot.com/bash-completion.html). In there we see the basics 
of calling a completion for a program using a shell script that itself calls a python
script. 

From that blog, we start out with the shell script

```bash title="completions_v1.sh"
#/usr/bin/env bash
_completions_v1()
{
  COMPREPLY=($(  COMP_WORDS="${COMP_WORDS[*]}" \
                 COMP_CWORD=$COMP_CWORD \
                 COMP_LINE=$COMP_LINE   \
                 python completions_v1.py
            ) )
}   

# Register this function with:
complete -F _completions_v1 cmd_v1
```

with corresponding python script

```python title="completions_v1.py"
import os
cwords = os.environ['COMP_WORDS'].split()
cword = int(os.environ['COMP_CWORD'])
cline = os.environ['COMP_LINE']
# Do stuff
print("candidate1 candidate2")
```

The meaning of the bash-variables, which are set by bash once the completion is
being invoked can be looked up in the 
[Bash-manual](https://www.gnu.org/software/bash/manual/bash.html#Special-Builtins).

In short, `COMP_LINE` contains the current command line, `COMP_WORDS` is a bash array with the current
individual words in the command line and `COMP_CWORD` is an index into `COMP_WORDS` to the word
that is in the current cursor position.

## Testing how the word splitting works

One important aspect of these variables is how the word splitting exactly
works, e.g. in the cases of quoted inputs that contain whitespace. In order to 
test this out, we write a little completion script that echos these variables back.

```bash title="test_compvars.sh"
#/usr/bin/env bash
_test_compvars()
{
  local IFS=' '
  echo '\n'
  echo COMP_WORDS="${COMP_WORDS[*]}"
  echo WORD1=${COMP_WORDS[1]}
  echo COMP_LINE=${COMP_LINE}
  echo COMP_CWORD=${COMP_CWORD}
  echo COMP_POINT=${COMP_POINT}
  COMPREPLY=""
}   

# Register this function with:
complete -F _test_compvars test_cmd
```

After sourcing the script we can test it out with `test_cmd "a b" c d` and 
from the output

```sh
COMP_WORDS=test_cmd "a b" c d
WORD1="a b"
COMP_LINE=test_cmd "a b" c d
COMP_CWORD=3
COMP_POINT=18
```
we see that quotes protect _words_ from being split despite spaces as expected.
This is however something to consider when splitting a line inside a python
script, that simple splitting based on whitespace is incorrect in such situations.

Another observation is that if we put in additional whitespace before the first
parameter like `test_cmd   "a b" c d`, then this whitespace will be collapsed to a single
space
```sh
COMP_WORDS=test_cmd "a b" c d
WORD1="a b"
COMP_LINE=test_cmd "a b" c d
COMP_CWORD=3
COMP_POINT=20
```
and that however in this case, the value of `COMP_POINT` can't be used to 
infer the cursor position inside `COMP_LINE` as `COMP_LINE` does not match the exact 
command line that is on the terminal.

For the return value in `COMPREPLY`, by default different options are whitespace separated,
however we can change that by setting a different value for `IFS` to e.g. `\\a` so 
that we can return options separated by a _bell_ sound, which is usually not used on the command
line otherwise. This will also be used for the concatenation so that splitting on 
`\\a` in the python script works reliably to split into words.

In addition to this we can also pass an evaluated version of all the parameters, using a
bit of bash logic to create an evaluated array. Together we then get

```sh title="test_compvars_v2
#/usr/bin/env bash
_test_compvars_v2()
{
  local IFS='@'
  EVAL_WORDS=()
  for word in ${COMP_WORDS[@]}; do
    EVAL_WORDS+=( $(eval "echo $word") )
  done
  echo '\n'
  echo COMP_WORDS="${COMP_WORDS[*]}"
  echo EVAL_WORDS="${EVAL_WORDS[*]}"
  echo WORD1=${COMP_WORDS[1]}
  echo COMP_LINE=${COMP_LINE}
  echo COMP_CWORD=${COMP_CWORD}
  echo COMP_POINT=${COMP_POINT}
  COMPREPLY=""
}   

# Register this function with:
complete -F _test_compvars_v2 test_cmd_v2
```
In the upper script we have set `IFS` to `@` so that we can see it on the printout, 
but in practice it should be set to teh bell or some equally 
usually not used character (`\\a`). 

When using the command `export MYVAR=myvar_test_value` and `test_cmd_v2 " a b" c $MYVAR d`
where we trigger completion at the end of the second command.
```sh
COMP_WORDS=test_cmd@" a b"@c@$MYVAR@d
EVAL_WORDS=test_cmd@ a b@c@myvar_test_value@d
WORD1=" a b"
COMP_LINE=test_cmd " a b" c $MYVAR d
COMP_CWORD=4
COMP_POINT=25
```

## Putting it all together

So using the last parts together with the original python script we get


```bash title="completions_v2.sh"
#/usr/bin/env bash
_completions_v2()
{
  local IFS=$'\a'
  EVAL_WORDS=()
  for word in ${COMP_WORDS[@]}; do
    EVAL_WORDS+=( $(eval "echo $word") )
  done
  COMPREPLY=($(  COMP_WORDS="${COMP_WORDS[*]}" \
                 EVAL_WORDS="${EVAL_WORDS[*]}" \
                 COMP_CWORD=$COMP_CWORD \
                 python completions_v2.py
            ) )
}   

# Register this function with:
complete -F _completions_v2 cmd_v2
```

with corresponding python script

```python title="completions_v2.py"
import os
from typing import List

if __name__ == "__main__":
    cwords = os.environ["COMP_WORDS"].split("\a")
    eval_words = os.environ["EVAL_WORDS"].split("\a")
    cword = int(os.environ["COMP_CWORD"])

    # we choose one of several options
    options: List[str] = ["one", "two", "three"]

    try:
        comp_select_word = cwords[cword]
        possible_choices = [x for x in options if x.startswith(comp_select_word)]
    except Exception:
        possible_choices = []
    finally:
        print("\a".join(possible_choices))
```

Instead of `COMP_WORDS`, we can also use `EVAL_WORDS` and then be able to provide
completions for e.g. directories that are referred to by environment variables.

## Defining completion using JSON

As a next step, we can develop a more general setup, where we
encode the possible completion tasks using JSON and develop a general
python script (or library) that interprets the JSON, uses the COMP_WORDS
to provide a completion based on the JSON encoding of the available options. 

In order to safely store the JSON in an environment variable, we will _base64_-encode
the JSON string. This way no complicated quoting is necessary and the decoding operation
for _base64_ is very fast.

## Summary

In this post we outlined how to use a shell script to provide completion based on 
python code. 
