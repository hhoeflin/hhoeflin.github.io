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

