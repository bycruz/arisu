# arisu

A painting program implemented entirely from scratch in LuaJIT.

> [!NOTE]
> The master branch is unstable and has regressed some features as it transitions from purely OpenGL to my cross-platform graphics library, [hood](https://github.com/codebycruz/hood).

## Requirements

- Linux (Recommended) or Windows
- Support for OpenGL 4.3 (you most certainly have this)
- _That's it._

There are no dependencies used by the library. Pure X11/Win32 and OpenGL.

## Goals

- [x] Fast
    - Best practices in the GPU pipeline and when writing LuaJIT code.
- [x] Written from scratch
    - **Zero** dependencies
- [x] Implement all painting operations on the GPU
    - Canvas is stored on the GPU and manipulated purely with compute shaders

## Showcase

![v4](./packages/arisu/assets/showcase/v0.4.0.png)
![v1](./packages/arisu/assets/showcase/v0.1.0.png)

## Running

1. Set up [lde](https://lde.sh) on your system.
2. Run `lde run` inside of `./packages/arisu`.

## Attributions

### Icons

Almost all of the icons are sourced from FamFamFam (Mark James)'s Silk icon set.

The rest are made by me sloppily in GIMP.

### Sound

Free sounds are sourced from [ZapSplat](https://www.zapsplat.com).
