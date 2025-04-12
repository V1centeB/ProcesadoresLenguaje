#!/bin/bash

bison trad3.y
gcc trad3.tab.c -o trad3
cat test.c | ./trad3 > test
cat test
