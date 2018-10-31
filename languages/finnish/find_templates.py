#!/usr/bin/env python3
import sys
import json
import re

TEMPLATE_PATT = re.compile(r"\{\{([^\{\}]+)\}\}")
BAR = re.compile(r"\s*\|\s*")
COMMENT_PATT = re.compile(r"<!--.*?-->", re.DOTALL)


def find_templates(data, level=0):
    return {
        tuple(BAR.split(t)[: level + 1])
        for t in TEMPLATE_PATT.findall(COMMENT_PATT.sub("", data))
    }


def main():
    input_file = sys.argv[1]

    templates = set()

    with open(input_file) as f:
        for line in f:
            title, wikitext = line.split("\t")
            wikitext = json.loads(wikitext)["Finnish"]
            templates |= find_templates(wikitext)

    for template in sorted(templates):
        print("\t".join(template))


if __name__ == "__main__":
    main()
