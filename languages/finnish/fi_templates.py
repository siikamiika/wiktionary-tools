from fi_patterns import *


def process_template_i(templ):
    return ""


def process_template_lit(templ, *args):
    start_from = 0
    prepend = ""
    append = ""
    if len(args) > 0:
        start_from = int(args[0])
    if len(args) > 1:
        prepend = args[1] + " "
    if len(args) > 2:
        append = args[2]
    content = ", ".join(
        [a for a in templ["args"][start_from:] if a]
        + [f"{k}={v}" for k, v in templ["kwargs"].items()]
    )
    return f"{prepend}{content}{append}"


def process_template_borrowed(templ, prepend=""):
    borrowed_word = None
    if len(templ["args"]) > 2 and templ["args"][2] not in ["", "-"]:
        borrowed_word = templ["args"][2]
    gloss = templ["kwargs"].get("gloss")
    if not gloss and len(templ["args"]) > 4:
        gloss = templ["args"][4]

    out = f'{prepend}{templ["args"][1]}'
    if borrowed_word:
        out = f"{out} {borrowed_word}"
    if gloss:
        out = f'{out} ("{gloss}")'
    return out


def process_template_calque(templ):
    return process_template_borrowed(templ, prepend="calque of ")


def process_template_hyphenation(templ):
    hyphenated = '-'.join(templ['args'][1:])
    return f"hyphenation: {hyphenated}"


def process_template_r(templ, replacement):
    return replacement


def process_template_paren(templ):
    text = " ".join(templ["args"][1:])
    return f"({text})"


def process_template_aka(templ, aka, types_by_template):
    templ[0] = aka
    template_type, *args = types_by_template[aka]
    return globals()[f"process_template_{template_type}"](templ, *args)


def process_template_fi_noun_cases(templ):
    # TODO
    return ", ".join(templ)


def process_template_fi_adv_cases(templ):
    # TODO
    return ", ".join(templ)


def process_template_conj(templ):
    # TODO
    return ", ".join(templ)


def process_template_decl(templ):
    # TODO
    return ", ".join(templ)
