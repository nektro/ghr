# ghr

![loc](https://sloc.xyz/github/nektro/ghr)
[![license](https://img.shields.io/github/license/nektro/ghr.svg)](https://github.com/nektro/ghr/blob/master/LICENSE)

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

## Built With

- Zig 0.13.0

## License

MIT
