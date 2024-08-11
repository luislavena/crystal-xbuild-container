FROM ghcr.io/luislavena/hydrofoil-crystal:1.12 AS base

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
        target_alpine=3.20; \
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
    # macOS (Monterey), supports only Apple Silicon (aarch64/arm64)
    { \
        pkg_path="/opt/multiarch-libs/aarch64-apple-darwin"; \
        mkdir -p $pkg_path/lib/pkgconfig; \
        # run homebrew-downloader
        crystal run /homebrew-downloader.cr -- \
            $pkg_path \
            gmp \
            libevent \
            libgc \
            libyaml \
            openssl \
            pcre2 \
            sqlite \
            zlib \
        ; \
    }

# copy macOS dependencies back into `base`
FROM base
COPY --from=macos-packages --chmod=0444 /opt/multiarch-libs/aarch64-apple-darwin /opt/multiarch-libs/aarch64-apple-darwin
