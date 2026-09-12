# Historical Meshy performance benchmarks — September 12, 2026

These retained single-run measurements explain the choice of untextured T2. They
are not current instructions or latency guarantees. The experimental benchmark
runner has been removed. See [backend setup](BACKEND.md) for supported commands.

## Meshy-6 polygon sweep

The experiment submitted four jobs sequentially with the same banana image,
requesting 100, 200, 500, and 1,000 triangular faces. It polled every three seconds,
downloaded the GLBs and counted their triangles. Observed ready time includes polling
delay; provider processing excludes local submission and download time.

Quick live comparison on 2026-09-12: banana sample, `meshy-6`, standard model,
remeshing enabled, no textures, triangle topology, GLB output. All four jobs succeeded.

| Target faces | Actual triangles | Provider processing | Observed ready time | GLB bytes |
|---|---|---|---|---|
| 100 | 104 | 38.162 s | 43.988 s | 10,292 |
| 200 | 210 | 40.473 s | 47.450 s | 16,532 |
| 500 | 524 | 47.242 s | 54.376 s | 32,404 |
| 1,000 | 1,038 | 44.526 s | 46.684 s | 51,716 |

Queue times were 3–4 ms. A tenfold target increase took only 1.17 times as long to
process; the 1,000-face job was faster than the 500-face job. This sample does not
show proportional scaling, and variation between runs prevents attributing these
differences solely to polygon count. All downloaded GLBs passed header checks and
triangle counting; visual quality and Godot import were not tested in this comparison.
Meshy's [API documentation](https://docs.meshy.ai/en/api/image-to-3d) describes the
standard-model target as a remeshing/decimation target, which is consistent with
generation taking substantial time even at low output counts.

### Faster model comparison

One T2 run on the same banana sample on 2026-09-12 succeeded in **2.030 seconds of
provider processing**, compared with **44.526 seconds** for the earlier Meshy-6
1,000-face run (approximately 22 times faster). Queue time was 6 ms; submission
took 0.924 seconds. Completion was observed at 4.827 seconds with three-second
polling, and the GLB was downloaded by 5.038 seconds. Output: 1,108 triangles,
20,704 bytes. The GLB header and triangle count were checked; visual quality and
Godot import remain unverified. This is a single-run comparison, not a guaranteed latency.

### T2 polygon sweep results

A subsequent four-job sweep on 2026-09-12 used the same banana image, T2 Smart
Topology, no textures, and GLB output. Each target was submitted once, sequentially.

| Target faces | Actual triangles | Provider processing | Observed ready time | GLB bytes |
|---|---|---|---|---|
| 100 | 108 | 1.896 s | 4.771 s | 2,672 |
| 200 | 218 | 1.901 s | 4.819 s | 4,652 |
| 500 | 552 | 2.620 s | 4.734 s | 10,668 |
| 1,000 | 1,076 | 2.841 s | 4.706 s | 20,128 |

All jobs succeeded and all GLBs downloaded and passed header/triangle checks.
Queue time was 3–5 ms. A tenfold polygon target increase took 1.50 times as long to
process in this sweep; timings did not scale proportionally. Compared with the earlier
Meshy-6 sweep, T2 processing was approximately 16–21 times faster. Each complete
command, including three-second polling and download, took 4.91–5.06 seconds.
These are single-run observations; visual quality and Godot import were not tested.

### T2 with a shared texture style

This experiment enabled 2K textures with PBR maps disabled for the same four polygon
targets. Reported provider processing includes both geometry and texture work; it
does not isolate the texture phase. The current pipeline disables texturing.

Live results on 2026-09-12, same banana image and exact prompt `hand-drawing style`:

| Target faces | Actual triangles | Textured processing | Earlier geometry-only processing | GLB bytes |
|---|---|---|---|---|
| 100 | 108 | 64.382 s | 1.896 s | 2,400,240 |
| 200 | 218 | 78.150 s | 1.901 s | 2,267,292 |
| 500 | 552 | 55.911 s | 2.620 s | 2,210,764 |
| 1,000 | 1,087 | 58.833 s | 2.841 s | 2,095,932 |

All four jobs succeeded. Each GLB passed header/triangle checks and contains an embedded
image texture referenced by a base-color material. Queue times were 3–4 ms. Textured
processing took about 56–78 seconds versus 2–3 seconds for geometry alone, with no
proportional scaling by polygon count in this sample. These are single runs, not
isolated texture-phase measurements. Art-style fidelity and Godot import remain unverified.
