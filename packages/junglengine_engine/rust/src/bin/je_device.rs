//! Plays a pattern out of the real device, through the real engine.
//!
//!   je_device [seconds]
//!
//! The smoke test for stage 2's first question: does cpal actually open an
//! output and pull blocks from our callback on this platform? It goes through
//! `Engine`, so a pass here is the control thread, the plan ring, the trash
//! ring, the renderer and the device all working together, which is a good
//! deal more than a sine proves.
//!
//! It also runs stage 5's leg: the device given back and taken again, which
//! is a thing a phone does constantly and a desk never does.
//!
//! On macOS this runs from a terminal. On a phone the app itself is this test:
//! `LiraAudioEngine` is the same path with Dart on the other end of the FFI.

use std::time::Duration;

use junglengine_engine::command::{Command, When};
use junglengine_engine::device::Engine;
use junglengine_engine::plan::{Clip, Plan, Sources};
use junglengine_engine::spec::Spec;

const RATE: u32 = 44100;
const BPM: f64 = 172.0;

fn main() {
    let seconds: u64 = std::env::args()
        .nth(1)
        .and_then(|a| a.parse().ok())
        .unwrap_or(4);

    let break_clip = source_break();
    let spec = Spec::from_json_str(&spec_json()).expect("the fixture spec should parse");
    let plan = Plan::new(1, spec, Sources::new(break_clip, Vec::new()));

    let mut engine = match Engine::new(RATE, plan) {
        Ok(engine) => engine,
        Err(error) => {
            eprintln!("je_device: could not open the output: {error}");
            std::process::exit(1);
        }
    };
    println!("je_device: device open at {} Hz", engine.sample_rate());

    engine.command(Command::Start).expect("engine is running");
    std::thread::sleep(Duration::from_secs(seconds));

    // Republishing under a running transport is the thing the whole stage is
    // for, so the smoke test does it: half way through, the tempo moves and
    // the bar keeps playing.
    let faster = Spec::from_json_str(&spec_json().replace(&BPM.to_string(), "150"))
        .expect("the fixture spec should parse");
    let sources = Sources::new(source_break(), Vec::new());
    engine
        .publish(Plan::new(2, faster, sources), When::Now)
        .expect("engine is running");
    std::thread::sleep(Duration::from_secs(1));

    let transport = std::sync::Arc::clone(engine.transport());
    println!(
        "je_device: {} frames rendered, step {}",
        transport.frame.load(std::sync::atomic::Ordering::Relaxed),
        transport.step.load(std::sync::atomic::Ordering::Relaxed),
    );

    // Stage 5's question, which a phone asks constantly and a desk never does:
    // give the device back, take it again, and carry on with the plan that was
    // already loaded. Audible as a gap and then the same pattern, from the top
    // -- a suspend stops the transport, because one that was running when the
    // output went away must not be running when it comes back.
    engine.suspend().expect("the device gives up cleanly");
    println!("je_device: suspended, output closed");
    std::thread::sleep(Duration::from_secs(1));

    let before = transport.frame.load(std::sync::atomic::Ordering::Relaxed);
    let rate = engine.resume().expect("the device comes back");
    engine.command(Command::Start).expect("engine is running");
    std::thread::sleep(Duration::from_secs(2));
    println!(
        "je_device: resumed at {rate} Hz, {} frames since",
        transport.frame.load(std::sync::atomic::Ordering::Relaxed) - before,
    );

    engine.command(Command::Stop).expect("engine is running");
    std::thread::sleep(Duration::from_millis(200));
}

fn spec_json() -> String {
    format!(
        r#"{{"sampleRate":{RATE},"bpm":{BPM},"sections":[{{"beat":{{
            "id":"smoke","sliceCount":16,"swing":0.58,
            "chop":[0,4,{{"s":8,"m":"rev"}},12,0,{{"s":6,"m":"ret"}},8,null,
                    0,4,{{"s":10,"m":"half"}},12,0,6,{{"s":14,"m":"pd"}},15],
            "sub":[{{"n":0}},{{"t":true}},{{}},{{}},{{"n":5,"a":true}},{{}},{{}},{{}},
                   {{"n":-2}},{{"t":true}},{{}},{{}},{{"n":7}},{{}},{{}},{{}}]
        }}}}]}}"#
    )
}

/// A stand in for a break: noise bursts under a rising tone, so every slice
/// sounds different and a wrong slice is audible rather than merely wrong.
fn source_break() -> Clip {
    let frames = (RATE as f64 * 4.0 * 60.0 / BPM).round() as usize;
    let mut samples = vec![0.0f32; frames * 2];
    let mut state: i64 = 12345;
    let mut phase = 0.0f64;
    for f in 0..frames {
        state = (state.wrapping_mul(1103515245).wrapping_add(12345)) & 0x7fff_ffff;
        let noise = state as f64 / 0x4000_0000u32 as f64 - 1.0;
        let hit = f * 16 / frames;
        let into = (f as f64 * 16.0 / frames as f64) - hit as f64;
        let env = (1.0 - into) * (1.0 - into);
        phase += (55.0 + hit as f64 * 7.0) / RATE as f64;
        if phase >= 1.0 {
            phase -= 1.0;
        }
        let tone = 4.0 * (phase - 0.5).abs() - 1.0;
        let value = ((0.55 * noise + 0.45 * tone) * env * 0.8) as f32;
        samples[f * 2] = value;
        samples[f * 2 + 1] = value * 0.92;
    }
    Clip::new(samples)
}
