#!/usr/bin/env python3
import sys
import json
import re

from fi_templates import *
from fi_patterns import *


def parse_finnish_wikitext(data, types_by_template):
    data = COMMENT_PATT.sub("", data)

    def _process_templ(match):
        template = match[1]
        template_name = BAR.split(template)[0]
        if template_name not in types_by_template:
            print(template_name, file=sys.stderr)
            return template
        template_type, *args = types_by_template[template_name]
        if template_type == "aka":
            args.append(types_by_template)
        return globals()[f"process_template_{template_type}"](template, *args)

    # brute force
    prev = None
    while data != prev:
        prev = data
        data = TEMPLATE_PATT.sub(_process_templ, data)

    return data


# def parse_finnish_wikitext(data):
#     words_by_pos = {}

#     pos = None
#     level = -1
#     for line in data.splitlines():
#         this_level = line.count("=") // 2
#         if not pos or this_level and this_level <= level:
#             new_pos = POS_PATT.search(line)
#             if new_pos:
#                 pos = new_pos.group(1)
#                 words_by_pos[pos] = []
#                 level = this_level
#             else:
#                 pos = None
#                 level = -1
#         else:
#             definition = DEF_PATT.search(line)
#             if definition:
#                 words_by_pos[pos].append(definition.group(1))

#     for pos in list(words_by_pos):
#         if not words_by_pos[pos]:
#             del words_by_pos[pos]

#     return words_by_pos


def main():
    input_file = sys.argv[1]

    with open("templates.def") as f:
        types_by_template = {}
        for line in f:
            line = line.strip()
            template, template_type, *args = line.split("|")
            types_by_template[template] = (template_type, *args)

    with open(input_file) as f:
        for line in f:
            title, wikitext = line.split("\t")
            wikitext = json.loads(wikitext)["Finnish"]
            parsed_wikitext = parse_finnish_wikitext(wikitext, types_by_template)
            print(
                f"{title}\n{parsed_wikitext}\n---------------------------------------------------------------------------"
            )


if __name__ == "__main__":
    main()
