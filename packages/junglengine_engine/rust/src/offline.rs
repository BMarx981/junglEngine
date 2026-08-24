//! Rendering faster than real time, for WAV export.
//!
//! A port of `renderPatternOffline` in `lib/audio/soloud_engine.dart`, and it
//! exists for the reason stated there: export goes *through* the engine rather
//! than around it, so what you hear is what you export. Moving playback to
//! Rust without moving this would fork the mixer in two, which is the one
//! thing M4 must not do.
//!
//! Called on whatever thread asked for the export -- never the audio callback
//! -- so it is free to allocate.

use crate::plan::Plan;
use crate::renderer::PatternRenderer;

/// How long a ring out is given to decay past the end of the file.
const TAIL_SECONDS: f64 = 1.2;

/// Frames per pass of the render loop. Deliberately not one call: a block
/// boundary that does not fall on a step boundary is exactly where a port goes
/// wrong, so the offline path takes the same seams the live one does.
const CHUNK: usize = 4096;

/// Renders `frame_count` frames plus a tail, then folds the tail back over the
/// start. The ring out of the last hit lands where it would on the next pass,
/// which is what makes the exported file loop seamlessly.
pub fn render_offline(plan: Box<Plan>, frame_count: usize) -> Vec<f32> {
    let sample_rate = plan.spec.sample_rate as f64;
    let tail_frames = (sample_rate * TAIL_SECONDS).round() as usize;

    let mut renderer = PatternRenderer::new(plan);
    let mut scratch = vec![0.0f32; CHUNK * 2];

    let mut out = vec![0.0f32; frame_count * 2];
    render_run(&mut renderer, &mut out, frame_count, &mut scratch);

    // Keep rendering with the sequencer stopped so nothing new triggers, then
    // lay that ring out over the head of the file.
    let mut tail = vec![0.0f32; tail_frames * 2];
    renderer.begin_tail();
    render_run(&mut renderer, &mut tail, tail_frames, &mut scratch);

    let fold = tail_frames.min(frame_count);
    for i in 0..fold * 2 {
        out[i] += tail[i];
    }
    out
}

fn render_run(
    renderer: &mut PatternRenderer,
    target: &mut [f32],
    frame_count: usize,
    scratch: &mut [f32],
) {
    let mut done = 0usize;
    while done < frame_count {
        let n = CHUNK.min(frame_count - done);
        renderer.render(scratch, n);
        target[done * 2..(done + n) * 2].copy_from_slice(&scratch[..n * 2]);
        done += n;
    }
}
