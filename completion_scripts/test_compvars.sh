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

