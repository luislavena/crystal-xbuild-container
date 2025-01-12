FROM ghcr.io/luislavena/hydrofoil-crystal:1.15 AS base

# install cross-compiler (Zig)
RUN --mount=type=cache,sharing=private,target=/var/cache/apk \
    --mount=type=tmpfs,target=/tmp \
    set -eux -o pipefail; \
    # Tools to extract Zig
    { \
        apk add \
            file \
            tar \
            xz \
        ; \
    }; \
    # Zig
    { \
        cd /tmp; \
        mkdir -p /opt/zig; \
        export ZIG_VERSION=0.13.0; \
        case "$(arch)" in \
        x86_64) \
            export \
                ZIG_ARCH=x86_64 \
                ZIG_SHA256=d45312e61ebcc48032b77bc4cf7fd6915c11fa16e4aad116b66c9468211230ea \
            ; \
            ;; \
        aarch64) \
            export \
                ZIG_ARCH=aarch64 \
                ZIG_SHA256=041ac42323837eb5624068acd8b00cd5777dac4cf91179e8dad7a7e90dd0c556 \
            ; \
            ;; \
        esac; \
        wget -q -O zig.tar.xz https://ziglang.org/download/${ZIG_VERSION}/zig-linux-${ZIG_ARCH}-${ZIG_VERSION}.tar.xz; \
        echo "${ZIG_SHA256} *zig.tar.xz" | sha256sum -c - >/dev/null 2>&1; \
        tar -C /opt/zig --strip-components=1 -xf zig.tar.xz; \
        rm zig.tar.xz; \
        # symlink executable
        ln -nfs /opt/zig/zig /usr/local/bin; \
    }; \
    # smoke check
    [ "$(command -v zig)" = '/usr/local/bin/zig' ]; \
    zig version; \
    zig cc --version

# ---
# Alpine Linux

# install multi-arch libraries
RUN --mount=type=cache,sharing=private,target=/var/cache/apk \
    --mount=type=tmpfs,target=/tmp \
    set -eux -o pipefail; \
    # Alpine Linux: download and extract packages for each arch
    { \
        supported_arch="aarch64 x86_64"; \
        target_alpine=3.21; \
        cd /tmp; \
        for target_arch in $supported_arch; do \
            target_path="/tmp/$target_arch-apk-chroot"; \
            mkdir -p $target_path/etc/apk; \
            # patch apk repositories to $target_alpine version
            sed -E "s/v\d\.\d+/v$target_alpine/g" /etc/apk/repositories | tee $target_path/etc/apk/repositories; \
            # use apk to download the specific packages
            apk add --root $target_path --arch $target_arch --initdb --no-cache --no-scripts --allow-untrusted \
                gc-dev \
                gmp-dev \
                libevent-dev \
                libevent-static \
                libsodium-dev \
                libsodium-static \
                libxml2-dev \
                libxml2-static \
                openssl-dev \
                openssl-libs-static \
                pcre2-dev \
                sqlite-dev \
                sqlite-static \
                yaml-dev \
                yaml-static \
                zlib-dev \
                zlib-static \
            ; \
            pkg_path="/opt/multiarch-libs/$target_arch-linux-musl"; \
            mkdir -p $pkg_path/lib/pkgconfig; \
            # copy the static libs & .pc files
            cp $target_path/usr/lib/*.a $pkg_path/lib/; \
            cp $target_path/usr/lib/pkgconfig/*.pc $pkg_path/lib/pkgconfig/; \
        done; \
    }

# ---
# macOS

# install macOS dependencies in separate target
FROM base AS macos-packages
COPY ./scripts/homebrew-downloader.cr /homebrew-downloader.cr

RUN --mount=type=cache,sharing=private,target=/var/cache/apk \
    --mount=type=tmpfs,target=/tmp \
    set -eux -o pipefail; \
    # macOS (Ventura), supports only Apple Silicon (aarch64/arm64)
    { \
        pkg_path="/opt/multiarch-libs/aarch64-apple-darwin"; \
        crystal run /homebrew-downloader.cr -- \
            $pkg_path \
            gmp \
            libevent \
            libgc \
            libiconv \
            libsodium \
            libxml2 \
            libyaml \
            openssl@3 \
            pcre2 \
            sqlite \
            zlib \
        ; \
    }

# copy macOS dependencies back into `base`
FROM base
COPY --from=macos-packages /opt/multiarch-libs/aarch64-apple-darwin /opt/multiarch-libs/aarch64-apple-darwin

# install macOS SDK
RUN --mount=type=cache,sharing=private,target=/var/cache/apk \
    --mount=type=tmpfs,target=/tmp \
    set -eux -o pipefail; \
    { \
        cd /tmp; \
        export \
            MACOS_SDK_VERSION=13.3 \
            MACOS_SDK_MAJOR_VERSION=13 \
            MACOS_SDK_SHA256=518e35eae6039b3f64e8025f4525c1c43786cc5cf39459d609852faf091e34be \
        ; \
        wget -q -O sdk.tar.xz https://github.com/joseluisq/macosx-sdks/releases/download/${MACOS_SDK_VERSION}/MacOSX${MACOS_SDK_VERSION}.sdk.tar.xz; \
        echo "${MACOS_SDK_SHA256} *sdk.tar.xz" | sha256sum -c - >/dev/null 2>&1; \
        tar -C /opt/multiarch-libs -xf sdk.tar.xz --no-same-owner; \
        rm sdk.tar.xz; \
        # symlink to latest version
        ln -nfs /opt/multiarch-libs/MacOSX${MACOS_SDK_VERSION}.sdk /opt/multiarch-libs/MacOSX${MACOS_SDK_MAJOR_VERSION}.sdk; \
    }

# copy xbuild helper
COPY ./scripts/xbuild.sh /usr/local/bin/xbuild
