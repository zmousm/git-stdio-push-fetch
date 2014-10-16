ssh dst-host \
  "git receive-pack /path/to/receiving-repo" \
 </tmp/justafifo | \
ssh src-host \
  "cd /path/to/source-repo; socat - EXEC:'git send-pack --all --receive-pack=\\\"socat - 5 #\\\" .',fdin=5" \
 >/tmp/justafifo
