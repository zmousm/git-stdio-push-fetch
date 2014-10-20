git push/fetch over stdio
================

For transferring data through the `smart protocol <http://git-scm.com/book/en/Git-Internals-Transfer-Protocols>`_, git uses ``send-pack`` and ``fetch-pack``. These *plumbing* commands are a bit too smart for their own good, in the sense that they **always** need to call their peer commands (``receive-pack`` and ``upload-pack`` respectively), either on the local host or over ssh to the remote host (for ``file://`` and ``ssh://`` remotes, respectively). In some cases it may not be feasible for git to directly connect to the remote host and/or run the peer commands, or it may just be preferrable that we control the peer processes. In such cases it should still be possible to connect the two ends together, e.g. over stdio.

The git commands ``pipe-send-pack`` and ``pipe-fetch-pack`` are wrappers for the respective git commands, which do just that. These commands, along with the ``gfp2gur.awk`` script (used by ``pipe-fetch-pack``), must be installed on the systems where the target repositories live (anywhere in the PATH for a non-interactive command). The file descriptor redirection magic currently uses `socat(1) <http://www.dest-unreach.org/socat/>`_, which must also be installed on these systems. You will also need ``awk`` and ``mktemp`` for ``pipe-fetch-pack``.

The ``git_stdio_client.sh`` script contains shell functions that setup ssh connections to the sending and receiving hosts and connect the two through a bidrectional pipe. The versions ending in ``2`` expect to use the git commands above; the other versions call ``socat`` directly, so the git commands are not necessary, however these versions are messier and more complicated (but otherwise equivalent in functionality).

Having sourced the functions in your shell, you can then do::

    git-pipe-push sending-host:/path/to/source/git/repo receiving-host:/path/to/destination/git/repo
 
Or for the equivalent of a ``git fetch``::

    git-pipe-fetch receiving-host:/path/to/destination/git/repo sending-host:/path/to/source/git/repo
 
``git fetch`` operations update refs for a (potentially) *virtual* remote, whose name can be controlled through the ``--remote`` option and defaults to the ``sending-host``. If no refs are specified, they default to ``--all``.

Known issues
^^^^^^^^^^^

``receive-pack`` may close the stream too soon, which results in ``send-pack`` (the receiving end) complaining like this: ``fatal: The remote end hung up unexpectedly`` The ``socat`` wrapper may also complain for a broken pipe. As far as I understand, this is harmless. You may verify refs and objects on the receiving end, or you may also repeat the process after setting ``GIT_TRACE=1`` and/or ``GIT_TRACE_PACKET=1`` on the ``sending-host``, in order to check if the transfer completes correctly.
