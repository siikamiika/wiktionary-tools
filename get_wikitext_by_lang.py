#!/usr/bin/env python3
import sys
from lxml import etree
import re
import json

LANG_PATT = re.compile(r'^==(.+)==')
LANG_END_PATT = re.compile(r'^----')

def parse_languages(data, languages):
    wikitext_by_lang = {}
    root = etree.fromstring(data)
    wikitext = root.xpath('revision/text')[0].text

    if not wikitext:
        return wikitext_by_lang

    lang = None
    for line in wikitext.splitlines():
        if not lang:
            new_lang = LANG_PATT.search(line)
            if new_lang:
                new_lang = new_lang.group(1)
                if new_lang in languages:
                    lang = new_lang
                    if lang not in wikitext_by_lang:
                        wikitext_by_lang[lang] = line
        elif LANG_END_PATT.search(line):
            lang = None
        else:
            wikitext_by_lang[lang] += line + '\n'

    if not wikitext_by_lang:
        return

    root.xpath('revision/text')[0].text = '\n'.join(wikitext_by_lang[k] for k in wikitext_by_lang)

    return etree.tostring(root)


def main():
    wiktionary, index, *languages = sys.argv[1:]
    index_fd = open(index)
    wiktionary_fd = open(wiktionary, 'rb')
    for line in index_fd:
        title, pos = line.split('\t')
        start, size = map(int, pos.split(':'))
        wiktionary_fd.seek(start)
        page = parse_languages(wiktionary_fd.read(size), languages)
        if page:
            print(page.decode('utf-8'))

if __name__ == '__main__':
    main()
