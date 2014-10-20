#!/bin/bash

function git-pipe-push () {
    local shost spath dhost dpath opts=() args=() justafifo rc
    if [ $# -ge 2 ]; then
	eval $(perl -e \
'my @d = qw(s d);
for (my $i=0; $i<=1; $i++) {
  if ($ARGV[$i] =~ /^(\[[0-9A-Fa-f:]+\]|[^:]+):(.*)$/) {
    printf "%1\$shost=\"%2\$s\" %1\$spath=\"%3\$s\" ", $d[$i], $1, $2 || ".";
  }
}' "${@:1:2}")
    fi
    if [ -z "$shost" -o -z "$dhost" -o "$1" = "-h" ]; then
	echo "Usage: ${FUNCNAME[0]} sending-host:[path] receiving-host:[path] [git-send-pack options]" >&2
	[ "$1" = "-h" ] && return 0 || return 1
    else
	shift 2
    fi
    while [ -n "$1" ]; do
	case "$1" in
	    --*)
		opts+=("$1")
		;;
	    *)
		args+=("$1")
	esac
	shift
    done
    opts+=(".")
    opts+=("${args[@]}")
    justafifo=$(mktemp -u /tmp/gitpipe.XXXXXX)
    mkfifo "$justafifo"
    rc=$?
    if [ $rc -eq 0 ]; then
	trap 'rm -f "$justafifo"' HUP INT QUIT TERM KILL
    else
	return $rc
    fi
    ssh $shost \
	"cd \"$spath\";"\
	"socat - EXEC:'git send-pack --receive-pack=\\\"socat - 5 #\\\" ${opts[@]//:/\:}',fdin=5"\
      <"$justafifo" | \
    ssh $dhost \
	"git receive-pack \"$dpath\"" \
      >"$justafifo"
    rc=$?
    rm -f "$justafifo"
    return $rc
}

function git-pipe-fetch () {
    local shost spath dhost dpath remote opts=() args=() justafifo rc
    if [ $# -ge 2 ]; then
	eval $(perl -e \
'my @d = qw(s d);
for (my $i=0; $i<=1; $i++) {
  if ($ARGV[$i] =~ /^(\[[0-9A-Fa-f:]+\]|[^:]+):(.*)$/) {
    printf "%1\$shost=\"%2\$s\" %1\$spath=\"%3\$s\" ", $d[$i], $1, $2 || ".";
  }
}' "${@:1:2}")
    fi
    if [ -z "$shost" -o -z "$dhost" -o "$1" = "-h" ]; then
	echo "Usage: ${FUNCNAME[0]} receiving-host:[path] sending-host:[path] [--remote=remote_name] [git-fetch-pack options]" >&2
	[ "$1" = "-h" ] && return 0 || return 1
    else
	shift 2
    fi
    if test -n "$1" && echo "$1" | grep -q "^--remote="; then
	remote="${1#--remote=}"
	shift
    fi
    while [ -n "$1" ]; do
	case "$1" in
	    --*)
		opts+=("$1")
		;;
	    *)
		args+=("$1")
	esac
	shift
    done
    # fetch-pack apparently needs refs
    if [ -z "${args[*]}" ]; then
	opts+=("--all")
    fi
    opts+=(".")
    opts+=("${args[@]}")
    justafifo=$(mktemp -u /tmp/gitpipe.XXXXXX)
    mkfifo "$justafifo"
    rc=$?
    if [ $rc -eq 0 ]; then
	trap 'rm -f "$justafifo"' HUP INT QUIT TERM KILL
    else
	return $rc
    fi
    ssh $shost \
	"cd \"$spath\";"\
	"export refstmp=$(mktemp -u /tmp/gitfetchpack.XXXXXXXX);"\
	"socat - SYSTEM:'git fetch-pack --upload-pack=\\\"socat - 5 #\\\" ${opts[@]//:/\:} >\$refstmp',fdin=5;"\
	"awk -v remote=\"${remote:-$dhost}\""\
	"'\$1 ~ /^[0-9a-f]+$/ && length(\$1) == 40 {
		if (\$2 == \"HEAD\") { sref = \"refs/remotes/\" remote \"/\" \$2; }
		else { sref = \$2; sub(/heads/, \"remotes/\" remote, sref); };
		print \"update-ref\", sref, \$1;
	}' \${refstmp} | xargs -L 1 git;"\
	"rm \${refstmp}"\
      <"$justafifo" | \
    ssh $dhost \
	"git upload-pack \"$dpath\"" \
      >"$justafifo"
    rc=$?
    rm -f "$justafifo"
    return $rc
}

function git-pipe-push2 () {
    local shost spath dhost dpath justafifo rc
    if [ $# -ge 2 ]; then
	eval $(perl -e \
'my @d = qw(s d);
for (my $i=0; $i<=1; $i++) {
  if ($ARGV[$i] =~ /^(\[[0-9A-Fa-f:]+\]|[^:]+):(.*)$/) {
    printf "%1\$shost=\"%2\$s\" %1\$spath=\"%3\$s\" ", $d[$i], $1, $2 || ".";
  }
}' "${@:1:2}")
    fi
    if [ -z "$shost" -o -z "$dhost" -o "$1" = "-h" ]; then
	echo "Usage: ${FUNCNAME[0]} sending-host:[path] receiving-host:[path] [git-send-pack options]" >&2
	[ "$1" = "-h" ] && return 0 || return 1
    else
	shift 2
    fi
    justafifo=$(mktemp -u /tmp/gitpipe.XXXXXX)
    mkfifo "$justafifo"
    rc=$?
    if [ $rc -eq 0 ]; then
	trap 'rm -f "$justafifo"' HUP INT QUIT TERM KILL
    else
	return $rc
    fi
    ssh $shost \
	"cd \"$spath\";"\
	"git pipe-send-pack $@;"\
      <"$justafifo" | \
    ssh $dhost \
	"git receive-pack \"$dpath\"" \
      >"$justafifo"
    rc=$?
    rm -f "$justafifo"
    return $rc
}

function git-pipe-fetch2 () {
    local shost spath dhost dpath remote justafifo rc
    if [ $# -ge 2 ]; then
	eval $(perl -e \
'my @d = qw(s d);
for (my $i=0; $i<=1; $i++) {
  if ($ARGV[$i] =~ /^(\[[0-9A-Fa-f:]+\]|[^:]+):(.*)$/) {
    printf "%1\$shost=\"%2\$s\" %1\$spath=\"%3\$s\" ", $d[$i], $1, $2 || ".";
  }
}' "${@:1:2}")
    fi
    if [ -z "$shost" -o -z "$dhost" -o "$1" = "-h" ]; then
	echo "Usage: ${FUNCNAME[0]} receiving-host:[path] sending-host:[path] [--remote=remote_name] [git-fetch-pack options]" >&2
	[ "$1" = "-h" ] && return 0 || return 1
    else
	shift 2
    fi
    if test -n "$1" && echo "$1" | grep -q "^--remote="; then
	remote="${1#--remote=}"
	shift
    fi
    justafifo=$(mktemp -u /tmp/gitpipe.XXXXXX)
    mkfifo "$justafifo"
    rc=$?
    if [ $rc -eq 0 ]; then
	trap 'rm -f "$justafifo"' HUP INT QUIT TERM KILL
    else
	return $rc
    fi
    ssh $shost \
	"cd \"$spath\";"\
	"export refstmp=$(mktemp -u /tmp/gitfetchpack.XXXXXXXX);"\
	"git pipe-fetch-pack --write-refs=\${refstmp} $@;"\
	"gfp2gur.awk -v remote=\"${remote:-$dhost}\" \${refstmp} | xargs -L 1 git;"\
	"rm \${refstmp}"\
      <"$justafifo" | \
    ssh $dhost \
	"git upload-pack \"$dpath\"" \
      >"$justafifo"
    rc=$?
    rm -f "$justafifo"
    return $rc
}
