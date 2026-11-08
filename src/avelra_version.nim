## Single framework version injected by the build from the repository VERSION.
##
## The fallback keeps direct `nim c` runs working; release builds override it
## with `-d:avelraVersion=<version>`.

const AvelraVersion* {.strdefine: "avelraVersion".} = "0.1.0"
