# system-health-fedora
Simple Bash Script for Monitoring Fedora Health

```
chmod +rwx check.sh
sudo dnf install -y \
  fastfetch \
  util-linux \
  sysstat \
  pciutils \
  iproute \
  procps-ng \
  coreutils \
  findutils \
  grep \
  gawk \
  sed \
  smartmontools \
  upower \
  lm_sensors \
  lsof \
  bash-completion \
  hostname \
  lshw \
  tree \
  systemd \
  initscripts \
  util-linux-script \
  aha \
  wkhtmltopdf

```

```
sudo ./check.sh
```
or
```
sudo script -q -c "./check.sh" output.log

aha < output.log > output.html

wkhtmltopdf --enable-local-file-access output.html check.pdf
```
