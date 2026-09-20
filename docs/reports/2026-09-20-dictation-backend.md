# Zao dictation backend verification

Date: 2026-09-20

## Build facts

- The unified tree pins nixpkgs `whisper-cpp` 1.8.3, not 1.9.2 as the earlier design research reported.
- The package builds with CUDA for Zao's RTX 3060 Laptop GPU at compute capability 8.6.
- The model input is `ggml-large-v3-turbo.bin` from the official `ggerganov/whisper.cpp` Hugging Face repository.
- The model file SHA-256 is `1fc70f774d38eb169993ac391eea357ef47c88757ef72ee5943879b7e8e2bc69`.
- The package removes the upstream unauthenticated `/load` route. The route can otherwise replace the active model from any readable path.
- `tsnet-proxy` permits interactive browser approval when a service has no auth key. Existing services keep their auth-key behavior.

## Audio-context measurement

The benchmark used the human speech in whisper.cpp's `samples/jfk.wav`. It tested clips of 3 seconds, 6 seconds, and the complete 11-second sentence. Each result is the median of two warm requests over loopback.

| Clip | Audio context | Median | Transcript result |
| --- | ---: | ---: | --- |
| 3 s | full | 0.205 s | Correct clipped phrase. |
| 3 s | 256 | 2.319 s | Repeated the phrase three times. |
| 3 s | 384 | 0.739 s | Incorrect and unstable. |
| 3 s | 512 | 0.078 s | Correct clipped phrase. |
| 3 s | 768 | 0.110 s | Correct clipped phrase. |
| 6 s | full | 0.226 s | Correct clipped phrase. |
| 6 s | 256 | 2.572 s | Truncated and unstable. |
| 6 s | 384 | 1.459 s | Truncated. |
| 6 s | 512 | 0.100 s | Added `is` at the clipped ending. |
| 6 s | 768 | 0.133 s | Added `is` at the clipped ending. |
| 11 s | full | 0.262 s | Exact sentence. |
| 11 s | 256 | 2.696 s | Truncated and repeated. |
| 11 s | 384 | 2.746 s | Incorrect. |
| 11 s | 512 | 0.135 s | Exact sentence. |
| 11 s | 768 | 0.167 s | Exact sentence. |

The short-sample result initially favored 512. A 33-second sample then disproved that choice. The sample concatenated the complete human-spoken sentence three times to cross Whisper's 30-second window.

| Audio context | 33-second latency | Transcript result |
| ---: | ---: | --- |
| full | 0.650 s | All three sentences were exact. |
| 512 | 0.288 s | Lost most of the second and third sentences. |
| 768 | 0.667 s | Repeated the sentence six times. |
| 1024 | 0.931 s | Repeated fragments many times. |
| 1280 | 0.963 s | Repeated the sentence eight times. |
| 1500 | 0.652 s | All three sentences were exact. |

The fixed audio context is 1500. It preserves long-take accuracy. The 11-second request took 0.262 seconds over loopback. From Myoko through the tailnet, the first request after restart took 0.703 seconds. Final verification after the persistent deployment took 0.562 seconds.

## Live resource use

The service loaded the model through the CUDA backend with flash attention enabled. The process held 1,896 MiB of GPU memory while idle. Total GPU use was 4,797 MiB of 6,144 MiB because two existing Kokoro workers and Sunshine already used the GPU.

This leaves about 1.3 GiB free in the measured idle state, not the more than 4 GiB assumed in the design record. Dictation worked beside those services, but a heavy game has less headroom than the design expected.

## Verification state

Verified on the test-activated Zao candidate:

- `dictation-backend.service` stays active.
- `whisper-server` listens only on `127.0.0.1:8178`.
- CUDA, flash attention, the FP16 model, and the English language setting are active.
- `POST /v1/audio/transcriptions` accepts multipart WAV input and returns a top-level `text` string.
- `POST /load` returns 404.
- Sunshine stays active.
- The journal contains file names, timings, and state. It does not contain transcript text.

Tailnet verification completed after interactive browser approval:

- The tsnet node is online as `dictate.hummingbird-lake.ts.net`.
- `https://dictate.hummingbird-lake.ts.net/v1/audio/transcriptions` returned the exact sentence from Myoko in 0.562 seconds after the persistent deployment.
- `https://dictate` fails certificate validation. Tailscale issues the certificate only for the full MagicDNS name.
- The client must use `https://dictate.hummingbird-lake.ts.net/v1/audio/transcriptions`.
- The backend remains unreachable at Zao's LAN address on port 8178.
