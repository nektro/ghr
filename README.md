# ghr

![loc](https://sloc.xyz/github/nektro/ghr)
[![license](https://img.shields.io/github/license/nektro/ghr.svg)](https://github.com/nektro/ghr/blob/master/LICENSE)
[![discord](https://img.shields.io/discord/551971034593755159.svg?logo=discord)](https://discord.gg/P6Y4zQC)
[![release](https://img.shields.io/github/v/release/nektro/ghr)](https://github.com/nektro/ghr/releases/latest)
[![downloads](https://img.shields.io/github/downloads/nektro/ghr/total.svg)](https://github.com/nektro/ghr/releases)
[![nektro @ github sponsors](https://img.shields.io/badge/sponsors-nektro-purple?logo=github)](https://github.com/sponsors/nektro)
[![Zig](https://img.shields.io/badge/Zig-0.14-f7a41d)](https://ziglang.org/)

Create GitHub releases and upload artifacts from the terminal.

Based on the popular https://github.com/tcnksm/ghr, brought to the world of Zig.

## Usage

```sh
$ ghr [option] TAG PATH
```

## Options

```sh
-t TOKEN        # *Set Github API Token
-u USERNAME     # *Set Github username
-r REPO         # *Set repository name
-c COMMIT       #  Set target commitish, branch or commit SHA
-n TITLE        #  Set release title
-b BODY         #  Set text describing the contents of the release
-draft          #  Release as draft (Unpublish)
-prerelease     #  Create prerelease
TAG             # *Name of the git tag to create
PATH            # *Directory that contains the artifacts to upload
```

## Installation

With [Zigmod](https://github.com/nektro/zigmod)

```sh
$ zigmod aq install 1/nektro/ghr
```

From Source

```
zigmod fetch
zig build
```
