# Locked release metadata for the default DOWNLOAD provider. Every hash is for
# the complete deterministic .tar.gz bundle, not only the shared libraries.
set(GAME_ANGLE_ELECTRON_VERSION "43.1.1")
set(GAME_ANGLE_RELEASE_REPOSITORY "wiredmatt/rayplate")
set(GAME_ANGLE_RELEASE_TAG "angle-electron-v43.1.1-r2")

# Filled from the deterministic output of scripts/package_angle.py. These
# values intentionally live in source control so replacing a GitHub release
# asset cannot make CMake accept different bytes.
set(GAME_ANGLE_BUNDLE_SHA256_windows_x64 "204fe82c80e66af29dd51a6b32506cc55d2daa74520eefeec3b5a8e417ac112b")
set(GAME_ANGLE_BUNDLE_SHA256_windows_arm64 "4c067d3f6326ee85e0e04e53afa013f14dd27f1b2cf2e49f52f715d7b019788f")
set(GAME_ANGLE_BUNDLE_SHA256_linux_x64 "467400052661f8ffdfe9e643cdb2f2b3cd876c769372eb7b6c927e3c16696ee0")
set(GAME_ANGLE_BUNDLE_SHA256_linux_arm64 "a5324676623768e3d0b797b60775cb0fd28118d2566d4679bb87da7ee628c62c")
set(GAME_ANGLE_BUNDLE_SHA256_macos_x64 "cecdd619adc5da551d71662e899f5fe21396cacbbbde78726e8bd52930d2d668")
set(GAME_ANGLE_BUNDLE_SHA256_macos_arm64 "9f814df8806453b22957a9c823a3b2d1a752d0deed6aedbfaaf96d2088e0fe1f")
