// CocoaPods will not build a target for a pod with no sources, and without a
// target nothing links the Rust static library into the app.
//
// It also will not keep a symbol nothing references. The engine's entry points
// are all looked up by name from Dart, which the linker cannot see, so one of
// them is referenced here to keep the archive from being stripped whole.

#include <stdint.h>

extern void *je_engine_new(uint32_t sample_rate);

__attribute__((visibility("default"))) __attribute__((used))
void *junglengine_engine_keep_alive(uint32_t sample_rate) {
  return je_engine_new(sample_rate);
}
