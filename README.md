# Android makefile

This repo consists of a small makefile along with a very minimal android hello
world app in kotlin. Its purpose is to allow for a more comfortable
`make`-based android app development experience. It works reasonably well and
and currently extract dependencies from the Google maven repository. Note
however that no dependency resolution is done so the entire dependency tree
must be specified.
