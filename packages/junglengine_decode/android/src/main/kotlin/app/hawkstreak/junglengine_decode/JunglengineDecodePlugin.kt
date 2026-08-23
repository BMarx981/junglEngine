package app.hawkstreak.junglengine_decode

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors

/**
 * Decodes audio files to interleaved 32 bit float PCM with MediaCodec.
 *
 * MediaExtractor plus MediaCodec is the only way to get PCM out of a compressed
 * file on Android without shipping a decoder, and it covers MP3, M4A, AAC,
 * FLAC, Ogg and WAV with the hardware decoders the phone already has.
 */
class JunglengineDecodePlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel

    /** Decoding is seconds of work, and the platform thread is the UI's. */
    private val worker = Executors.newSingleThreadExecutor()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "junglengine_decode")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        if (call.method != "decodeFile") {
            result.notImplemented()
            return
        }
        val path = call.argument<String>("path")
        if (path == null) {
            result.error("bad_arguments", "decodeFile needs a path", null)
            return
        }
        val maxFrames = call.argument<Int>("maxFrames") ?: 0

        worker.execute {
            try {
                postSuccess(result, decode(path, maxFrames))
            } catch (error: Exception) {
                postError(result, error)
            }
        }
    }

    private fun postSuccess(
        result: Result,
        value: Map<String, Any>
    ) {
        android.os.Handler(android.os.Looper.getMainLooper()).post { result.success(value) }
    }

    private fun postError(
        result: Result,
        error: Exception
    ) {
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            result.error("decode_failed", error.message ?: error.toString(), null)
        }
    }

    private fun decode(
        path: String,
        maxFrames: Int
    ): Map<String, Any> {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            extractor.setDataSource(path)
            val track = audioTrackOf(extractor)
                ?: throw IllegalArgumentException("file has no audio track")
            extractor.selectTrack(track)

            val inputFormat = extractor.getTrackFormat(track)
            val mime = inputFormat.getString(MediaFormat.KEY_MIME)
                ?: throw IllegalArgumentException("audio track has no mime type")

            // Ask for float. Decoders are free to ignore this, so what actually
            // came back is read off the output format below rather than assumed.
            inputFormat.setInteger(MediaFormat.KEY_PCM_ENCODING, AudioFormat.ENCODING_PCM_FLOAT)

            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(inputFormat, null, null, 0)
            codec.start()

            var channels = inputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            var sampleRate = inputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var encoding = AudioFormat.ENCODING_PCM_16BIT

            val pcm = ByteArrayOutputStream()
            val info = MediaCodec.BufferInfo()
            var framesWritten = 0
            var truncated = false
            var inputDone = false
            var outputDone = false

            while (!outputDone) {
                if (!inputDone) {
                    val index = codec.dequeueInputBuffer(TIMEOUT_US)
                    if (index >= 0) {
                        val buffer = codec.getInputBuffer(index)!!
                        val size = extractor.readSampleData(buffer, 0)
                        if (size < 0) {
                            codec.queueInputBuffer(
                                index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM
                            )
                            inputDone = true
                        } else {
                            codec.queueInputBuffer(index, 0, size, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }

                when (val index = codec.dequeueOutputBuffer(info, TIMEOUT_US)) {
                    MediaCodec.INFO_TRY_AGAIN_LATER -> Unit
                    MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val outputFormat = codec.outputFormat
                        channels = outputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                        sampleRate = outputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        encoding = if (outputFormat.containsKey(MediaFormat.KEY_PCM_ENCODING)) {
                            outputFormat.getInteger(MediaFormat.KEY_PCM_ENCODING)
                        } else {
                            AudioFormat.ENCODING_PCM_16BIT
                        }
                    }
                    else -> {
                        if (index >= 0) {
                            if (info.size > 0) {
                                val buffer = codec.getOutputBuffer(index)!!
                                buffer.position(info.offset)
                                buffer.limit(info.offset + info.size)
                                val frames = appendFrames(
                                    pcm, buffer, encoding, channels,
                                    if (maxFrames > 0) maxFrames - framesWritten else Int.MAX_VALUE
                                )
                                framesWritten += frames
                            }
                            codec.releaseOutputBuffer(index, false)
                            if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                                outputDone = true
                            }
                            if (maxFrames > 0 && framesWritten >= maxFrames && !outputDone) {
                                truncated = true
                                outputDone = true
                            }
                        }
                    }
                }
            }

            return mapOf(
                "pcm" to pcm.toByteArray(),
                "channels" to channels,
                "sampleRate" to sampleRate,
                "truncated" to truncated
            )
        } finally {
            try {
                codec?.stop()
            } catch (_: Exception) {
            }
            codec?.release()
            extractor.release()
        }
    }

    /**
     * Writes [source] out as little endian float32, converting from 16 or 8 bit
     * when that is what the decoder produced, and stops at [frameBudget].
     *
     * Returns how many frames were written.
     */
    private fun appendFrames(
        sink: ByteArrayOutputStream,
        source: ByteBuffer,
        encoding: Int,
        channels: Int,
        frameBudget: Int
    ): Int {
        if (frameBudget <= 0 || channels <= 0) return 0
        val input = source.order(ByteOrder.nativeOrder())
        val bytesPerSample = when (encoding) {
            AudioFormat.ENCODING_PCM_FLOAT -> 4
            AudioFormat.ENCODING_PCM_8BIT -> 1
            else -> 2
        }
        val available = input.remaining() / (bytesPerSample * channels)
        val frames = minOf(available, frameBudget)
        if (frames <= 0) return 0

        val out = ByteBuffer.allocate(frames * channels * 4).order(ByteOrder.LITTLE_ENDIAN)
        val samples = frames * channels
        when (encoding) {
            AudioFormat.ENCODING_PCM_FLOAT ->
                for (i in 0 until samples) out.putFloat(input.getFloat())
            AudioFormat.ENCODING_PCM_8BIT ->
                // 8 bit PCM is unsigned, the same as it is in a WAV.
                for (i in 0 until samples) {
                    out.putFloat(((input.get().toInt() and 0xFF) - 128) / 128.0f)
                }
            else ->
                for (i in 0 until samples) out.putFloat(input.getShort() / 32768.0f)
        }
        sink.write(out.array())
        return frames
    }

    private fun audioTrackOf(extractor: MediaExtractor): Int? {
        for (track in 0 until extractor.trackCount) {
            val mime = extractor.getTrackFormat(track).getString(MediaFormat.KEY_MIME)
            if (mime != null && mime.startsWith("audio/")) return track
        }
        return null
    }

    private companion object {
        const val TIMEOUT_US = 10_000L
    }
}
