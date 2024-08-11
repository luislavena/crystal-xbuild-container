# crystal-xbuild
> 🧪 Container image to ease cross-compilation of Crystal applications (experiment)

This repository is the companion of some posts on [my site](https://luislavena.info/writing/cross-compiling-crystal-applications-part-1/) and [part 2](https://luislavena.info/writing/cross-compiling-crystal-applications-part-2/)

## Usage

### Building container image locally

Clone this repository and build the container image:

```console
$ make build
```

This process might take a few minutes, depending on your computer performance
and internet bandwidth.

Once built, you will have `crystal-xbuild:latest` image locally, that you can
use to cross-compile your projects

### Cross-compile applications

You can use the following one-liner to cross-compile an application and have
the artifacts placed in the local `build/` directory:

```console
$ docker run --rm -v $(pwd):/app -w /app crystal-xbuild:latest xbuild examples/hello.cr hello-mac aarch64-apple-darwin
Compiling 'build/aarch64-apple-darwin/hello-mac' ('examples/hello.cr')...
Linking with: -lpcre2-8 -lgc -lpthread -levent -liconv
Done.
```

And now you have a macOS binary inside `build/aarch64-apple-darwin` directory:

```console
$ file build/aarch64-apple-darwin/hello-mac
build/aarch64-apple-darwin/hello-mac: Mach-O 64-bit executable arm64
```

### Supported platforms

At this time, the following are the only supported platforms:

* Alpine Linux: x86_64 (64bits) and aarch64 (ARM64)
* macOS: aarch64 (ARM64), SDK version 12 (Monterey)

## Contribution policy

Inspired by [Litestream](https://github.com/benbjohnson/litestream) and
[SQLite](https://sqlite.org/copyright.html#notopencontrib), this project is
open to code contributions for bug fixes only. Features carry a long-term
burden so they will not be accepted at this time.

## License

Licensed under the Apache License, Version 2.0. You may obtain a copy of
the license [here](./LICENSE).
