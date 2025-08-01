#!/bin/sh
# Copyright (C) Dan Fandrich, <dan@coneharvesters.com>, Viktor Szakats, et al.
#
# SPDX-License-Identifier: curl

# https://cmake-format.readthedocs.io/en/latest/cmake-lint.html
# https://cmake-format.readthedocs.io/en/latest/lint-usage.html
# https://github.com/cheshirekow/cmake_format/blob/master/cmakelang/configuration.py

# Run cmakelint on the curl source code. It will check all files given on the
# command-line, or else all relevant files in git, or if not in a git
# repository, all files starting in the tree rooted in the current directory.
#
# cmake-lint can be installed from PyPi with the command "python3 -m pip
# install cmakelang".
#
# The xargs invocation is portable, but does not preserve spaces in file names.
# If such a file is ever added, then this can be portably fixed by switching to
# "xargs -I{}" and appending {} to the end of the xargs arguments (which will
# call cmakelint once per file) or by using the GNU extension "xargs -d'\n'".

set -eu

cd "$(dirname "$0")"/..

{
  if [ -n "${1:-}" ]; then
    for A in "$@"; do printf "%s\n" "$A"; done
  elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git ls-files
  else
    # strip off the leading ./ to make the grep regexes work properly
    find . -type f | sed 's@^\./@@'
  fi
} | grep -E '(^CMake|/CMake|\.cmake$)' | grep -v -E '(\.h\.cmake|\.in|\.c)$' \
  | xargs \
  cmake-lint \
    --suppress-decorations \
    --disable \
    --line-width 132 \
    --tab-size 2 \
    --use-tabchars false \
    --disabled-codes C0113 \
    --function-pattern 'libssh2_[0-9a-z_]+' \
    --macro-pattern 'libssh2_[0-9a-z_]+' \
    --global-var-pattern '[A-Z][0-9A-Z_]+' \
    --internal-var-pattern '_[a-z][0-9a-z_]+' \
    --local-var-pattern '_[a-z][0-9a-z_]+' \
    --private-var-pattern '_[0-9a-z_]+' \
    --public-var-pattern '([A-Z][0-9A-Z_]+|[A-Z][A-Za-z0-9]+_FOUND|[a-z]+_SOURCES|prefix|exec_prefix|includedir|libdir)' \
    --argument-var-pattern '_[a-z][0-9a-z_]+' \
    --keyword-pattern '[A-Z][0-9A-Z_]+' \
    --max-conditionals-custom-parser 2 \
    --min-statement-spacing 1 \
    --max-statement-spacing 2 \
    --max-returns 6 \
    --max-branches 12 \
    --max-arguments 5 \
    --max-localvars 15 \
    --max-statements 50
