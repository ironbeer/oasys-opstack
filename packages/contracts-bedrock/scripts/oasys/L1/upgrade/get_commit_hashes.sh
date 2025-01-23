#!/bin/bash
#
# Description:
#   Searches through git history to find the commit where a file's
#   content matches a target MD5 hash.
#
# Usage:
#   bash ./scripts/oasys/L1/upgrade/get_commit_hashes.sh src/L1/L1CrossDomainMessenger.sol
#


# Target file to search through git history
FILE="$1"

# Get MD5 hash of target file using available command
if which md5 >/dev/null; then
  md5cmd=md5
elif which md5sum >/dev/null; then
  md5cmd=md5sum
else
  echo "MD5 command not found"
  exit 1
fi

src_hash="$(cat $FILE | $md5cmd)"
echo "md5: $src_hash"

# Find commit ID by comparing file content hashes
for commit in $(git log --format='%H' "$FILE"); do
  if git show "${commit}:packages/contracts-bedrock/${FILE}" | $md5cmd | grep -q $src_hash; then
    echo "commit: $commit"
  fi
done
