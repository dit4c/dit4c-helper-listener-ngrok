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
  xmlstarlet sel -t -m '//host' -v 'concat(times/@srtt, "
")' | \
  paste - $TMP | \
  sort -n | \
  cut -f 2

rm $TMP
