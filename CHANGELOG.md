## 0.1.0

- Initial public release.
- Add Unicode-aware Noto lookup, including available skin-tone variants.
- Bundle 881 Noto JSON animations and an independent Google metadata catalog for
  offline playback, without a dependency on another animated-emoji package.
- Add lifecycle-aware vector and raster playback with static fallbacks.
- Cross-fade loaded content from its placeholder with reduced-motion support.
- Decode vector content in a bounded background queue on native platforms.
- Defer loading during scrolling and avoid per-tick Lottie widget rebuilds.
- Add bounded byte and composition caches with optional native persistence.
- Add configurable local catalogs, paginated search and an embeddable picker.
- Add explicit Noto artwork (CC BY 4.0) and catalog (Apache-2.0) attribution.
