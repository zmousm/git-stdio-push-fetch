#!/bin/bash

function git-pipe-push () {
    local shost spath dhost dpath
    eval $(perl -e \
'my @d = qw(s d);
for (my $i=0; $i<=1; $i++) {
  if ($ARGV[$i] =~ /^(\[[0-9A-Fa-f:]+\]|[^:]+):(.*)$/) {
    printf "%1\$shost=\"%2\$s\" %1\$spath=\"%3\$s\" ", $d[$i], $1, $2;
  }
}' "${@:1:2}")
    if [ -z "$shost" -o -z "$dhost" -o -z "$spath" -o -z "$dpath" ]; then
	return 1
    else
	shift 2
    fi
    justafifo=$(mktemp -u /tmp/gitpushpipe.XXXXXX)
    mkfifo "$justafifo"
    trap 'rm -f "$justafifo"' HUP INT QUIT TERM KILL
    ssh $shost \
	"cd $spath; socat - EXEC:'git send-pack --receive-pack=\\\"socat - 5 #\\\" /dev/null ${@//:/\:}',fdin=5" \
      <"$justafifo" | \
    ssh $dhost \
	"git receive-pack $dpath" \
      >"$justafifo"
    rc=$?
    rm -f "$justafifo"
    return $rc
}
