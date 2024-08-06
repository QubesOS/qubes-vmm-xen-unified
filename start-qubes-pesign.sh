#!/bin/bash
set -ex

source /etc/default/qubes-pesign

exec /usr/bin/socat UNIX-LISTEN:/var/run/qubes-pesign,fork,group=qubes,mode=660 EXEC:"/usr/bin/qrexec-client-vm vault-pesign qubes.PESign+${KEY_NAME// /__}"
