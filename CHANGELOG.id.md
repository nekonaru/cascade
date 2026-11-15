# Changelog

## v0.1.0

Rilis publik pertama Cascade.

## Fitur baru

- **Empat topologi jaringan.** Generator Erdos-Renyi, Watts-Strogatz, Barabasi-Albert dan Stochastic Block Model dengan RNG berseed eksplisit.
- **Model rumor berbasis agen.** State Susceptible, Believer, Skeptic dan Recovered, skeptisisme heterogen Beta(2, 5), forgetting, dan aturan transisi per langkah yang didokumentasikan di `docs/model.md`.
- **Strategi seed.** Seeding acak, hub, dan per komunitas untuk penyebar awal.
- **Intervensi.** Klarifikasi dini atau terlambat dengan jangkauan tetap, literacy boost populasi-wide, dan pemblokiran akun seed hub top-k sejak awal.
- **Analisis Monte Carlo.** Runner replikasi dengan rata-rata, standar deviasi dan CI 95%, plus metrik jangkauan, puncak aktivitas, waktu menuju puncak dan pertumbuhan awal.
- **Sweep parameter.** Grid sweep dengan heatmap rata-rata jangkauan akhir.
- **Visualisasi.** Kurva state, kurva rata-rata dengan pita, perbandingan seed dan klarifikasi, heatmap sweep, ekspor CSV dan JSON, dan output animasi GIF.
- **Konfigurasi TOML.** Run penuh dari `config/default.toml`, dengan skrip untuk single run, studi Monte Carlo, benchmark dan animasi.

## Peningkatan

- **Reproducibility.** Stream StableRNG dipisah per kebutuhan (jaringan, seed, model); seed sama, history sama.
- **Adjacency deterministik.** Daftar tetangga diurutkan agar urutan iterasi tidak bergantung hash atau urutan alokasi.

## Perbaikan bug

- Tidak ada. Rilis pertama.
