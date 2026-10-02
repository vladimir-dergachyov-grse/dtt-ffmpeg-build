# License Requirements

Obligations for shipping this FFmpeg build inside a (closed-source) application.
This is practical guidance, not legal advice.

## What this build is

- **FFmpeg 8.1.2**, x64, **LGPL v2.1+** (built WITHOUT `--enable-gpl`,
  `--enable-nonfree` and `--enable-version3`; no patented decoders, no
  x264/x265/fdk-aac).
- Shipped as **shared DLLs** (`avcodec`, `avformat`, `avutil`, `avfilter`,
  `avdevice`, `swscale`, `swresample`). Your app links them **dynamically**.
- **FFmpeg is the only LGPL component.** Only permissive (BSD/MIT/Zlib/0BSD/
  Apache-2.0) libraries are statically baked into the FFmpeg DLLs (see table).
  libiconv, libopenmpt (with its libmpg123 dependency) and libva are
  deliberately excluded; `build-ffmpeg-lgpl.sh` fails if iconv or libopenmpt
  get enabled or if libiconv / libmpg123 / libopenmpt code shows up in a DLL.
- TLS uses Windows SChannel (no obligation).

## Your obligations (checklist)

1. **Ship the license texts.** Include `COPYING.LGPLv2.1` (FFmpeg) and the
   copyright/permission notice of every bundled library (see table).
   `THIRD-PARTY-NOTICES.txt` in this project covers all of them.
2. **Provide "complete corresponding source" for FFmpeg**: the exact version
   source **and the build scripts/configure flags** used. The build
   configuration is part of the required source -- a bare upstream tarball
   link alone is not enough.
   - This project is **not published**. Instead, package the exact source and
     the build scripts as a `.zip` (see "Source archive" below) and provide it
     on request under the written offer (DTT: `Docs/FFmpeg_WRITTEN_OFFER.txt`,
     request form at help.onvif.org).
   - Keep that `.zip` archived: the written offer must stay valid for at least
     3 years after the last distribution of the binaries.
3. **Keep dynamic linking + allow replacement.** The user must be able to swap
   the `av*.dll` files for their own build. Do NOT statically link FFmpeg into
   your `.exe`. (Already satisfied by the shared-DLL design.)
4. **Add a notice in the app** (About / credits / help): state that it uses
   FFmpeg and the other libraries under their licenses, and say how to obtain
   the source (the written offer).
5. **Permissive libs (BSD/MIT/Zlib): reproduce their copyright notice** in your
   distribution/docs. No source-provision duty for these.

## You do NOT have to

- Open-source **your application** code.
- Pay attention to GPL/patent-pool terms here -- no GPL code and no
  actively-licensed patented decoders are included.

## Component licenses

Libraries actually linked into the DLLs (verified with a linker map):

| Component | License | Duty |
|-----------|---------|------|
| FFmpeg (core libs) | LGPL-2.1+ | License text + **corresponding source + build config** |
| dav1d | BSD-2-Clause | Notice |
| libvpx | BSD-3-Clause | Notice |
| libaom | BSD-2-Clause (+ AOMedia Patent License 1.0) | Notice |
| libopus, libspeex, libvorbis, libogg | BSD-3-Clause | Notice |
| libjxl | BSD-3-Clause | Notice |
| -- highway (jxl dep) | Apache-2.0 / BSD-3 | Notice |
| -- brotli decoder (jxl dep) | MIT | Notice |
| zlib | Zlib | Notice |
| bzip2 | bzip2 (BSD-style) | Notice |
| xz / liblzma | 0BSD | Notice (optional) |
| GCC runtime (libgcc, libstdc++) | GPL-3.0 + GCC Runtime Library Exception | None (exception covers it) |
| mingw-w64 winpthreads | MIT AND BSD-3-Clause | Notice |
| Windows SChannel (TLS) | OS component | None |

Installed for the build but **not linked** (no code in the DLLs):

- **OpenJPEG** -- FFmpeg 8.1 only has a libopenjpeg *encoder*; encoders are
  disabled. JPEG 2000 is decoded by FFmpeg's native decoder.
- **lcms2** -- pulled in only by libjxl's pkg-config files. Its `fast_float`
  plugin is **GPL-3.0-or-later** and `lcms2.pc` puts `-llcms2_fast_float` on
  the link line, but nothing references it, so nothing is linked. Re-check
  this with a linker map (`-Wl,-Map=...`) whenever libjxl or lcms2 is updated.

"Notice" = include the library's copyright line + license text in your
distribution. "Source" = also make the exact source + build configuration
available (as in obligation 2).

## Source archive (provided under the written offer)

```
THIRD-PARTY-NOTICES.txt     # LGPL + all bundled libs' notices/license texts
COPYING.LGPLv2.1            # FFmpeg license
ffmpeg-8.1.2.tar.xz         # exact upstream source (SHA-256 in FFMPEG_BUILD.txt)
build-ffmpeg-lgpl.sh/.cmd   # the build configuration (part of "source")
README.md                   # how to build
```

Plus an in-app line: "Uses FFmpeg (LGPL v2.1) and other open-source libraries --
the corresponding source is available on request (see the FFmpeg written
offer)".
