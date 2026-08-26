//! The control thread, and the device it owns.
//!
//! One thread owns the cpal stream for its whole life. Every call from Dart
//! arrives here as a message rather than touching the stream directly, because
//! `cpal::Stream` is not `Send` on every backend and because opening, closing
//! and reopening a device is exactly the sort of slow, fallible thing that
//! must not happen on a caller's thread.
//!
//! The shape is `lira_graph::controller`, minus everything a phone does not
//! have: no device pickers, no input capture, no MIDI, no worker pool. One
//! output.
//!
//! One output, given back when the phone asks for it. A desktop DAW can hold
//! an output for as long as it is running; a phone takes it away for a call,
//! for another app, or when the route changes underneath it, and expects it
//! back afterwards. That is [`Engine::suspend`] and [`Engine::resume`], and it
//! is why the callback's state travels in a carrier that hands it back when
//! the stream is dropped: the plan that is loaded was published, not kept, so
//! there is no rebuilding it from here. See docs/M4.md.

use std::sync::atomic::AtomicU64;
use std::sync::mpsc::{self, Receiver, RecvTimeoutError, Sender};
use std::sync::Arc;
use std::thread::{self, JoinHandle};
use std::time::Duration;

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{ErrorKind, SampleFormat, StreamConfig};

use crate::audio::AudioSide;
use crate::command::{Command, Publication, Retired, When};
use crate::plan::Plan;
use crate::renderer::PatternRenderer;
use crate::transport::{TransportShared, DEVICE_LOST, DEVICE_OPEN, DEVICE_SUSPENDED};

/// Commands control to audio. Drained every callback, so this only has to
/// absorb one block's worth of taps.
const COMMAND_CAPACITY: usize = 256;

/// Plans in flight control to audio. An edit publishes one; the callback
/// drains every block. Deep enough to absorb a whole drag of the tempo slider
/// between two callbacks.
const PLAN_CAPACITY: usize = 32;

/// Retired plans and clips audio to control. Sized past everything that feeds
/// it so the callback's push can never fail: a failed push there would mean
/// deallocating on the audio thread.
const TRASH_CAPACITY: usize = (PLAN_CAPACITY + COMMAND_CAPACITY) * 2;

/// How often the control loop wakes to drop retired plans while idle. Also how
/// long a stream that has failed underneath us stays open before the control
/// thread closes what is left of it.
const TRASH_TICK: Duration = Duration::from_millis(200);

/// How long a caller waits for the control thread to answer a suspend or a
/// resume. Not a budget -- closing an output is immediate and opening one is
/// tens of milliseconds on both phone platforms -- but a ceiling: the caller
/// is a lifecycle callback holding the UI thread, iOS gives a backgrounding
/// app a few seconds before it suspends the process, and giving up on a device
/// that will not answer is better than being killed while waiting for it.
const REPLY_TIMEOUT: Duration = Duration::from_secs(3);

/// How long the control thread waits for the callback's state to come back
/// after a stream is dropped. It travels with the closure, which is freed as
/// part of dropping the stream, so this is a backstop rather than a wait.
const SIDE_RETURN_TIMEOUT: Duration = Duration::from_secs(2);

/// What the device is asked for. Small enough that an edit lands quickly,
/// large enough that the render loop is cheap. The device is free to give
/// something else, and CoreAudio and AAudio both do.
const PREFERRED_BLOCK_FRAMES: u32 = 512;

#[derive(Debug)]
pub enum DeviceError {
    NoOutputDevice,
    UnsupportedConfig(String),
    BuildStream(String),
    PlayStream(String),
    ControlThreadDown,
    CallbackStateLost,
}

impl std::fmt::Display for DeviceError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            DeviceError::NoOutputDevice => write!(f, "no default audio output device"),
            DeviceError::UnsupportedConfig(e) => write!(f, "unsupported output config: {e}"),
            DeviceError::BuildStream(e) => write!(f, "could not build the output stream: {e}"),
            DeviceError::PlayStream(e) => write!(f, "could not start the output stream: {e}"),
            DeviceError::ControlThreadDown => write!(f, "the audio control thread is not running"),
            DeviceError::CallbackStateLost => write!(
                f,
                "the audio callback's state did not come back from the closed stream"
            ),
        }
    }
}

impl std::error::Error for DeviceError {}

enum ControlMsg {
    Publish(Publication),
    Command(Command),

    /// Give the device back: an interruption beginning, or the app going to
    /// the background. Answered when it is actually closed, because the caller
    /// is a lifecycle callback and the platform expects it to have finished.
    Suspend(Sender<()>),

    /// Take the device again, and say what rate it opened at this time.
    Resume(Sender<Result<u32, DeviceError>>),

    Shutdown,
}

/// The engine, from the control side. Everything Dart holds a handle to.
pub struct Engine {
    to_control: Sender<ControlMsg>,
    control: Option<JoinHandle<()>>,

    /// The rate the device actually opened at, which is not always the one it
    /// was asked for: phones run their own clock and a 48 kHz device will
    /// simply say so. Everything the app decodes is resampled to this.
    sample_rate: u32,

    transport: Arc<TransportShared>,

    /// Publications so far. Stamped into each plan so the Dart side can tell
    /// which spec the playhead it is reading belongs to.
    next_plan_id: u64,
}

impl Engine {
    /// Opens the device and starts the control thread. The stream runs from
    /// here until shutdown, whether or not the sequencer is playing: that is
    /// what makes a tapped pad sound at once instead of after a stream start.
    pub fn new(requested_rate: u32, first_plan: Box<Plan>) -> Result<Engine, DeviceError> {
        let transport = Arc::new(TransportShared::default());
        let frame = Arc::new(AtomicU64::new(0));
        let (to_control, from_app) = mpsc::channel();
        let (rate_out, rate_in) = mpsc::channel();

        let control_transport = Arc::clone(&transport);
        let control_frame = Arc::clone(&frame);
        let control = thread::Builder::new()
            .name("junglengine-audio-control".into())
            .spawn(move || {
                control_loop(
                    requested_rate,
                    first_plan,
                    from_app,
                    rate_out,
                    control_transport,
                    control_frame,
                );
            })
            .map_err(|e| DeviceError::BuildStream(e.to_string()))?;

        match rate_in.recv() {
            Ok(Ok(sample_rate)) => Ok(Engine {
                to_control,
                control: Some(control),
                sample_rate,
                transport,
                next_plan_id: 1,
            }),
            Ok(Err(error)) => {
                let _ = control.join();
                Err(error)
            }
            Err(_) => Err(DeviceError::ControlThreadDown),
        }
    }

    pub fn sample_rate(&self) -> u32 {
        self.sample_rate
    }

    pub fn transport(&self) -> &Arc<TransportShared> {
        &self.transport
    }

    pub fn next_plan_id(&mut self) -> u64 {
        let id = self.next_plan_id;
        self.next_plan_id += 1;
        id
    }

    /// The id of the most recent publication. The transport reports which plan
    /// the playhead belongs to, and that is only the newest one once a queued
    /// Beat swap has actually landed.
    pub fn last_plan_id(&self) -> u64 {
        self.next_plan_id - 1
    }

    pub fn publish(&self, plan: Box<Plan>, when: When) -> Result<(), DeviceError> {
        self.send(ControlMsg::Publish(Publication { plan, when }))
    }

    pub fn command(&self, command: Command) -> Result<(), DeviceError> {
        self.send(ControlMsg::Command(command))
    }

    /// Closes the output and keeps everything else: the loaded plan, the
    /// cached audio, the rings. The transport stops, because one that was
    /// running when the output went away must not be running when it returns.
    ///
    /// Idempotent, and cheap when the device is already closed.
    pub fn suspend(&self) -> Result<(), DeviceError> {
        let (reply, answered) = mpsc::channel();
        self.send(ControlMsg::Suspend(reply))?;
        answered
            .recv_timeout(REPLY_TIMEOUT)
            .map_err(|_| DeviceError::ControlThreadDown)
    }

    /// Opens the output again, at whatever rate the device gives this time.
    ///
    /// A phone can come back on a different route than it went away on, so the
    /// rate is a result rather than a promise, the same way it is on open. The
    /// caller compares it with what it had and resamples what it has decoded
    /// if it moved.
    pub fn resume(&mut self) -> Result<u32, DeviceError> {
        let (reply, answered) = mpsc::channel();
        self.send(ControlMsg::Resume(reply))?;
        match answered.recv_timeout(REPLY_TIMEOUT) {
            Ok(Ok(rate)) => {
                self.sample_rate = rate;
                Ok(rate)
            }
            Ok(Err(error)) => Err(error),
            Err(_) => Err(DeviceError::ControlThreadDown),
        }
    }

    fn send(&self, message: ControlMsg) -> Result<(), DeviceError> {
        self.to_control
            .send(message)
            .map_err(|_| DeviceError::ControlThreadDown)
    }
}

impl Drop for Engine {
    fn drop(&mut self) {
        let _ = self.to_control.send(ControlMsg::Shutdown);
        if let Some(control) = self.control.take() {
            // Joining is what closes the device: the stream lives on that
            // thread's stack and nothing else may drop it.
            let _ = control.join();
        }
    }
}

fn control_loop(
    requested_rate: u32,
    first_plan: Box<Plan>,
    from_app: Receiver<ControlMsg>,
    rate_out: Sender<Result<u32, DeviceError>>,
    transport: Arc<TransportShared>,
    frame: Arc<AtomicU64>,
) {
    let (mut commands_tx, commands_rx) = rtrb::RingBuffer::new(COMMAND_CAPACITY);
    let (mut plans_tx, plans_rx) = rtrb::RingBuffer::new(PLAN_CAPACITY);
    let (trash_tx, mut trash_rx) = rtrb::RingBuffer::new(TRASH_CAPACITY);

    let renderer = PatternRenderer::new(first_plan);
    let audio = AudioSide::new(
        renderer,
        commands_rx,
        plans_rx,
        trash_tx,
        Arc::clone(&transport),
        Arc::clone(&frame),
        requested_rate,
    );

    let mut output = match Output::open(requested_rate, audio, Arc::clone(&transport)) {
        Ok(output) => {
            let _ = rate_out.send(Ok(output.rate));
            output
        }
        Err(error) => {
            let _ = rate_out.send(Err(error));
            return;
        }
    };

    // Whatever the callback is finished with, dropped here. Nothing below is
    // on an audio thread, so all of it is allowed to take as long as it likes.
    let drop_trash = |trash: &mut rtrb::Consumer<Retired>| while trash.pop().is_ok() {};

    loop {
        match from_app.recv_timeout(TRASH_TICK) {
            Ok(ControlMsg::Publish(publication)) => {
                // A full ring means the callback has not run since the last 32
                // edits, which on a live stream does not happen. If it ever
                // did, the newest plan is the one worth keeping and the
                // dropped one is superseded by it anyway.
                if let Err(rejected) = plans_tx.push(publication) {
                    drop(rejected);
                }
            }
            Ok(ControlMsg::Command(command)) => {
                if let Err(rejected) = commands_tx.push(command) {
                    drop(rejected);
                }
            }
            Ok(ControlMsg::Suspend(reply)) => {
                // Queued rather than done here: `playing` belongs to the
                // callback and only the callback may move it. The stop is
                // drained on the first block after the device comes back,
                // before a sample of it is rendered, so a suspend that
                // interrupted playback cannot restart it.
                if let Err(rejected) = commands_tx.push(Command::Stop) {
                    drop(rejected);
                }
                output.close();
                transport.set_device_state(DEVICE_SUSPENDED);
                // Allowed only because the stream is gone by now: while it is
                // open, the callback is the one writing this.
                transport.set_playing(false);
                let _ = reply.send(());
            }
            Ok(ControlMsg::Resume(reply)) => {
                let _ = reply.send(output.reopen_if_closed());
            }
            Ok(ControlMsg::Shutdown) => break,
            Err(RecvTimeoutError::Timeout) => {}
            Err(RecvTimeoutError::Disconnected) => break,
        }

        // A stream that failed underneath us is a dead device holding a live
        // callback. Closed here, on the thread that is allowed to close it,
        // and left closed: on a phone the reason is usually something that has
        // to finish first, so reopening in a loop would only fail in a loop.
        // Dart sees the flag and asks for the device back when the platform
        // says it can have it. See `DEVICE_LOST`.
        if output.is_open() && transport.device_state() == DEVICE_LOST {
            output.close();
            transport.set_playing(false);
        }

        drop_trash(&mut trash_rx);
    }

    // Closing the device first means the callback is not running while the
    // last plans are dropped.
    output.close();
    drop(output);
    drop_trash(&mut trash_rx);
}

/// The output, from the control thread's side: either open, or closed with the
/// callback's state parked here waiting for the next stream to carry it.
struct Output {
    /// Dropped to close the device. Declared first so it is dropped first,
    /// before the channel its closure hands the callback's state back over.
    stream: Option<cpal::Stream>,
    parked: Option<AudioSide>,
    home: Sender<AudioSide>,
    back: Receiver<AudioSide>,
    transport: Arc<TransportShared>,

    /// The rate the device last opened at, and what the next open asks for.
    rate: u32,
}

impl Output {
    fn open(
        requested_rate: u32,
        side: AudioSide,
        transport: Arc<TransportShared>,
    ) -> Result<Output, DeviceError> {
        let (home, back) = mpsc::channel();
        let mut output = Output {
            stream: None,
            parked: Some(side),
            home,
            back,
            transport,
            rate: requested_rate,
        };
        output.reopen()?;
        Ok(output)
    }

    fn is_open(&self) -> bool {
        self.stream.is_some()
    }

    /// Closes the device and takes the callback's state back off the stream.
    ///
    /// Dropping the stream drops the closure, and the closure hands the state
    /// over on its way out. Without it there is nothing to reopen with: the
    /// renderer, the plan that is loaded and the consumer ends of both rings
    /// all live in there.
    fn close(&mut self) {
        let Some(stream) = self.stream.take() else {
            return;
        };
        drop(stream);
        match self.back.recv_timeout(SIDE_RETURN_TIMEOUT) {
            Ok(side) => self.parked = Some(side),
            Err(_) => eprintln!("junglengine: the audio callback's state did not come back"),
        }
    }

    fn reopen_if_closed(&mut self) -> Result<u32, DeviceError> {
        if self.is_open() && self.transport.device_state() == DEVICE_OPEN {
            return Ok(self.rate);
        }
        self.reopen()
    }

    /// Closes whatever is open and opens the device again.
    ///
    /// The rate is asked for rather than assumed: a phone can come back on a
    /// different route than it went away on. If it does come back at another
    /// rate, the preview voice's ramps are still the old rate's -- a fraction
    /// of a millisecond either way, which is not worth rebuilding the
    /// callback's state over -- and the plan that is loaded is still the old
    /// rate's, which is not: the caller republishes after resampling what it
    /// has decoded, and the transport is stopped until it does.
    fn reopen(&mut self) -> Result<u32, DeviceError> {
        self.close();
        let Some(side) = self.parked.take() else {
            self.transport.set_device_state(DEVICE_LOST);
            return Err(DeviceError::CallbackStateLost);
        };

        match open_stream(self.rate, side, &self.home, &self.back, &self.transport) {
            Ok(open) => {
                self.stream = Some(open.stream);
                self.rate = open.sample_rate;
                self.transport.set_device_state(DEVICE_OPEN);
                Ok(open.sample_rate)
            }
            Err(error) => {
                // Whatever failed handed the state back on its way out, so a
                // later resume still has something to open with.
                self.parked = self.back.recv_timeout(SIDE_RETURN_TIMEOUT).ok();
                self.transport.set_device_state(DEVICE_LOST);
                Err(error)
            }
        }
    }
}

/// The callback's state, and its way back out of the closure.
///
/// cpal takes the data callback by value and frees it with the stream, so
/// anything the callback owns goes with it. Everything the callback owns here
/// is unrebuildable from the control thread -- the plan that is loaded was
/// published, not kept, and a ring consumer has no second end -- so it travels
/// in this and comes home when the stream is dropped.
struct SideCarrier {
    side: Option<AudioSide>,
    home: Sender<AudioSide>,
}

impl SideCarrier {
    fn process(&mut self, out: &mut [f32], frames: usize) {
        match self.side.as_mut() {
            Some(side) => side.process(out, frames),
            // Only reachable if a callback lands between the state being taken
            // and the closure being freed. Silence, rather than whatever the
            // platform left in the buffer.
            None => out.fill(0.0),
        }
    }
}

impl Drop for SideCarrier {
    fn drop(&mut self) {
        if let Some(side) = self.side.take() {
            // A failed send is shutdown: nobody is waiting for it any more, so
            // dropping it is the right thing, and the thread that dropped the
            // stream is the control thread.
            let _ = self.home.send(side);
        }
    }
}

/// The stream, and the rate it actually opened at.
struct OpenStream {
    stream: cpal::Stream,
    sample_rate: u32,
}

fn open_stream(
    requested_rate: u32,
    side: AudioSide,
    home: &Sender<AudioSide>,
    back: &Receiver<AudioSide>,
    transport: &Arc<TransportShared>,
) -> Result<OpenStream, DeviceError> {
    let host = cpal::default_host();
    let device = match host.default_output_device() {
        Some(device) => device,
        None => {
            // Handed back the way a failed build hands it back, so the caller
            // has one place to recover it from.
            let _ = home.send(side);
            return Err(DeviceError::NoOutputDevice);
        }
    };

    let mut config = match output_config(&device, requested_rate) {
        Ok(config) => config,
        Err(error) => {
            let _ = home.send(side);
            return Err(error);
        }
    };
    let sample_rate = config.sample_rate;
    let channels = config.channels as usize;

    // A short block is the whole point -- it is the delay between painting a
    // step and hearing it -- but it is a request. Some devices only run at the
    // size they have chosen, and being told no is not a reason to have no
    // audio at all.
    let stream = match build_stream(&device, config, channels, side, home, transport) {
        Ok(stream) => stream,
        Err(preferred) => {
            // The closure that failed to become a stream has already handed
            // the state back, and the second attempt needs it.
            let Ok(side) = back.recv_timeout(SIDE_RETURN_TIMEOUT) else {
                return Err(DeviceError::CallbackStateLost);
            };
            config.buffer_size = cpal::BufferSize::Default;
            match build_stream(&device, config, channels, side, home, transport) {
                Ok(stream) => stream,
                Err(_) => return Err(DeviceError::BuildStream(preferred.to_string())),
            }
        }
    };

    if let Err(error) = stream.play() {
        // Dropped rather than handed back: the state goes home with the
        // closure, which is where a failed open has to leave it.
        drop(stream);
        return Err(DeviceError::PlayStream(error.to_string()));
    }

    Ok(OpenStream {
        stream,
        sample_rate,
    })
}

fn build_stream(
    device: &cpal::Device,
    config: StreamConfig,
    channels: usize,
    side: AudioSide,
    home: &Sender<AudioSide>,
    transport: &Arc<TransportShared>,
) -> Result<cpal::Stream, cpal::Error> {
    let mut carrier = SideCarrier {
        side: Some(side),
        home: home.clone(),
    };
    let lost = Arc::clone(transport);
    device.build_output_stream(
        config,
        move |out: &mut [f32], _| {
            let frames = out.len() / channels;
            carrier.process(out, frames);
        },
        move |error| {
            // Not every error means the stream is gone, and tearing down one
            // that is still running would turn a click into a silence. A route
            // change reroutes the stream and says so, an xrun is a glitch that
            // has already happened, and a refused real time promotion is a
            // warning about the future: all three leave something that is
            // still playing. Everything else has to be rebuilt, which is not
            // something a callback may do -- so it says so, and the control
            // thread does it.
            //
            // On a phone that is a call arriving, another app taking the
            // output, or media services restarting. `audio_session` is what
            // says when to ask for the device back; this only says it went.
            match error.kind() {
                ErrorKind::DeviceChanged | ErrorKind::Xrun | ErrorKind::RealtimeDenied => {}
                _ => lost.set_device_state(DEVICE_LOST),
            }
            eprintln!("junglengine: output stream error: {error}");
        },
        None,
    )
}

/// Stereo f32 at the requested rate if the device will take it, and whatever
/// the device runs at if it will not.
///
/// A phone runs its own clock. Asking a 48 kHz device for 44.1 and being told
/// no is the normal case, not a failure: the app resamples what it decodes to
/// [`Engine::sample_rate`], so the only thing that matters is that both sides
/// agree on the number.
fn output_config(
    device: &cpal::Device,
    requested_rate: u32,
) -> Result<StreamConfig, DeviceError> {
    let supported: Vec<_> = device
        .supported_output_configs()
        .map_err(|e| DeviceError::UnsupportedConfig(e.to_string()))?
        .filter(|range| range.sample_format() == SampleFormat::F32)
        .filter(|range| range.channels() == 2)
        .collect();

    if supported.is_empty() {
        return Err(DeviceError::UnsupportedConfig(
            "no stereo f32 output config".into(),
        ));
    }

    let requested = requested_rate;
    let picked = supported
        .iter()
        .find(|range| {
            range.min_sample_rate() <= requested && requested <= range.max_sample_rate()
        })
        .map(|range| range.with_sample_rate(requested))
        .unwrap_or_else(|| {
            supported
                .iter()
                .min_by_key(|range| {
                    range
                        .max_sample_rate()
                        .abs_diff(requested_rate)
                        .min(range.min_sample_rate().abs_diff(requested_rate))
                })
                .expect("checked non-empty")
                .with_max_sample_rate()
        });

    let mut config: StreamConfig = picked.into();
    config.buffer_size = cpal::BufferSize::Fixed(PREFERRED_BLOCK_FRAMES);
    Ok(config)
}
