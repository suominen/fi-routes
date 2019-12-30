#!/usr/bin/env python
#
# Example 1: All blocks in list.txt, one CIDR per line
#   cat list.txt | cidr.py
#
# Example 2: Echo CIDR blocks to stdout
#   echo 1.2.3.0/25 1.2.3.128/25 | cidr.py

import sys
from netaddr import *

# Read from stdin
data = sys.stdin.readlines()

if len(data) == 1:
    # Input from echo
    data = data[0].split()

# Create an IPSet of the CIDR blocks
# IPSet automatically runs cidr_merge
nets = IPSet(data)

# Output the superset of CIDR blocks
for cidr in nets.iter_cidrs():
    print(cidr)
