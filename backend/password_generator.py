"""
password_generator.py
----------------------
Cryptographically secure, customizable password generator.

Uses `secrets` (not `random`) because it draws from the OS CSPRNG -- this
matters for a password manager, where predictable output would be a real
vulnerability.
"""

import secrets
import string

AMBIGUOUS = set("Il1O0")


def generate_password(length=16, use_upper=True, use_lower=True,
                       use_digits=True, use_symbols=True,
                       avoid_ambiguous=True):
    length = max(4, min(int(length), 128))

    pools = []
    if use_lower:
        pools.append(string.ascii_lowercase)
    if use_upper:
        pools.append(string.ascii_uppercase)
    if use_digits:
        pools.append(string.digits)
    if use_symbols:
        pools.append("!@#$%^&*()-_=+[]{};:,.<>?/")

    if not pools:
        pools = [string.ascii_lowercase]  # never return an empty pool

    if avoid_ambiguous:
        pools = ["".join(c for c in pool if c not in AMBIGUOUS) for pool in pools]

    alphabet = "".join(pools)

    # Guarantee at least one character from each selected pool, then fill
    # the remainder randomly, then shuffle so the guaranteed chars aren't
    # always in the same position.
    password_chars = [secrets.choice(pool) for pool in pools]
    remaining = length - len(password_chars)
    password_chars += [secrets.choice(alphabet) for _ in range(remaining)]

    # Fisher-Yates shuffle using the CSPRNG
    for i in range(len(password_chars) - 1, 0, -1):
        j = secrets.randbelow(i + 1)
        password_chars[i], password_chars[j] = password_chars[j], password_chars[i]

    return "".join(password_chars[:length])
