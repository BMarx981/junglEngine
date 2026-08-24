//! Times the Rust mixer on a spec, for the A/B against the Dart one.
//!
//!   je_bench <spec.json> <frames> <repeats>
//!
//! Prints one line of numbers for `tool/engine_bench.dart` to read. It renders
//! in 1024 frame blocks because that is what the engine will be asked for by a
//! device, and a block that size is where the per block overhead actually
//! shows up.

use std::fs;
use std::time::Instant;

use junglengine_engine::renderer::{Clip, PatternRenderer, Sources};
use junglengine_engine::spec::Spec;

const BLOCK: usize = 1024;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 4 {
        eprintln!("usage: je_bench <spec.json> <frames> <repeats>");
        std::process::exit(2);
    }
    let text = fs::read_to_string(&args[1]).expect("spec unreadable");
    let frames: usize = args[2].parse().expect("frames is not a number");
    let repeats: usize = args[3].parse().expect("repeats is not a number");

    let json: serde_json::Value = serde_json::from_str(&text).expect("spec unparseable");
    let break_clip = read_clip(json["breakPath"].as_str().expect("no breakPath"));
    let kit_clips: Vec<Clip> = json["kitPaths"]
        .as_array()
        .map(|paths| {
            paths
                .iter()
                .map(|p| read_clip(p.as_str().expect("kit path is not a string")))
                .collect()
        })
        .unwrap_or_default();

    let mut block = vec![0.0f32; BLOCK * 2];
    let mut best = f64::INFINITY;
    let mut sink = 0.0f64;

    // One warm up pass, then the best of the repeats: the fastest run is the
    // one least disturbed by everything else on the machine.
    for run in 0..=repeats {
        let spec = Spec::from_json_str(&text).expect("spec unparseable");
        let sources = Sources::new(break_clip.clone(), kit_clips.clone());
        let mut renderer = PatternRenderer::new(spec, sources);
        let start = Instant::now();
        let mut done = 0usize;
        while done < frames {
            let count = BLOCK.min(frames - done);
            renderer.render(&mut block, count);
            // Touch the output so nothing can be optimised away.
            sink += block[0] as f64;
            done += count;
        }
        let elapsed = start.elapsed().as_secs_f64();
        if run > 0 && elapsed < best {
            best = elapsed;
        }
    }

    let sample_rate = json["sampleRate"].as_f64().unwrap_or(44100.0);
    let audio_seconds = frames as f64 / sample_rate;
    println!(
        "rust {:.6} {:.6} {:.3}",
        best,
        audio_seconds,
        sink.abs().min(0.0)
    );
}

fn read_clip(path: &str) -> Clip {
    let bytes = fs::read(path).unwrap_or_else(|e| panic!("cannot read {path}: {e}"));
    let mut samples = Vec::with_capacity(bytes.len() / 4);
    for chunk in bytes.chunks_exact(4) {
        samples.push(f32::from_le_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]));
    }
    Clip::new(samples)
}
