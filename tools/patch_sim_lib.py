#!/usr/bin/env python3
"""Give a Godot iOS export an arm64 iOS Simulator library ("arm64-to-sim").

Godot's iOS template ships the Simulator slice of libgodot.a as x86_64 only,
and the iOS Simulator on Apple Silicon runs arm64 only. The device slice is
arm64 code the Simulator can run as is; what stops the linker is the platform
each object records in its LC_BUILD_VERSION load command: PLATFORM_IOS (2)
where the Simulator needs PLATFORM_IOSSIMULATOR (7).

This copies the device archive and rewrites that one field in every arm64
Mach-O object, in place: no member changes size, so member offsets and the
archive's symbol table stay valid. Members are walked directly instead of
extracted with `ar -x`, which would lose objects that share a name.

Usage:
  patch_sim_lib.py XCFRAMEWORK...
      For each xcframework whose iOS Simulator slice has no arm64 Simulator
      code, build ios-arm64-simulator/ from the arm64 device slice, point
      Info.plist at it and remove the old Simulator slice. xcframeworks that
      already have arm64 Simulator code (MoltenVK) or no iOS libraries are
      left alone.
  patch_sim_lib.py --patch SRC DST   patch one archive or object file
  patch_sim_lib.py --check LIB       list the platforms of LIB's arm64
                                     objects; exit 1 unless all are Simulator

Files are rewritten only when their contents change, so re-runs are no-ops.
Python 3 standard library only.
"""
import os
import plistlib
import shutil
import struct
import sys
import tempfile

CPU_TYPE_ARM64 = 0x0100000C
FAT_MAGIC, FAT_MAGIC_64 = 0xCAFEBABE, 0xCAFEBABF
MACHO_64 = b"\xcf\xfa\xed\xfe"  # MH_MAGIC_64, little-endian
BITCODE = (b"BC\xc0\xde", b"\xde\xc0\x17\x0b")
AR_MAGIC = b"!<arch>\n"
LC_VERSION_MIN_IPHONEOS = 0x25
LC_BUILD_VERSION = 0x32
PLATFORM_IOS, PLATFORM_IOSSIMULATOR = 2, 7
PLATFORMS = {1: "macOS", 2: "iOS", 3: "tvOS", 4: "watchOS", 6: "Mac Catalyst",
             7: "iOS Simulator", 8: "tvOS Simulator", 9: "watchOS Simulator",
             11: "visionOS", 12: "visionOS Simulator"}
SIM_ID = "ios-arm64-simulator"
MARKER = ".made-from-device"  # marks a SIM_ID slice this tool wrote


class Report:
    def __init__(self):
        self.objects = 0      # arm64 Mach-O objects
        self.patched = 0      # rewritten from iOS to iOS Simulator
        self.platforms = {}   # LC_BUILD_VERSION platform -> objects (after patching)
        self.version_min = 0  # only LC_VERSION_MIN_IPHONEOS: needs a bigger command
        self.no_platform = 0  # no platform load command at all
        self.other_arch = 0   # Mach-O objects for another CPU (x86_64 slices)
        self.bitcode = 0      # LLVM bitcode members: cannot be patched

    def simulator_ready(self):
        return (self.objects > 0 and not self.version_min and not self.bitcode
                and set(self.platforms) <= {PLATFORM_IOSSIMULATOR})

    def __str__(self):
        parts = ["%d arm64 objects" % self.objects]
        parts += ["%d %s" % (n, PLATFORMS.get(p, "platform %d" % p))
                  for p, n in sorted(self.platforms.items())]
        if self.patched:
            parts.append("%d rewritten from iOS" % self.patched)
        parts.append("%d with only LC_VERSION_MIN_IPHONEOS" % self.version_min)
        if self.no_platform:
            parts.append("%d with no platform command" % self.no_platform)
        if self.other_arch:
            parts.append("%d for other CPUs" % self.other_arch)
        if self.bitcode:
            parts.append("%d LLVM bitcode" % self.bitcode)
        return ", ".join(parts)


def slices(data):
    """Yield (start, end) of each architecture slice; a thin file is one slice."""
    magic = struct.unpack_from(">I", data)[0] if len(data) >= 8 else 0
    if magic not in (FAT_MAGIC, FAT_MAGIC_64):
        yield 0, len(data)
        return
    pos = 8
    for _ in range(struct.unpack_from(">I", data, 4)[0]):
        if magic == FAT_MAGIC:
            offset, size = struct.unpack_from(">8xII", data, pos)
            pos += 20
        else:
            offset, size = struct.unpack_from(">8xQQ", data, pos)
            pos += 32
        yield offset, offset + size


def members(data, start, end):
    """Yield (name, offset, size) for each member of the ar archive data[start:end]."""
    pos = start + len(AR_MAGIC)
    while pos + 60 <= end:
        header = data[pos:pos + 60]
        if header[58:60] != b"`\n":
            raise ValueError("bad archive member header at byte %d" % pos)
        name = header[:16].decode("ascii", "replace").rstrip(" ")
        size = int(header[48:58].decode("ascii"))
        body = pos + 60
        if body + size > end:
            raise ValueError("archive member %r runs past the end" % name)
        if name.startswith("#1/"):  # BSD long name, stored before the data
            name_len = int(name[3:])
            name = data[body:body + name_len].rstrip(b"\0").decode("utf-8", "replace")
            yield name, body + name_len, size - name_len
        else:
            yield name, body, size
        pos = body + size + (size & 1)


def scan_object(data, off, end, name, report, patch):
    _magic, cputype, _sub, _type, ncmds, sizeofcmds = struct.unpack_from("<6I", data, off)
    if cputype != CPU_TYPE_ARM64:
        report.other_arch += 1
        return
    report.objects += 1
    pos, stop = off + 32, off + 32 + sizeofcmds
    if stop > end:
        raise ValueError("%s: load commands run past the end of the object" % name)
    platform, version_min = None, False
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from("<II", data, pos)
        if cmdsize < 8 or pos + cmdsize > stop:
            raise ValueError("%s: malformed load command at byte %d" % (name, pos - off))
        if cmd == LC_BUILD_VERSION:
            platform = struct.unpack_from("<I", data, pos + 8)[0]
            if patch and platform == PLATFORM_IOS:
                struct.pack_into("<I", data, pos + 8, PLATFORM_IOSSIMULATOR)
                platform = PLATFORM_IOSSIMULATOR
                report.patched += 1
        elif cmd == LC_VERSION_MIN_IPHONEOS:
            version_min = True
        pos += cmdsize
    if platform is not None:
        report.platforms[platform] = report.platforms.get(platform, 0) + 1
    elif version_min:
        report.version_min += 1
    else:
        report.no_platform += 1


def scan(data, patch=False):
    """Count (and with patch=True rewrite) the objects of an archive or object file."""
    report = Report()
    for start, end in slices(data):
        if data[start:start + len(AR_MAGIC)] == AR_MAGIC:
            items = members(data, start, end)
        else:
            items = [("object", start, end - start)]
        for name, off, size in items:
            magic = data[off:off + 4]
            if magic == MACHO_64:
                scan_object(data, off, off + size, name, report, patch)
            elif magic in BITCODE:
                report.bitcode += 1
    return report


def read(path):
    with open(path, "rb") as f:
        return bytearray(f.read())


def write_if_changed(path, data):
    try:
        with open(path, "rb") as f:
            if f.read() == data:
                return False
    except FileNotFoundError:
        pass
    folder = os.path.dirname(path) or "."
    os.makedirs(folder, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=folder, prefix=".patch-")
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise
    return True


def patch_file(src, dst):
    data = read(src)
    report = scan(data, patch=True)
    if not report.simulator_ready():
        raise SystemExit("%s: cannot make a Simulator library: %s" % (src, report))
    changed = write_if_changed(dst, data)
    print("%s: %s -> %s (%s)" % (os.path.basename(src), report, dst,
                                 "written" if changed else "unchanged"))


def fix_xcframework(xcf):
    xcf = xcf.rstrip("/")
    name = os.path.basename(xcf)
    info_path = os.path.join(xcf, "Info.plist")
    with open(info_path, "rb") as f:
        info = plistlib.load(f)
    libs = info.get("AvailableLibraries", [])
    ios = [lib for lib in libs if lib.get("SupportedPlatform") == "ios"]
    if not ios:
        print("%s: no iOS libraries, left alone" % name)
        return
    sims = [lib for lib in ios if lib.get("SupportedPlatformVariant") == "simulator"]
    marker = os.path.join(xcf, SIM_ID, MARKER)
    for sim in sims:
        if sim["LibraryIdentifier"] == SIM_ID and os.path.isfile(marker):
            continue  # made by this tool earlier: remade below (a no-op if current)
        rel = sim.get("BinaryPath") or sim["LibraryPath"]
        path = os.path.join(xcf, sim["LibraryIdentifier"], rel)
        if os.path.isfile(path) and "arm64" in sim.get("SupportedArchitectures", []):
            report = scan(read(path))
            if report.simulator_ready():
                print("%s: %s already has arm64 Simulator code (%s)"
                      % (name, sim["LibraryIdentifier"], report))
                return
    device = next((lib for lib in ios if not lib.get("SupportedPlatformVariant")
                   and lib.get("SupportedArchitectures") == ["arm64"]), None)
    if device is None:
        raise SystemExit("%s: no arm64-only iOS device library to start from" % name)
    rel = device.get("BinaryPath") or device["LibraryPath"]
    src = os.path.join(xcf, device["LibraryIdentifier"], rel)
    with open(src, "rb") as f:
        if f.read(len(AR_MAGIC)) != AR_MAGIC:
            raise SystemExit("%s: %s is not a static library; only those are handled"
                             % (name, rel))
    patch_file(src, os.path.join(xcf, SIM_ID, rel))
    write_if_changed(marker, b"Made from %s/%s by tools/patch_sim_lib.py\n"
                     % (device["LibraryIdentifier"].encode(), rel.encode()))

    entry ={key: device[key] for key in ("BinaryPath", "LibraryPath") if key in device}
    entry.update(LibraryIdentifier=SIM_ID, SupportedArchitectures=["arm64"],
                 SupportedPlatform="ios", SupportedPlatformVariant="simulator")
    if "HeadersPath" in device:
        entry["HeadersPath"] = device["HeadersPath"]
        headers = os.path.join(xcf, SIM_ID, device["HeadersPath"])
        shutil.rmtree(headers, ignore_errors=True)
        shutil.copytree(os.path.join(xcf, device["LibraryIdentifier"],
                                     device["HeadersPath"]), headers)
    new_libs = [lib for lib in libs if lib not in sims]
    new_libs.insert(libs.index(sims[0]) if sims else len(new_libs), entry)
    info["AvailableLibraries"] = new_libs
    changed = write_if_changed(info_path, plistlib.dumps(info))
    print("%s: Info.plist %s" % (name, "updated" if changed else "unchanged"))
    for sim in sims:
        old = os.path.join(xcf, sim["LibraryIdentifier"])
        if sim["LibraryIdentifier"] != SIM_ID and os.path.isdir(old):
            shutil.rmtree(old)
            print("%s: removed old Simulator slice %s" % (name, sim["LibraryIdentifier"]))


def main(args):
    if len(args) == 3 and args[0] == "--patch":
        patch_file(args[1], args[2])
    elif len(args) == 2 and args[0] == "--check":
        report = scan(read(args[1]))
        print("%s: %s" % (args[1], report))
        return 0 if report.simulator_ready() else 1
    elif args and not any(arg.startswith("-") for arg in args):
        for xcf in args:
            fix_xcframework(xcf)
    else:
        sys.stderr.write(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
