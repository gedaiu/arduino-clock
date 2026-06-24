# Running the clock server on OpenWrt (x86_64)

The server is a tiny D daemon that opens `/dev/ttyACM0` to the Arduino and drives
the meters/pixels/chimes. On an x86_64 OpenWrt box this is straightforward — the
only catch is that OpenWrt uses **musl** libc while a normal Linux build links
against **glibc**, so build a static binary.

## 1. Build a static x86_64 binary (on your dev box)

OpenWrt is musl, so build against musl and link statically. Easiest is a throwaway
Alpine (musl) container with LDC:

```sh
docker run --rm -v "$PWD":/src -w /src alpine:3.20 sh -euc '
  apk add --no-cache ldc dub gcc musl-dev
  DFLAGS="-static" dub build -b release --compiler=ldc2 --force
'
file ./clock          # expect: ELF 64-bit ... statically linked
ldd  ./clock          # expect: "not a dynamic executable"
```

The `serial-port` dependency is pure D over POSIX termios, so it builds on musl
with no extra work. If you prefer not to use Docker, a fully-static glibc build
(`DFLAGS="-static" dub build -b release`) also runs on OpenWrt — this app does no
DNS/NSS, which is the usual static-glibc pitfall.

## 2. Router: USB driver, time, files

```sh
# CDC-ACM driver (the Micro is native USB, NOT a usb-serial bridge) + USB host kmod.
opkg update
opkg install kmod-usb-acm          # plus your SoC's host kmod if needed (x86 usually built-in)
# plug the Arduino in, then confirm:
ls /dev/ttyACM*                    # -> /dev/ttyACM0
logread | grep -i cdc_acm          # -> "USB ACM device"

# Correct wall-clock time, or the chime fires on the wrong hour:
#   set timezone in LuCI (System > System) or /etc/config/system, then:
/etc/init.d/sysntpd enable && /etc/init.d/sysntpd restart
date                               # sanity check

# Install the binary + service. Stock OpenWrt (dropbear) has no scp server, so
# pipe over ssh with cat instead — works with zero extra packages:
cat ./clock              | ssh root@router "cat > /usr/bin/clock && chmod +x /usr/bin/clock"
cat ./openwrt/clock.init | ssh root@router "cat > /etc/init.d/clock && chmod +x /etc/init.d/clock"
# (alternatives: `opkg install openssh-sftp-server` then scp; or `scp -O`; or
#  wget from an HTTP server on your dev box; or copy via a USB stick.)
```

To survive a firmware **sysupgrade** (a reboot is fine without this), keep the files:

```sh
ssh root@router 'echo /usr/bin/clock >> /etc/sysupgrade.conf; echo /etc/init.d/clock >> /etc/sysupgrade.conf'
```

## 3. Start it

```sh
ssh root@router '/etc/init.d/clock enable && /etc/init.d/clock start'
logread -e clock                   # should show "connecting to:" then "connected."
ps | grep clock
```

Kill the pid to confirm procd respawns it.

## Notes / things to verify on your hardware

- **Timezone on musl**: musl handles `TZ`/zoneinfo differently from glibc. After
  deploy, confirm the chime actually fires on the correct local hour. If not, set
  `TZ` via the commented `procd_set_param env` line in `clock.init`.
- **Cold-boot hotplug**: on some boards `/dev/ttyACM0` isn't created if the Arduino
  is already plugged in at power-on (OpenWrt #21914). The `wait_for_serial` poll
  covers most cases; an `/etc/hotplug.d/tty/` trigger is the fallback.
- **Reflashing the Arduino**: while it's on the router, `flash.sh` (which expects
  arduino-cli + the board on your dev box) won't reach it. Either unplug it to the
  dev box to flash, or `/etc/init.d/clock stop` before flashing if you put
  arduino-cli on the router.
