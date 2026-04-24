# ratarmount-vfs.yazi

[Yazi][] plugin to traverse archives as directories using a VFS managed by
[ratarmount][].

## Motivation

As of v26.1.22, Yazi does not support traversing archives as directories
(although this has been registered as a feature request in
[#51](https://github.com/sxyazi/yazi/issues/51)).

This plugin adds this functionality without needing the archives to be
decompressed.

Ratarmount was chosen over alternatives like
[archivemount](https://github.com/cybernoid/archivemount/) and
[AVFS](https://avf.sourceforge.net/) for its speed (see
[Benchmarks](https://github.com/mxmlnkn/ratarmount#benchmarks)).

## Features

Current:
* Preview

Planned:
* File icons
* Seeking in preview window
* Entering archive

See the Ratarmount docs for [Supported
Formats](https://github.com/mxmlnkn/ratarmount#supported-formats). Note that
the full version is required for use with certain formats. See
[Installation](https://github.com/mxmlnkn/ratarmount#installation) for more
details.

## Requirements

* Linux (not tested on macOS)
* [Yazi][] (obviously)
* [ratarmount][]
* `tree`: Used by preview

## Installation

Using the [Yazi package manager](https://yazi-rs.github.io/docs/cli#pm):
```sh
ya pkg add shyun3/ratarmount-vfs.yazi
```

Currently, this plugin assumes the Ratarmount-based VFS is available at
`/run/user/$UID/ratarmount`. This can be created with:
```sh
ratarmount --index-file ':memory:' --lazy -r / /run/user/$UID/ratarmount/
```

As of Ratarmount v1.2.3, some formats do not get mounted inside this VFS
despite being supported. See this
[issue](https://github.com/mxmlnkn/ratarmount/issues/190) for more details.

## Usage

### Preview

To preview archives, add the following to your `yazi.toml` (see
[Configuration](https://yazi-rs.github.io/docs/configuration/overview)):
```toml
[[plugin.prepend_previewers]]
mime = "application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip2,lzma}"
run = "ratarmount-vfs"
```
The listed formats are not exhaustive.

## Credits

* This Ratarmount issue [comment](https://github.com/mxmlnkn/ratarmount/issues/56#issuecomment-799983738)
  about creating the VFS.
* This [ranger](https://ranger.fm/) issue [comment](https://github.com/ranger/ranger/issues/456#issuecomment-798318187)
  about integrating AVFS for traversing archives.
* [Yazi preset archive plugin](https://github.com/sxyazi/yazi/blob/shipped/yazi-plugin/preset/plugins/archive.lua)
* [Yazi preset folder plugin](https://github.com/sxyazi/yazi/blob/shipped/yazi-plugin/preset/plugins/folder.lua)
* [ouch.yazi](https://github.com/ndtoan96/ouch.yazi)

## Development

This project uses the following tools and plugins:

* [LuaLS](https://luals.github.io/): See [config](/.luarc.json)
* [types.yazi](https://github.com/yazi-rs/plugins/tree/main/types.yazi): To
  provide Lua annotations for Yazi types
* [StyLua](https://github.com/JohnnyMorganz/StyLua): For Lua code formatting


[Yazi]: https://yazi-rs.github.io/
[ratarmount]: https://github.com/mxmlnkn/ratarmount
