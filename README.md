# vmm-xen-unified

### Debug

Generate `build.img` that will contain `bootx64.efi` extracted from built RPM: 

```bash
sudo ./generate-boot-img.sh /path/to/built/rpm /path/to/output/dir
```

Generate QEMU dependencies in `/path/to/output/dir`:
```bash
cd /path/to/output/dir
qemu-img create -f qcow2 -F raw -b /usr/share/edk2/ovmf/OVMF_CODE.fd pflash-code-overlay0
qemu-img create -f qcow2 -F raw -b /usr/share/edk2/ovmf/OVMF_VARS.fd pflash-vars-overlay0
```

Then run QEMU as:

```bash
sudo qemu-system-x86_64 \
  -m 1024 \
  -serial stdio \
  -drive id=pflash-code-overlay0,if=pflash,file=pflash-code-overlay0,unit=0,readonly=on \
  -drive id=pflash-vars-overlay0,if=pflash,file=pflash-vars-overlay0,unit=1 \
  /path/to/output/dir/build.img
```

### Socket Access

To access the `qubes-pesign` socket, typically when building this package in a Qubes executor, create the socket with `socat` like this:
```bash
socat UNIX-LISTEN:/var/run/qubes-pesign,fork EXEC:"qrexec-client-vm vault-uki qubes.PESign"
```
where `vault-uki` is the qube holding the standard configuration for `pesign`.
Ensure the Qubes executor has the correct RPC policy.
This socat command can be placed in `/rw/config/rc.local` to run at startup.
