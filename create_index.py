#!/usr/bin/env python3
import sys
import os
import re

START_PATT = re.compile(rb'<page>')
END_PATT = re.compile(rb'<\/page>')

TITLE_PATT = re.compile(rb'<title>(.+)</title>')


def parse_title_positions(fd):
    last_progress = 0
    total_size = os.fstat(fd.fileno()).st_size
    current_pos = 0

    title = None
    page_start = -1
    for line in fd:
        current_pos += len(line)
        pos_percent = int((current_pos / total_size) * 100)
        if pos_percent > last_progress:
            last_progress = pos_percent
            print(pos_percent, file=sys.stderr)

        if page_start == -1 and START_PATT.search(line):
            page_start = current_pos - len(line)
        elif page_start != -1 and END_PATT.search(line):
            yield title, page_start, current_pos - page_start
            page_start = -1
            title = None
        elif not title:
            title = TITLE_PATT.search(line)
            if title:
                title = title.group(1).decode('utf-8')

def main():
    input_filename = sys.argv[1]
    results = []
    with open(input_filename, 'rb') as fd:
        for page_title, page_start, page_size in parse_title_positions(fd):
            results.append(f'{page_title}\t{page_start}:{page_size}')
    for line in sorted(results, key=str.lower):
        print(line)

if __name__ == '__main__':
    main()
