# Third-party dependencies

`ps2-native-recomp/` is a Git checkout created by `scripts/setup.ps1` and pinned to
commit `74912bd8e57c327a02242cde4df36f12e986a2c0`. It is intentionally ignored by
Git: it is upstream MIT-licensed source, not source authored in this repository.

`scripts/setup.ps1` clones the checkout, verifies the commit, downloads the pinned
native dependencies (wgpu-native, SDL2, DXC) and builds the `eerecomp`/`vurecomp`
tools. No game assets or generated C++ translations are stored here.
