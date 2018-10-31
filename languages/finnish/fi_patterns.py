import re

POS = [
    "Adjective",
    "Adverb",
    "Ambiposition",
    "Article",
    "Circumposition",
    "Classifier",
    "Conjunction",
    "Contraction",
    "Counter",
    "Determiner",
    "Ideophone",
    "Interjection",
    "Noun",
    "Numeral",
    "Participle",
    "Particle",
    "Postposition",
    "Preposition",
    "Pronoun",
    "Proper noun",
    "Verb",
    "Circumfix",
    "Combining form",
    "Infix",
    "Interfix",
    "Prefix",
    "Root",
    "Suffix",
    "Diacritical mark",
    "Letter",
    "Ligature",
    "Number",
    "Punctuation mark",
    "Syllable",
    "Symbol",
    "Phrase",
    "Proverb",
    "Prepositional phrase",
]

POS_PATT = re.compile(f'==\s*({"|".join(POS)})\s*==')
DEF_PATT = re.compile(f"^\s*#\s*(.*)")

BAR = re.compile(r"\s*\|\s*")
TEMPLATE_PATT = re.compile(r"\{\{((?:[^\{\}]|\n)+)\}\}", re.MULTILINE)
COMMENT_PATT = re.compile(r"<!--.*?-->", re.DOTALL)
