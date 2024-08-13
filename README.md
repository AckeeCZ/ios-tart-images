# iOS Tart images

Repository containing macOS images for [Tart][tart], heavily inspired by [cirruslabs/macos-image-templates](https://github.com/cirruslabs/macos-image-templates).

## Images

We currently use 2 images - [macOS base](#macos-base) and [Ackee Xcode](#ackee-xcode). Both are build and distributed using [Github Packages](https://github.com/orgs/AckeeCZ/packages?repo_name=ios-tart-images) so they can be easily pulled using [Tart][tart]. If you need to you can build them using [Packer][packer].

In general we would prefer having more images with more granular additions, but that is too time and space consuming, so we sticked with just two.

### macOS Base

Almost macOS vanilla image that adds a few things to make further image extension simple - adds [Homebrew][homebrew] and [rbenv](https://github.com/rbenv/rbenv) with some more stuff.

It is good to know that in cases of macOS pre-releases, Homebrew might be omitted as it requires Xcode Command line tools and beta releases often require beta Command line tools that are not easily accessible, in those cases will [Homebrew][homebrew] be present in the [Ackee Xcode image](#ackee-xcode).

This image is versioned based on the system version, so current (Feb 2024) macOS Sonoma is versioned as `macos-base:14.3.1`, also latest tags will point to the latest stable version available. So it is possible that tag `macos-base:14.3.1` will be moved if we need to make any changes in it, if you need to fixed version, you should use image's SHA instead of a version. Latest tag moves by design.

### Ackee Xcode

This image contains pretty much everything that is required by our stack to be installed on the machine mainly:
- Xcode
- [Carthage](https://github.com/Carthage/Carthage)
- [Mint](https://github.com/yonaskolb/Mint)
- [Tuist](https://tuist.io)
- OpenJDK for [KMP/KMM](https://kotlinlang.org/docs/multiplatform.html)
- [Flutter](https://flutter.dev)
- [ReactNative Expo](https://expo.dev)

This image is versioned based on Xcode version. Latest tag points to the latest stable version. As in [macOS-base](#macos-base) image, tags can be moved if we need to make any changes in it, for fixed version specify image's SHA. You can also use a v-prefixed tag that will ensure latest minor/bugfix version for specified major version, so using `v15` would point to latest published `15.x.x`. 

#### Build notes

To be able to build the image using [Packer][packer], you are expected to specify `xcode_version` variable and you are also expected to have `~/Downloads/Xcode_{xcode_version}.xip` downloaded.

After [Packer][packer] is installed you also need Tart plugin for [Packer][packer].

```sh
packer plugins install github.com/cirruslabs/tart
```

And finally to build this image you would run

```sh
packer build --var xcode_version=<xcode version> ackee-xcode.pkr.hcl
```

#### Publish

To publish the image to the remote so everyone on the team can use it, you have to at first login [Tart][tart] to the remote.

```sh
tart login ghcr.io
```

As a username use your Github username and as a password you need to generate new [Personal access token](https://github.com/settings/tokens).

Once you're successfully logged in just run

```sh
tart push <image>:<tag> ghcr.io/ackeecz/<image>:<tag>
```

where `<image>` is the name of the newly created image and `<tag>` is the version. It's gonna take a while, so be patient. 💪

[tart]: https://tart.run
[homebrew]: https://brew.sh
[packer]: https://www.packer.io
