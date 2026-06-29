# FFmpeg for Windows 10+ — strictly LGPL, patent-conscious build

This folder builds the **latest stable FFmpeg (8.1.2)** for **Windows 10 (x64) and
later** as **shared libraries (DLLs)**, configured to be safe for inclusion in
**closed-source** products:

* **Strictly LGPL** — built *without* `--enable-gpl` and *without*
  `--enable-nonfree`. No GPL libraries (x264, x265, Xvid, GPL-only filters) and
  no non-free libraries (libfdk-aac, etc.) are linked. Result is **LGPL v2.1 or
  later**.
* **No patent-encumbered software codecs** — the decoders and encoders that
  implement still-actively-licensed patent pools are removed at configure time
  (see below), so the shipped libraries do not themselves implement patented
  decoding/encoding.

## Files

| File | Purpose |
|------|---------|
| `build-ffmpeg-lgpl.sh` | The build script (runs in an MSYS2 **MINGW64** shell). |
| `build-ffmpeg-lgpl.cmd` | Windows launcher — sets up MINGW64 and runs the script. |
| `dist/` | Output: `bin/` (DLLs + `ffmpeg.exe`/`ffprobe.exe`/`ffplay.exe`), `include/`, `lib/`. |
| `sources/` | Downloaded source tarball + checksum. |
| `build/` | Extracted source + object files. |
| `build.log` | Full log of the last build. |

## How to build

Prerequisites are installed once via [MSYS2](https://www.msys2.org/):

```powershell
winget install MSYS2.MSYS2
```

Then, from a normal Windows prompt:

```cmd
build-ffmpeg-lgpl.cmd
```

…or directly in an **MSYS2 MINGW64** shell:

```bash
./build-ffmpeg-lgpl.sh
```

The script downloads FFmpeg, verifies its SHA-256 (best-effort against the
upstream-published value), configures, **hard-fails if GPL or non-free ever got
enabled**, compiles, installs to `dist/`, bundles the dependency DLLs into
`dist/bin`, and finally **asserts the patented decoders are absent** from the
produced binary.

### Toolchain / dependency packages

The toolchain plus the decoder libraries (TLS uses the native Windows SChannel,
no package required):

```bash
pacman -S --needed \
  make diffutils git \
  mingw-w64-x86_64-{gcc,make,nasm,yasm,pkgconf} \
  mingw-w64-x86_64-{zlib,bzip2,xz,libiconv} \
  mingw-w64-x86_64-{dav1d,libvpx,aom,opus,speex,libvorbis,openjpeg2} \
  mingw-w64-x86_64-{libjxl,libopenmpt}
```

## Licensing posture

### What "strictly LGPL" means here

FFmpeg's own code is LGPL **unless** you opt into GPL components. This build
never passes `--enable-gpl` or `--enable-nonfree`, and a guard in the script
aborts the build if `CONFIG_GPL=yes` or `CONFIG_NONFREE=yes` ever appears.
`--enable-version3` is also **not** used, so the result stays at **LGPL v2.1 or
later** rather than v3.

Because the libraries are **shared (DLLs)**, an application can dynamically link
against them and remain compliant with the LGPL by allowing the user to replace
the DLLs. If you ever switch to static linking, additional LGPL obligations
(providing relinkable object files) apply.

> You must still ship the LGPL license text and the corresponding FFmpeg source
> (or a written offer for it) with your product.

### Build profile — MAX DECODERS (decode + demux/mux for RTP/RTSP)

Tuned for an **ONVIF / RTSP-RTP receive-and-record** pipeline with the **widest
possible non-patented decoder set** (≈470 decoders). Component categories:

| Category | State |
|----------|-------|
| **Decoders** | **maximized** — every native LGPL decoder (patented set removed) **plus** LGPL/permissive external-lib decoders (below) |
| **Demuxers / Muxers** | **all kept** — RTSP, RTP, SDP, MPEG-TS, MP4/MOV, Matroska, FLV, … |
| **Parsers / bitstream filters** | kept — depacketize & remux (e.g. `h264_mp4toannexb`, `aac_adtstoasc`) |
| **Protocols** | kept — `rtp`, `rtsp`, `srtp`, `rtmp`, `udp`, `tcp`, `http`, `https`, `tls`, `file`, … |
| **Encoders** | **disabled** (`--disable-encoders`) — recording is done by stream-copy |
| **Devices** | **disabled** (`--disable-devices`) — no dshow/gdigrab capture |
| **Filters** | kept — `scale`, `format`, `aresample`, etc. |

### External decoder libraries (all LGPL or permissive)

These add decoders on top of FFmpeg's native set. Every one is **statically
linked** (see below), so they add **no DLLs**:

| Library | Adds | License |
|---------|------|---------|
| **libdav1d** | AV1 decode (fast) | BSD |
| **libvpx** | VP8 / VP9 decode | BSD |
| **libaom** | AV1 (reference) | BSD |
| **libopus** | Opus | BSD |
| **libspeex** | Speex (no native decoder) | BSD |
| **libvorbis** | Vorbis | BSD |
| **libopenjpeg** | JPEG 2000 | BSD |
| **libjxl** | JPEG XL (no native decoder) | BSD |
| **libopenmpt** | tracker modules .mod/.xm/.it/.s3m (no native) | BSD |

Plus `zlib`, `bzlib`, `lzma`, `iconv` (container/subtitle support) and **SChannel**
(native-Windows TLS for `rtsps://`/`https://`/`tls://` — no GnuTLS/crypto DLLs).
`libaribcaption` was evaluated but skipped (its MSYS2 build is shared-only and
pulls a DirectWrite font stack — irrelevant to ONVIF).

> The `dist\bin` folder still ships just the **7 FFmpeg DLLs** (`avcodec`,
> `avformat`, `avutil`, `avfilter`, `avdevice`, `swscale`, `swresample`) — every
> decoder library and the C/C++ runtime are baked in. **No `zlib1.dll`, no GCC
> runtime DLLs, no `libstdc++.dll`** (verified with `objdump -p`).

### Why only 7 DLLs — static runtime linkage

The build passes `--extra-ldflags="-static"`, which statically links the GCC
runtime (`libgcc`, `libstdc++`, `libwinpthread`) **and** all the decoder
libraries **into** each FFmpeg DLL. The FFmpeg libraries themselves stay
**shared** (`--enable-shared`), so you still get separate, replaceable `av*.dll`
(LGPL-friendly), but they carry no external runtime dependency.

#### C++ decoder libraries without a `libstdc++.dll` dependency

`libjxl` and `libopenmpt` are C++. Their MSYS2 `.pc` files omit the C++ runtime
from `Libs.private` (`libjxl_threads.pc` lists only `-lm`; `libopenmpt.pc` is
empty), so a `-static` link of FFmpeg's `pkg-config` probe fails on `std::`
symbols. This build solves it the same way **[BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds)**
does — declaring `-lstdc++` **per-library via a pkg-config overlay** (a temp
copy of those `.pc` files with `Libs.private: … -lstdc++ -ladvapi32` appended;
no system file is touched), rather than forcing it globally. Combined with
`-static`, `libstdc++` is then linked **statically**, so the FFmpeg DLLs do
**not** depend on `libstdc++.dll`. (`objdump -p avcodec-62.dll` lists only
`avutil`, `swresample`, `KERNEL32`, `msvcrt`, `ole32` — no `libstdc++`.)
`libjxl`'s headers are also compiled with `-DJXL_STATIC_DEFINE` so the static
archive is used instead of a dll-import stub.

> **Why not MSVC?** Building with MSVC (`--toolchain=msvc`) would also avoid
> shipping a runtime (it links the in-box UCRT on Windows 10+), but it does *not*
> reduce the DLL count below this, and it still requires running `./configure`
> under MSYS2 plus a full Visual C++ install and nasm. MinGW + `-static` reaches
> the same 7-DLL result with the toolchain already in place. FFmpeg's C API is
> CRT-agnostic across the DLL boundary, so these MinGW DLLs are consumed by an
> MSVC application without issue. Trade-off: `-static` gives each DLL its own
> copy of the runtime, so total on-disk size is slightly larger — but the DLL
> **count** (the goal here) is minimal.

> To re-enable encoding, remove `--disable-encoders` and add the LGPL encoder
> libraries you want (e.g. `--enable-libopus --enable-libmp3lame`).

### Deliberately **excluded** (GPL or non-free)

* **x264, x265, Xvid** — GPL → no H.264/H.265/MPEG-4-ASP *encoding* from these.
* **libfdk-aac** — non-free.
* Any GPL-only filters/devices.

### Patent-encumbered software codecs removed

Even under the LGPL, some codecs *implement* technology covered by patent pools
that are **still actively licensed**. Shipping them in a closed-source product
can create royalty exposure, so this build removes the patented **decoders**
(`--disable-decoder=…`). Encoders are moot here because **all encoders are
disabled**, but the list below documents the encoders that would otherwise be
patented:

| Family | Removed | Patent pool / holder |
|--------|---------|----------------------|
| H.264 / AVC | `h264` | Via LA (AVC) |
| H.265 / HEVC | `hevc` | Via LA / Access Advance / others |
| H.266 / VVC | `vvc` | active pools |
| VC-1 / WMV9 | `vc1`, `vc1image`, `wmv3`, `wmv3image` | MPEG-LA / Microsoft |
| MPEG-4 Part 2 (ASP) | `mpeg4`, `msmpeg4v1/2/3`, `wmv1`, `wmv2` | Via LA (MPEG-4 Visual) |
| H.263 | `h263`, `h263i`, `h263p` | MPEG-LA |
| AAC | `aac`, `aac_latm`, `aac_fixed` (+ `aac` encoder) | Via LA (AAC) |
| AC-3 / E-AC-3 / TrueHD / Dolby-E | `ac3`, `ac3_fixed`, `eac3`, `truehd`, `mlp`, `dolby_e` (+ AC-3 encoders) | Dolby |
| DTS | `dca` | DTS/Xperi |
| WMA (Windows Media Audio) | `wmav1`, `wmav2`, `wmapro`, `wmavoice`, `wmalossless` | Microsoft |
| Voice | `amrnb`, `amrwb`, `g723_1`, `g729`, `g728`, `sipr`, `qcelp`, `evrc` | VoiceAge / Via LA / Qualcomm |

The exact list is intersected against what the FFmpeg version actually provides,
so the script stays correct across versions.

**Kept** because they are royalty-free or their patents have **expired**:
VP8/VP9, AV1, Theora, Opus, Vorbis, FLAC, ALAC, **MP3** (expired 2017),
**MPEG-1/MPEG-2 video** (expired 2018), MP2, **MJPEG/JPEG** (expired),
H.261 (expired).

The removal targets the **major, actively-licensed pools** (MPEG/Via LA, Dolby,
DTS, Microsoft, the voice codecs). A handful of *obscure* codecs with some patent
history remain enabled (e.g. Sony **ATRAC1/3/9**, RealAudio **Cook**, NTT
**TwinVQ**, QDesign **QDM2**) — none appear in ONVIF/RTSP streams. If you need
them gone too, add their decoder names to `PATENT_DEC_WISH` in the build script.

### Important consequence for hardware decoding

FFmpeg's DXVA2 / D3D11VA hardware-acceleration paths attach to the corresponding
**software** decoder. Removing, e.g., the `h264` decoder also removes FFmpeg's
in-process DXVA2/D3D11VA H.264 decoding. For hardware H.264/H.265 in a shipping
app, decode through **Windows Media Foundation** instead — that uses the OS's own
codec under Windows' patent grant rather than a decoder you ship.

For an ONVIF/RTSP use case this means: FFmpeg here handles RTSP/RTP/containers,
TLS, AV1/VP9/Opus, scaling and muxing; H.264/H.265 from cameras should be decoded
via Media Foundation (or a separately-licensed decoder).

## Minimum Windows version

Configured with `-D_WIN32_WINNT=0x0A00` (Windows 10). The binaries may call
Windows 10 APIs and therefore require **Windows 10 or newer** (x64).
