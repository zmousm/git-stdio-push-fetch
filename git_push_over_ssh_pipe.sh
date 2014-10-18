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
    justafifo=$(mktemp -u /tmp/gitpipe.XXXXXX)
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

function git-pipe-fetch () {
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
    justafifo=$(mktemp -u /tmp/gitpipe.XXXXXX)
    mkfifo "$justafifo"
    trap 'rm -f "$justafifo"' HUP INT QUIT TERM KILL
    ssh $shost \
	"cd $spath; export refstmp=$(mktemp -u /tmp/gitfetchpack.XXXXXXXX); socat - SYSTEM:'git fetch-pack --upload-pack=\\\"socat - 5 #\\\" --all /home/zmousm/gitest >\$refstmp',fdin=5; awk -v remote=\"${dhost}\" '\$1 ~ /^[0-9a-f]{40}$/ { if (\$2 == \"HEAD\") { sref = \"refs/remotes/\" remote \"/\" \$2; } else { sref = \$2; sub(/heads/, \"remotes/\" remote, sref); }; printf \"update-ref %s %s\\n\", sref, \$1; }' \${refstmp} | xargs -L 1 git >&2; rm \${refstmp}"\
      <"$justafifo" | \
    ssh $dhost \
	"git upload-pack $dpath" \
      >"$justafifo"
    rc=$?
    rm -f "$justafifo"
    return $rc
}
