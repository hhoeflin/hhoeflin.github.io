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

