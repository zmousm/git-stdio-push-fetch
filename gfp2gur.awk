#!/usr/bin/awk -f
BEGIN {
    if (remote "x" == "x")
	exit
    cmd = gitprefix "update-ref"
}
$1 ~ /^[0-9a-f]{40}$/ {
    if ($2 == "HEAD")
	sref = "refs/remotes/" remote "/" $2
    else {
	sref = $2
	sub(/heads/, "remotes/" remote, sref)
    }
    print cmd, sref, $1
}
