//! Renders a fixture spec to a raw f32 file, for the Dart parity test.
//!
//!   je_render <spec.json> <frames> <out.f32>
//!
//! The spec names the source audio it needs, so the Dart side writes the clips
//! it rendered with and this reads exactly those bytes. Nothing about the
//! source material is generated twice, which is the only way a parity test can
//! be about the mixer rather than about two noise generators agreeing.

use std::fs;
use std::io::Write;

use junglengine_engine::renderer::{Clip, PatternRenderer, Sources};
use junglengine_engine::spec::Spec;

/// Blocks, deliberately not one call: a block boundary that does not fall on a
/// step boundary is exactly where a port goes wrong.
const BLOCK: usize = 1024;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 4 {
        eprintln!("usage: je_render <spec.json> <frames> <out.f32>");
        std::process::exit(2);
    }
    let text = fs::read_to_string(&args[1]).expect("spec unreadable");
    let frames: usize = args[2].parse().expect("frames is not a number");
    let spec = Spec::from_json_str(&text).expect("spec unparseable");

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

    let mut renderer = PatternRenderer::new(spec, Sources::new(break_clip, kit_clips));
    let mut out = vec![0.0f32; frames * 2];
    let mut block = vec![0.0f32; BLOCK * 2];
    let mut done = 0usize;
    while done < frames {
        let count = BLOCK.min(frames - done);
        renderer.render(&mut block, count);
        out[done * 2..(done + count) * 2].copy_from_slice(&block[..count * 2]);
        done += count;
    }

    let mut bytes = Vec::with_capacity(out.len() * 4);
    for sample in &out {
        bytes.extend_from_slice(&sample.to_le_bytes());
    }
    let mut file = fs::File::create(&args[3]).expect("cannot write output");
    file.write_all(&bytes).expect("cannot write output");
}

fn read_clip(path: &str) -> Clip {
    let bytes = fs::read(path).unwrap_or_else(|e| panic!("cannot read {path}: {e}"));
    let mut samples = Vec::with_capacity(bytes.len() / 4);
    for chunk in bytes.chunks_exact(4) {
        samples.push(f32::from_le_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]));
    }
    Clip::new(samples)
}
