#!/usr/bin/env bash
###############################################################################
# build-ffmpeg-lgpl.sh
#
# Builds the latest stable FFmpeg for Windows 10 (x64) and later as SHARED
# libraries (DLLs), STRICTLY under the LGPL.
#
#   * NO --enable-gpl       (excludes x264, x265, xvid, GPL filters, ...)
#   * NO --enable-nonfree   (excludes libfdk-aac, OpenSSL-linked nonfree, ...)
#   * NO --enable-version3  (keeps result at LGPL v2.1-or-later)
#
# No external codec libraries are linked (only zlib and the Windows SChannel TLS
# stack). The script aborts if GPL or non-free code is ever turned on.
#
# Run it from an MSYS2 *MINGW64* shell (the launcher .cmd sets this up):
#     ./build-ffmpeg-lgpl.sh
#
# Useful overrides (environment variables):
#     FFMPEG_VERSION=8.1.2     # which stable release to build
#     JOBS=8                   # parallel make jobs
#     PREFIX=/c/work/onvif/ffmpeg-build/dist   # install location
###############################################################################
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
FFMPEG_VERSION="${FFMPEG_VERSION:-8.1.2}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"   # a login shell may start in $HOME; anchor to the script's own dir
SRC_DIR="${SRC_DIR:-$HERE/sources}"
BUILD_DIR="${BUILD_DIR:-$HERE/build}"
PREFIX="${PREFIX:-$HERE/dist}"
JOBS="${JOBS:-$(nproc)}"

# Minimum Windows API level -> Windows 10 (0x0A00). Binaries built this way
# may call Win10 APIs and therefore require Windows 10 or newer.
WIN_MIN_NT="0x0A00"

TARBALL="ffmpeg-${FFMPEG_VERSION}.tar.xz"
URL="https://ffmpeg.org/releases/${TARBALL}"

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die()  { printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------
[ "${MSYSTEM:-}" = "MINGW64" ] || die "Run this from an MSYS2 MINGW64 shell (MSYSTEM=$MSYSTEM)."
command -v gcc        >/dev/null || die "gcc not found. Install mingw-w64-x86_64-gcc."
command -v nasm       >/dev/null || die "nasm not found. Install mingw-w64-x86_64-nasm."
command -v pkg-config >/dev/null || die "pkg-config not found. Install mingw-w64-x86_64-pkgconf."

# Start from a clean dist so no stale DLLs linger from a prior profile. This is
# best-effort: on Windows the dir can be briefly held by a file watcher / IDE
# terminal (a cwd lock blocks *deletion* but not *writing*), so don't abort the
# whole build if removal fails -- just clear the binaries we are about to replace.
rm -rf "$PREFIX" 2>/dev/null || rm -f "$PREFIX"/bin/*.dll "$PREFIX"/bin/*.exe 2>/dev/null || true
mkdir -p "$SRC_DIR" "$BUILD_DIR" "$PREFIX"

# ---------------------------------------------------------------------------
# Fetch source
# ---------------------------------------------------------------------------
log "FFmpeg ${FFMPEG_VERSION}  |  jobs=${JOBS}  |  prefix=${PREFIX}"
cd "$SRC_DIR"
if [ ! -f "$TARBALL" ]; then
    log "Downloading ${URL}"
    curl -fL --retry 3 -o "$TARBALL" "$URL"
fi
# Best-effort integrity check against the upstream-published SHA256.
if curl -fsL --retry 2 -o "${TARBALL}.sha256" "${URL}.sha256" 2>/dev/null; then
    EXP="$(tr -d '[:space:]' < "${TARBALL}.sha256")"
    GOT="$(sha256sum "$TARBALL" | cut -d' ' -f1)"
    [ "$EXP" = "$GOT" ] || die "SHA256 mismatch! expected=$EXP got=$GOT"
    log "SHA256 verified: $GOT"
else
    log "WARNING: upstream .sha256 not fetched; skipping checksum verification."
    log "Local SHA256: $(sha256sum "$TARBALL" | cut -d' ' -f1)"
fi

SRC="$BUILD_DIR/ffmpeg-${FFMPEG_VERSION}"
rm -rf "$SRC"
log "Extracting to $SRC"
tar -C "$BUILD_DIR" -xf "$TARBALL"

# ---------------------------------------------------------------------------
# Configure  (STRICTLY LGPL -- no --enable-gpl, no --enable-nonfree)
# ---------------------------------------------------------------------------
cd "$SRC"

# ---------------------------------------------------------------------------
# Patent-encumbered codecs to REMOVE.
#
# These software codecs implement technology covered by patent pools that are
# still actively licensed (e.g. Via LA AVC/HEVC/MPEG-4, Dolby, DTS), so a
# closed-source product that ships them may owe royalties. We strip the
# decoders AND encoders. Royalty-free or patent-EXPIRED codecs are kept:
#   kept: VP8/VP9, Theora, Opus, Vorbis, FLAC, ALAC,
#         MP3 (expired 2017), MP2, MPEG-1/MPEG-2 video (expired 2018),
#         MJPEG/JPEG (expired), H.261 (expired).
#
# NOTE: removing e.g. the h264 decoder also removes FFmpeg's DXVA2/D3D11VA
# hardware path for that codec (the hwaccel attaches to the SW decoder). For
# hardware H.264/H.265 in a shipping app, use Windows Media Foundation.
# ---------------------------------------------------------------------------
PATENT_DEC_WISH="h264 hevc vvc \
  mpeg4 msmpeg4v1 msmpeg4v2 msmpeg4v3 wmv1 wmv2 wmv3 wmv3image vc1 vc1image \
  h263 h263i h263p \
  aac aac_latm aac_fixed \
  ac3 ac3_fixed eac3 truehd mlp dca dolby_e \
  wmav1 wmav2 wmapro wmavoice wmalossless \
  amrnb amrwb g723_1 g729 g728 sipr qcelp evrc"
# (Encoders are ALL disabled below via --disable-encoders, so there is no
#  separate patented-encoder list to manage.)

# Intersect the wishlist with what this FFmpeg version actually provides, so
# an unknown name can never abort configure. NOTE: configure --list-* prints
# names in MULTIPLE COLUMNS, so flatten to one-name-per-line before matching.
_avail_dec="$(./configure --list-decoders 2>/dev/null | tr -s ' \t\r' '\n' | grep -v '^$' || true)"
_intersect() {  # $1 = space-separated wishlist, $2 = newline-separated available
    local item out=()
    for item in $1; do printf '%s\n' "$2" | grep -qx "$item" && out+=("$item"); done
    local IFS=,; printf '%s' "${out[*]}"
}
DISABLE_DECODERS="$(_intersect "$PATENT_DEC_WISH" "$_avail_dec")"
log "Disabling patented decoders: ${DISABLE_DECODERS:-<none>}"

log "Configuring (LGPL, shared, Windows 10+ x64, MAX decoders, no patented codecs)"

# ---------------------------------------------------------------------------
# Profile: an ONVIF / RTSP-RTP receive-record pipeline with the WIDEST possible
# non-patented NATIVE decoder coverage.
#   * Decoders ......... every native LGPL decoder (patented set removed above);
#                        NO external codec libraries are linked.
#   * Demuxers/Muxers .. ALL kept (RTSP/RTP/SDP/MPEG-TS/MP4/Matroska/...)
#   * Parsers / BSFs ... kept (depacketize & remux, e.g. h264_mp4toannexb)
#   * Protocols ........ kept (rtp, rtsp, srtp, rtmp, udp, tcp, http(s), tls...)
#   * Encoders ......... DISABLED (record via stream-copy; not needed)
#   * Devices .......... DISABLED (no dshow/gdigrab capture)
#   * Filters .......... kept (scale/format/aresample)
#
# (libiconv and libopenmpt are not used, to keep FFmpeg the ONLY LGPL component.
#  iconv is auto-detected by configure, so it must be disabled explicitly.)
# TLS uses the native Windows SChannel (no GnuTLS/crypto DLLs).
# --extra-ldflags=-static links the GCC runtime and zlib statically, so NO
# runtime DLL is added beyond FFmpeg's own and the Windows system DLLs.
# ---------------------------------------------------------------------------

# --disable-filter=gfxcapture: it is the only C++ source and would link libstdc++ statically into avfilter.
./configure \
    --disable-decoder="$DISABLE_DECODERS" \
    --disable-encoders \
    --disable-devices \
    --prefix="$PREFIX" \
    --arch=x86_64 \
    --target-os=mingw32 \
    --cc=gcc \
    --pkg-config=pkg-config \
    --pkg-config-flags=--static \
    --enable-shared \
    --disable-static \
    --disable-debug \
    --disable-doc \
    --enable-runtime-cpudetect \
    --enable-w32threads \
    --extra-cflags="-O2 -D_WIN32_WINNT=${WIN_MIN_NT} -DWINVER=${WIN_MIN_NT}" \
    --extra-ldflags="-static" \
    --enable-schannel \
    --enable-zlib \
    --disable-bzlib \
    --disable-lzma \
    --disable-iconv \
    --disable-vaapi \
    --disable-sdl2 \
    --disable-filter=gfxcapture

# ---------------------------------------------------------------------------
# License guard: hard-fail if GPL or non-free slipped in
# ---------------------------------------------------------------------------
log "Verifying license configuration"
CFG="ffbuild/config.mak"
grep -q '^CONFIG_GPL=yes'     "$CFG" && die "GPL got enabled -- aborting (strict LGPL required)."
grep -q '^CONFIG_NONFREE=yes' "$CFG" && die "Non-free got enabled -- aborting (strict LGPL required)."
log "License OK: GPL=no, non-free=no (LGPL v2.1 or later)."

# FFmpeg must stay the ONLY LGPL component: libiconv (LGPL) and libopenmpt
# (which statically drags in LGPL libmpg123) must not be linked. iconv is
# auto-detected, and an auto-detected library does NOT appear in -buildconf,
# so check the resolved configuration instead.
for lib in ICONV LIBOPENMPT; do
    grep -q "^CONFIG_${lib}=yes" "$CFG" && die "CONFIG_${lib} got enabled -- aborting (it would add an LGPL dependency)."
done
log "LGPL deps OK: iconv=no, libopenmpt=no."

# Link FFmpeg's OWN libraries (-lavutil, -lavcodec, ...) dynamically.
# --extra-ldflags=-static makes ld search only for static lib<name>.a. Our build
# tree has just the import libs (lib<name>.dll.a), so if MSYS2's own FFmpeg
# package is installed (e.g. pulled in by gst-libav) ld silently links ITS
# /mingw64/lib/libavutil.a into every DLL -- wrong code, and a link failure on
# its QSV objects. LD_LIB is only used for FFmpeg's internal libraries, so
# wrapping it in -Bdynamic/-Bstatic keeps all external libs and the GCC
# runtime static while the DLLs import avutil-60.dll etc. as intended.
grep -q '^LD_LIB=-l%$' "$CFG" || die "Unexpected LD_LIB in $CFG -- cannot apply the dynamic-internal-libs fix."
sed -i 's/^LD_LIB=-l%$/LD_LIB=-Wl,-Bdynamic -l% -Wl,-Bstatic/' "$CFG"
log "Internal FFmpeg libraries will be linked dynamically (LD_LIB patched)."

# ---------------------------------------------------------------------------
# Build & install
# ---------------------------------------------------------------------------
log "Compiling with ${JOBS} jobs"
make -j"$JOBS"
log "Installing to $PREFIX"
make install

# ---------------------------------------------------------------------------
# Bundle runtime DLLs so the dist/bin folder is redistributable
# ---------------------------------------------------------------------------
log "Bundling dependency DLLs into $PREFIX/bin"
cd "$PREFIX/bin"
# Resolve every non-system DLL the FFmpeg binaries pull in and copy it locally.
resolve() {
    for f in *.exe *.dll; do
        [ -e "$f" ] || continue
        ldd "$f" 2>/dev/null | awk '/mingw64/ {print $3}'
    done | sort -u
}
changed=1
while [ "$changed" = 1 ]; do
    changed=0
    while read -r dep; do
        [ -n "$dep" ] || continue
        base="$(basename "$dep")"
        if [ ! -f "$base" ] && [ -f "$dep" ]; then
            cp -f "$dep" .
            changed=1
        fi
    done < <(resolve)
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
log "Build complete."
echo "Binaries : $PREFIX/bin"
echo "Headers  : $PREFIX/include"
echo "Import libs / pkgconfig : $PREFIX/lib"
echo
./ffmpeg.exe -hide_banner -version | head -n 4
echo
echo "License line from build:"
./ffmpeg.exe -hide_banner -L 2>/dev/null | head -n 3 || true

# ---------------------------------------------------------------------------
# Assert the patent-encumbered decoders really are gone from the binary.
# ---------------------------------------------------------------------------
echo
log "Verifying patented decoders are absent"
DECLIST="$(./ffmpeg.exe -hide_banner -decoders 2>/dev/null)"
leak=0
for d in h264 hevc vvc vc1 aac ac3 ac3_fixed eac3 truehd dca dolby_e mpeg4 wmav2 wmapro wmavoice; do
    if printf '%s\n' "$DECLIST" | awk '{print $2}' | grep -qx "$d"; then
        echo "  STILL PRESENT: $d"; leak=1
    else
        echo "  removed: $d"
    fi
done
[ "$leak" = 0 ] || die "A patented decoder is still present -- check --disable-decoder list."
log "All targeted patented decoders confirmed absent."

# ---------------------------------------------------------------------------
# Assert no LGPL library other than FFmpeg was statically linked into the DLLs.
# FFmpeg's own source never mentions mpg123, and the symbol names of a linked
# libiconv / libmpg123 survive in the binary, so any hit means a leak.
# ---------------------------------------------------------------------------
echo
log "Verifying libiconv / libmpg123 / libopenmpt are not linked"
leak=0
for f in *.dll; do
    for s in libiconv mpg123 openmpt; do
        if grep -a -q -i "$s" "$f"; then
            echo "  FOUND '$s' in $f"; leak=1
        fi
    done
done
[ "$leak" = 0 ] || die "An LGPL dependency other than FFmpeg is linked -- check configure options."
log "No libiconv / libmpg123 / libopenmpt code in the DLLs."
