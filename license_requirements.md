# License Requirements

Obligations for shipping this FFmpeg build inside a (closed-source) application.
This is practical guidance, not legal advice.

## What this build is

- **FFmpeg 8.1.2**, x64, **LGPL v2.1+** (built WITHOUT `--enable-gpl` and WITHOUT
  `--enable-nonfree`; no patented decoders, no x264/x265/fdk-aac).
- Shipped as **shared DLLs** (`avcodec`, `avformat`, `avutil`, `avfilter`,
  `avdevice`, `swscale`, `swresample`). Your app links them **dynamically**.
- Several BSD/MIT/permissive **and a few LGPL** libraries are **statically baked
  into** the FFmpeg DLLs (see table). TLS uses Windows SChannel (no obligation).

## Your obligations (checklist)

1. **Ship the license texts.** Include `COPYING.LGPLv2.1` (FFmpeg) and the
   copyright/permission notice of every bundled library (see table). A single
   `THIRD-PARTY-NOTICES.txt` covering all of them is fine.
2. **Provide "complete corresponding source" for the LGPL components**
   (FFmpeg + libiconv + libmpg123): the exact version source **and the build
   scripts/configure flags** used. The build configuration is part of the
   required source -- a bare upstream tarball link alone is not enough.
   - Easiest: publish this build project (scripts + pinned/mirrored sources) and
     link to it. **Host it yourself** -- a third-party link can rot, and the
     written-offer obligation lasts 3 years.
3. **Keep dynamic linking + allow replacement.** The user must be able to swap
   the `av*.dll` files for their own build. Do NOT statically link FFmpeg into
   your `.exe`. (Already satisfied by the shared-DLL design.)
4. **Add a notice in the app** (About / credits): state that it uses FFmpeg and
   the other libraries under their licenses, and give the source link.
5. **Permissive libs (BSD/MIT/Zlib): reproduce their copyright notice** in your
   distribution/docs. No source-provision duty for these, but providing it is
   cleanest.

## You do NOT have to

- Open-source **your application** code.
- Pay attention to GPL/patent-pool terms here -- no GPL code and no
  actively-licensed patented decoders are included.

## Component licenses

| Component | License | Duty |
|-----------|---------|------|
| FFmpeg (core libs) | LGPL-2.1+ | License text + **corresponding source + build config** |
| GNU libiconv (`--enable-iconv`) | LGPL-2.1+ | Same as FFmpeg (source) |
| libmpg123 (via libopenmpt) | LGPL-2.1 | Same as FFmpeg (source) |
| dav1d | BSD-2-Clause | Notice |
| libvpx | BSD-3-Clause | Notice |
| libaom | BSD-2-Clause-Patent | Notice |
| libopus, libspeex, libvorbis, libogg | BSD-3-Clause | Notice |
| OpenJPEG | BSD-2-Clause | Notice |
| libjxl | BSD-3-Clause | Notice |
| -- highway (jxl dep) | Apache-2.0 / BSD-3 | Notice |
| -- brotli (jxl dep) | MIT | Notice |
| -- lcms2 (jxl dep) | MIT | Notice |
| libopenmpt | BSD-3-Clause | Notice |
| zlib | Zlib | Notice |
| bzip2 | bzip2 (BSD-style) | Notice |
| xz / liblzma | 0BSD / public domain | Notice (optional) |
| Windows SChannel (TLS) | OS component | None |

"Notice" = include the library's copyright line + license text in your
distribution. "Source" = also make the exact source + build configuration
available (as in obligation 2).

## Minimal compliant package to ship/host

```
THIRD-PARTY-NOTICES.txt     # LGPL + all bundled libs' notices/license texts
COPYING.LGPLv2.1            # FFmpeg license
ffmpeg-8.1.2 source         # exact source (mirror it; SHA-256 in build script)
build-ffmpeg-lgpl.sh/.cmd   # the build configuration (part of "source")
```
Plus an in-app line: "Uses FFmpeg (LGPL v2.1) and other open-source libraries --
source: [vladimir-dergachyov-grse/dtt-ffmpeg-build](https://github.com/vladimir-dergachyov-grse/dtt-ffmpeg-build)".
