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
