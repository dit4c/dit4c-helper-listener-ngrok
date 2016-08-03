#!/bin/sh

# Write args to tempory file
TMP=$(mktemp)
for h in "$@"
do
  echo $h >> $TMP
done

cat $TMP | \
  sed -e 's/:.*$//' | \
  xargs nmap -oX - -n -sn | \
  grep -E 'srtt="[^"]*"' | sed -e 's/^.*srtt="\([^"]*\)".*$/\1/' | \
  paste - $TMP | \
  sort -n | \
  cut -f 2

rm $TMP
