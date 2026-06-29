# FFmpeg LGPL build - session context

Working dir: c:\work\onvif\ffmpeg-build  (part of an ONVIF / RTSP-RTP project)
Date: 2026-06-18

## Goal (evolved over the session)
Build the latest stable FFmpeg for Windows 10+ (x64), STRICTLY LGPL (no GPL, no
non-free), then progressively: drop patented software decoders, minimize external
libs, minimize DLL count, and finally MAXIMIZE the (non-patented) decoder set.

## Final delivered state
- FFmpeg 8.1.2 (latest stable on the 8.1 branch), x64, shared DLLs.
- License: LGPL v2.1+ (configure guard asserts CONFIG_GPL=no, CONFIG_NONFREE=no;
  --enable-version3 NOT used).
- Min Windows: 10 (-D_WIN32_WINNT=0x0A00 / -DWINVER=0x0A00).
- dist\bin ships exactly 7 DLLs: avcodec-62, avformat-62, avutil-60, avfilter-11,
  avdevice-62, swscale-9, swresample-6. NOTHING else.
  Verified via `objdump -p`: NO libstdc++.dll, libgcc_s, libwinpthread, zlib1.
- 468 decoders enabled. 0 encoders. Devices disabled.
- Demuxers/muxers/parsers/bsfs/protocols/filters: kept (RTSP/RTP/SDP, MP4/MOV,
  Matroska, MPEG-TS; rtp/rtsp/srtp/tls/http(s)/tcp/udp; h264_mp4toannexb etc.).
- TLS via native Windows SChannel (no GnuTLS / crypto DLLs).

## Build environment
- Host had NO compiler initially. Installed MSYS2 via: winget install MSYS2.MSYS2
  -> C:\msys64. Toolchain: gcc 16.1.0, nasm 3.01 (mingw-w64-x86_64-*).
- Docker present but its Linux engine was NOT running (not used).
- The MSYS2 *MINGW64* shell must be used to build.

## Key files
- build-ffmpeg-lgpl.sh   : the build script (bash, run in MSYS2 MINGW64).
- build-ffmpeg-lgpl.cmd  : Windows launcher (sets MSYSTEM=MINGW64, runs the .sh).
- README.md              : full documentation (profile, licensing, patents, C++).
- context.md             : this file.
- dist/                  : output (bin/ include/ lib/). sources/ build/ : work dirs.

## How to (re)build
From cmd/PowerShell:  build-ffmpeg-lgpl.cmd
Or in MSYS2 MINGW64:   ./build-ffmpeg-lgpl.sh
Override version:      FFMPEG_VERSION=8.2 ./build-ffmpeg-lgpl.sh
Launch pattern used here (background):
  MSYSTEM=MINGW64 /c/msys64/usr/bin/bash.exe -lc \
    '/c/work/onvif/ffmpeg-build/build-ffmpeg-lgpl.sh 2>&1 | tee build.log; exit ${PIPESTATUS[0]}'

## Decoder libraries added (all LGPL/permissive, STATICALLY linked -> no new DLL)
libdav1d (AV1), libvpx (VP8/VP9), libaom (AV1), libopus, libspeex (no native),
libvorbis, libopenjpeg (JPEG2000), libjxl (JPEG XL, no native), libopenmpt
(tracker modules, no native). Plus zlib/bzlib/lzma/iconv.
Packages: pacman -S mingw-w64-x86_64-{dav1d,libvpx,aom,opus,speex,libvorbis,
openjpeg2,libjxl,libopenmpt,zlib,bzip2,xz,libiconv} + toolchain.

## Patented DECODERS removed (PATENT_DEC_WISH in the script)
H.264 h264; H.265 hevc; H.266 vvc; VC-1/WMV vc1,vc1image,wmv3,wmv3image;
MPEG-4 ASP mpeg4,msmpeg4v1/2/3,wmv1,wmv2; H.263 h263,h263i,h263p;
AAC aac,aac_latm,aac_fixed; Dolby ac3,ac3_fixed,eac3,truehd,mlp,dolby_e;
DTS dca; WMA wmav1,wmav2,wmapro,wmavoice,wmalossless;
Voice amrnb,amrwb,g723_1,g729,g728,sipr,qcelp,evrc.
The list is intersected with `./configure --list-decoders` so unknown names
never break configure. ac3_fixed/dolby_e/WMA were caught as gaps mid-session.
NOTE: removing h264/hevc also removes FFmpeg's DXVA2/D3D11VA path for them; use
Windows Media Foundation for hardware H.264/H.265. (User chose to KEEP patented
decoders excluded; only NON-patented set was maximized.)
Obscure long-tail patented codecs still ENABLED (never in ONVIF): ATRAC1/3/9,
Cook, TwinVQ, QDM2. Add to PATENT_DEC_WISH if they must go.

## Critical technical decisions / gotchas (do not re-derive)
1. DLL count reduced WITHOUT MSVC: --extra-ldflags="-static" statically links
   libgcc/libstdc++/libwinpthread + zlib INTO the (still --enable-shared) FFmpeg
   DLLs. MSVC was evaluated and rejected: it still needs MSYS2+make to configure,
   adds a full VS install, and does NOT beat the 7-DLL result. FFmpeg's C API is
   CRT-agnostic across the DLL boundary, so MinGW DLLs link fine into MSVC apps.
2. C++ deps (libjxl, libopenmpt) without a libstdc++.dll dependency - done the
   BtbN/FFmpeg-Builds way (github.com/BtbN/FFmpeg-Builds, which also uses gcc):
   their MSYS2 .pc files omit the C++ runtime from Libs.private, so a -static
   pkg-config probe fails on std:: symbols. Fix = pkg-config OVERLAY: copy
   libjxl/libjxl_threads/libopenmpt .pc into $BUILD_DIR/pkgconfig-overlay, append
   "Libs.private: ... -lstdc++ -ladvapi32", prepend to PKG_CONFIG_PATH. No system
   file touched. (Earlier I used a global --extra-libs="-lstdc++"; replaced by the
   scoped overlay per user's steer. The .pc files use absolute prefix=/mingw64 so
   copying them is safe.)
3. libjxl headers compiled with -DJXL_STATIC_DEFINE -DJXL_THREADS_STATIC_DEFINE
   -DJXL_CMS_STATIC_DEFINE because MSYS2's libjxl is a SHARED build (its export
   headers default to __declspec(dllimport)); the defines force using the static
   .a instead of a dll-import stub. Symptom without them: undefined `__imp_*`.
4. libaribcaption (ARIB captions) was SKIPPED: its MSYS2 aribcc_config.h hardcodes
   ARIBCC_SHARED_LIBRARY=1 (shared-only headers) and it pulls a DirectWrite font
   stack - irrelevant to ONVIF. libilbc skipped too (no static .a -> breaks -static).
5. --toolchain=gcc is INVALID for FFmpeg configure (only presets like msvc/*-asan).
   Use --cc=gcc instead. ("Unknown toolchain gcc" was an early failure.)
6. `./configure --list-decoders` prints names in MULTIPLE COLUMNS - flatten with
   `tr -s ' \t\r' '\n'` before grep -qx, else intersection silently returns empty.
7. --pkg-config-flags=--static is required so pkg-config emits the full static dep
   chain (hwy/brotli for jxl, mpg123 for openmpt) for the -static link.
8. Script anchors itself: `cd "$HERE"` (HERE=dirname of BASH_SOURCE) because a
   MSYS2 login shell (bash -lc) starts in $HOME; invoke the script by ABSOLUTE path.
9. Cleanup `rm -rf "$PREFIX"` is best-effort (|| clear bin) because Windows may
   hold dist\bin (VS Code file watcher / IDE terminal cwd) -> "Device or resource
   busy". A cwd-lock blocks deletion but NOT writing, so make install still works.
   For runtime tests, copy binaries out to /tmp to avoid re-locking dist\bin.

## Verification commands (reference)
- DLLs:        ls dist/bin/*.dll   (expect 7)
- No C++ dep:  objdump -p dist/bin/avcodec-62.dll | grep "DLL Name"  (no libstdc++)
- Decoders:    ffmpeg -hide_banner -decoders   (468; h264/hevc/aac/ac3 absent)
- License:     ffmpeg -L  (LGPL); config.mak CONFIG_GPL/NONFREE must be != yes
- Arch:        PE machine 0x8664 (x64)

## Possible next steps (not done)
- If in-process H.264/H.265 decode is later required: re-enable just those
  decoders (still LGPL; patent posture is the user's call) - they were excluded.
- Tighten the obscure long-tail patented codecs (ATRAC/Cook/TwinVQ/QDM2).
- Add a real RTSP smoke test against an actual camera/stream.
