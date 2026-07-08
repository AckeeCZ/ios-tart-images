# Remove gitlab-runner from image

We decided to remove `gitlab-runner` from the macos-base image.

When running jobs via [gitlab-tart-executor](https://github.com/cirruslabs/gitlab-tart-executor),
the GitLab Runner that orchestrates the run lives outside the VM. Baking a
`gitlab-runner` binary into the image risks a version mismatch between the
runner that orchestrates the run and the version installed in the image.

By not installing it, we ensure the runner version stays consistent with
whatever orchestrates the run.
