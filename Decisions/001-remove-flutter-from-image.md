# Remove Flutter from image

We decided to remove Flutter from our image from Xcode 16.0 image and above. 
Installing a single version is not a good idea as various projects might use various versions of Flutter,
that would require having a separate image for each Flutter version which is not what we would actually want.

When we have more active Flutter projects, we will probably install [FVM](https://fvm.app). 
For now it will be project's responsibility to install correct version of Flutter when building.