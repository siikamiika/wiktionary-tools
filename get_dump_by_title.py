#!/usr/bin/env python3
import sys
from lxml import etree
import re
import json

def main():
    wiktionary, index, title_patt = sys.argv[1:]
    index_fd = open(index)
    wiktionary_fd = open(wiktionary, 'rb')
    title_patt = re.compile(title_patt)
    for line in index_fd:
        title, pos = line.split('\t')
        if not title_patt.match(title):
            continue
        start, size = map(int, pos.split(':'))
        wiktionary_fd.seek(start)
        print(wiktionary_fd.read(size).decode('utf-8'))

if __name__ == '__main__':
    main()
