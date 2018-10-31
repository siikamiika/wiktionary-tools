#!/usr/bin/env python3
import sys
import re

# wiki article title
TITLE_PATT = re.compile(r'<title>(.+)</title>')

# for dialectal synonym data
# wiki data module for chinese synonyms
DIAL_SYN_PATT = re.compile(r'Module:zh/data/dial-syn/(.+)')
# xml escaped lua table item
KEY_VAL_PATT = re.compile(r'\[.*?;(.+)?&.*?{(.+)?}')
# single xml escaped lua table value (when value is a list)
VAL_PATT = re.compile(r'&quot;([^, ]+)&quot;')

# for general synonyms
WIKI_SYN_PATT = re.compile(r'{{(?:.+, )?(?:q|i|qual|qualifier)\|(.+)?}}\s+({{zh-l\|.+?}}.*)')
ZH_L_PATT = re.compile(r'{{zh-l\|([^}]+)?}}')

# end
END_PATT = re.compile(r'<\/page>')

class EndOfFile(Exception):
    pass

def parse_dial_syn_data(file_handle, dialects):
    synonyms = set()
    for line in file_handle:
        if END_PATT.search(line):
            break
        else:
            key_val_match = KEY_VAL_PATT.search(line)
            if key_val_match and key_val_match.group(1) in dialects:
                synonyms |= set(w.split(':')[0] for w in VAL_PATT.findall(key_val_match.group(2)))
    return synonyms

def parse_syn_wikitext(file_handle, dialects):
    synonyms = set()
    for line in file_handle:
        if END_PATT.search(line):
            break
        else:
            wiki_syn_match = WIKI_SYN_PATT.search(line)
            if not wiki_syn_match:
                continue
            for dialect in dialects:
                if dialect in wiki_syn_match.group(1):
                    break
            else:
                break
            synonyms = set(w.split('|')[0].split('/')[0] for w in ZH_L_PATT.findall(wiki_syn_match.group(2)))
    return synonyms

def parse_next_synonym(file_handle, dialects):
    word = None
    synonyms = set()

    for line in file_handle:
        title_match = TITLE_PATT.search(line)
        if title_match:
            word = title_match.group(1)
            dial_syn_match = DIAL_SYN_PATT.search(word)
            if dial_syn_match:
                word = dial_syn_match.group(1)
                synonyms = parse_dial_syn_data(file_handle, dialects)
            else:
                synonyms = parse_syn_wikitext(file_handle, dialects)
            break

    if not word:
        raise EndOfFile
    else:
        return word, synonyms

def parse_synonyms(file_handle, dialects):
    while True:
        try:
            yield parse_next_synonym(file_handle, dialects)
        except EndOfFile:
            break

def main():
    input_filename, *dialects = sys.argv[1:]
    results = dict()
    with open(input_filename) as f:
        for word, synonyms in parse_synonyms(f, dialects):
            if not synonyms:
                continue
            if word not in results:
                results[word] = set()
            results[word] |= synonyms

    for word in sorted(results):
        synonyms = set(results[word])
        synonyms -= {word}
        if synonyms:
            print('{}\t{}'.format(word, '\t'.join(sorted(synonyms))))

if __name__ == '__main__':
    main()
