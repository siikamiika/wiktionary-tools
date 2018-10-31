from fi_patterns import *


def process_template_i(templ):
    return ""


def process_template_lit(templ, start_from=0):
    return ", ".join(BAR.split(templ)[start_from:])


def process_template_r(templ, replacement):
    return replacement


def process_template_paren(templ):
    text = " ".join(BAR.split(templ)[1:])
    return f"({text})"


def process_template_aka(templ, aka, types_by_template):
    templ = BAR.split(templ)
    templ[0] = aka
    templ = "|".join(templ)
    template_type, *args = types_by_template[aka]
    return globals()[f"process_template_{template_type}"](templ, *args)


def process_template_conj(templ):
    # TODO
    return ", ".join(BAR.split(templ))


def process_template_decl(templ):
    # TODO
    return ", ".join(BAR.split(templ))
