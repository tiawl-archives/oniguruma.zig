# oniguruma.zig

This is a fork of [kkos/oniguruma][1] to package the libonig C API for [Zig][2]

## Why this fork ?

The intention under this fork is to package [kkos/oniguruma][1] for [Zig][2]. So:
* Unnecessary files have been deleted,
* The build system has been replaced with `build.zig`,
* A cron runs every day to check [kkos/oniguruma][1]. Then it updates this repository if a new release is available.

## How to use it

The goal of this repository is not to provide a [Zig][2] binding for [kkos/oniguruma][1]. There are at least as many legit ways as possible to make a binding as there are active accounts on Github. So you are not going to find an answer for this question here. The point of this repository is to abstract the [kkos/oniguruma][1] compilation process with [Zig][2] (which is not new comers friendly and not easy to maintain) to let you focus on your application. So you can use **oniguruma.zig**:
- as raw (no available example now),
- as a daily updated interface for your [Zig][2] binding of [kkos/oniguruma][1] (no available exemple now).

## Dependencies

The [Zig][2] part of this package is relying on the latest [Zig][2] release (0.14.0) and will only be updated for the next one (so for the 0.14.1).

Here the repositories' version used by this fork:
* [kkos/oniguruma](https://github.com/tiawl/oniguruma.zig/blob/trunk/.references/oniguruma)

## CICD reminder

These repositories are automatically updated when a new release is available:
* [tiawl/libjq.zig][3]

This repository is automatically updated when a new release is available from these repositories:
* [kkos/oniguruma][1]
* [tiawl/toolbox][4]
* [tiawl/spaceporn-action-bot][5]
* [tiawl/spaceporn-action-ci][6]
* [tiawl/spaceporn-action-cd-ping][7]
* [tiawl/spaceporn-action-cd-pong][8]

## `zig build` options

These additional options have been implemented for maintainability tasks:
```
  -Dfetch   Update .references folder and build.zig.zon then stop execution
  -Dupdate  Update binding
```

## License

This repository is not subject to a unique License:

The parts of this repository originated from this repository are dedicated to the public domain. See the LICENSE file for more details.

**For other parts, it is subject to the License restrictions their respective owners choosed. By design, the public domain code is incompatible with the License notion. In this case, the License prevails. So if you have any doubt about a file property, open an issue.**

[1]:https://github.com/kkos/oniguruma
[2]:https://github.com/ziglang/zig
[3]:https://github.com/tiawl/libjq.zig
[4]:https://github.com/tiawl/toolbox
[5]:https://github.com/tiawl/spaceporn-action-bot
[6]:https://github.com/tiawl/spaceporn-action-ci
[7]:https://github.com/tiawl/spaceporn-action-cd-ping
[8]:https://github.com/tiawl/spaceporn-action-cd-pong
