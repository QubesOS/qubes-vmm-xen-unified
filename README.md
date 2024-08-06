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

### `vault-pesign` - PEsign certificate generation helper in a vault qube

Setup manually NSS DB or use the following helper script:
```bash
#!/bin/bash
set -ex

KEYS_DIR=/home/user/keys
CERT_DB_DIR=/etc/pki/pesign

# Remove existing files and create necessary directories
rm -rf "${KEYS_DIR}" "${CERT_DB_DIR}"
mkdir -p "${KEYS_DIR}" "${CERT_DB_DIR}"

# Generate CA certificate and key
openssl req \
    -nodes \
    -new \
    -x509 \
    -newkey rsa:4096 \
    -sha256 \
    -keyout "${KEYS_DIR}/key.pem" \
    -out "${KEYS_DIR}/cert.pem" \
    -days 3650 \
    -subj "/CN=Qubes OS Unified Kernel Image Signing Key/"

# Export the key and certificate to PKCS#12 format
openssl pkcs12 \
    -export \
    -inkey "${KEYS_DIR}/key.pem" \
    -in "${KEYS_DIR}/cert.pem" \
    -name "Qubes OS Unified Kernel Image Signing Key" \
    -out "${KEYS_DIR}/secure_boot.p12" \
    -passout pass: \
    -passin pass:""

# Initialize the certificate database
certutil -d "${CERT_DB_DIR}" -N --empty-password

# Import the PKCS#12 file into the certificate database
pk12util \
    -d sql:${CERT_DB_DIR} \
    -i "${KEYS_DIR}/secure_boot.p12" \
    -W ""

# Verify the imported certificates
certutil -d "${CERT_DB_DIR}" -L

# Set ownerships
chown -R pesign:pesign "${CERT_DB_DIR}"
chmod -R 664 "${CERT_DB_DIR}"
chmod 775 "${CERT_DB_DIR}"
```

Add `user` to the group `pesign` permanently:
```bash
echo usermod -aG pesign user | sudo tee -a /rw/config/rc.local
````

### `builder-dvm` - Socket Access

Add to `/rw/config/rc.local`:
```bash
echo 'KEY_NAME="Qubes OS Unified Kernel Image Signing Key"' | sudo tee /etc/default/qubes-pesign
```

Create `/usr/local/bin/start-qubes-pesign.sh`:
```bash
#!/bin/bash
set -ex
source /etc/default/qubes-pesign
exec /usr/bin/socat UNIX-LISTEN:/var/run/qubes-pesign,fork,group=qubes,mode=660 EXEC:"/usr/bin/qrexec-client-vm vault-pesign qubes.PESign+${KEY_NAME// /__}"
```

```bash
sudo chmod +x /usr/local/bin/start-qubes-pesign.sh
```

Create the `/etc/systemd/system/qubes-pesign.service`:
```ini
[Unit]
Description=Qubes PESign Service
After=network.target

[Service]
Type=simple
EnvironmentFile=/etc/default/qubes-pesign
ExecStart=/usr/local/bin/start-qubes-pesign.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Reload and enable daemon:
```bash
sudo systemctl daemon-reload
sudo systemctl enable qubes-pesign
```

Ensure the Qubes executor `builder-dvm` has the correct RPC policy set up.

