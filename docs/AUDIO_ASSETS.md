# Game audio provenance

## Music

- Track: **Morning Puzzle**, Suno v5.5.
- Creator/account: the user's `dannyluponenko` Suno account.
- Source: https://suno.com/song/625dab8f-de48-496a-a245-71d4bd275fc7
- Downloaded through Suno's normal Chrome download UI on 2026-09-06 while the
  account showed **Pro Plan** and 27 included downloads available. One included
  download was used; no purchase, upgrade, or new song generation occurred.
- Suno's current paid-plan guidance explicitly grants commercial use for songs
  downloaded while subscribed, including use in video games:
  https://help.suno.com/en/articles/9601665
  https://help.suno.com/en/articles/13614785
- Original local download: `/Users/daniel/Downloads/Morning Puzzle.m4a`.
- Source duration: 105.72 seconds, stereo, 48 kHz Opus.
- Bundled asset: `App/Resources/Audio/bookshop-theme.m4a`, transcoded to AAC,
  44.1 kHz stereo, 128 kbps for iOS playback; normalized to a quiet -23 LUFS
  target with a -3 dB true-peak ceiling and short edge fades.

The existing source prompt describes a no-vocals instrumental for this Sudoku
book game: quiet acoustic guitar, piano, marimba, light bells and delicate
percussion. No third-party song, voice, or artist likeness was uploaded here.

## Effects

Game effects are generated locally from short, original tone/noise envelopes,
not downloaded samples. No third-party attribution or network service is
required for their playback. Master, Music, and Sound effects levels are local
player preferences; zero is mute. Audio respects Silent Mode and pauses when
the app is inactive or a rewarded video is presented.

## Additional production-polish cues — 2026-09-06

Created through the user's existing Suno **Pro Plan**, verified in the account
page before generating. The plan displayed commercial use for newly made
songs, 2,500 credits and 26 included downloads. Five generation requests
created ten candidates; four included downloads were used. No purchase,
upgrade, auto-reload change, artist imitation, voice upload or public publish
action was performed. The initial short Red Ink candidates were not bundled.

| Cue | Source song | Bundled resource |
| --- | --- | --- |
| Quiet Margins | https://suno.com/song/1a231508-ac64-4d1f-9c8d-a16e64828340 | `quiet-margins.m4a` |
| Rainy Margins | https://suno.com/song/676b3795-1653-4c2f-a827-2dd49d89b922 | `rainy-margins.m4a` |
| Red Ink Deadline — Gameplay Loop | https://suno.com/song/a7462d8c-8888-4822-8761-8ad42837c3cc | `red-ink-deadline.m4a` |
| The Final Draft | https://suno.com/song/ebf9ce34-9d8f-445d-885e-88ab1e3519dc | `final-draft.m4a` |

Prompts requested original instrumental acoustic/chamber game music: quiet
felt piano and nylon guitar; reflective clarinet and vibraphone; ticking
prepared-piano Boss tension; and a more determined final-Boss pizzicato/brass
motif. All excluded singing, spoken words, choir, huge reverb and explosive
percussion. Full prompts remain with the songs in the user's Suno workspace.

Downloads remain unchanged in `/Users/daniel/Downloads/` under their song
titles. The source M4A containers hold stereo 48kHz Opus. App assets are
stereo 44.1kHz AAC at 128kbps, normalized to -23 LUFS / -3dBTP / LRA7.
For each new cue a 1.25-second tail/head crossfade is placed at the loop seam;
the resulting file starts at source time1.25 and continues through that seam.
This removes a hard waveform cut without a silent gap or runtime network use.
The original Morning Puzzle asset is preserved.

`GameMusicCue` assigns three Book moods and two Boss cues (regular/final).
It does not claim19 individually composed Boss songs. Playback crossfades
between cues using at most two music players and stops both for mute, ads,
backgrounding, interruptions and disconnected headphones.

Effects now use dry multi-mode wood/paper contact, shuffled fibre noise and
short mallet notes instead of the earlier hollow single-tone envelopes.
They remain original local synthesis, with tested PCM headroom and zero
start/end samples. Speaker balance and subjective musical quality require
listening; decoder/PCM tests alone are not that proof.

The page-turn cue is separately band-limited: a soft lifted edge, flexible
sheet movement, two restrained crease-pressure accents and a quiet final
contact over 460 ms. Cascaded noise filters replace its former bright repeated
grain; no recorded samples, pitched oscillator or electronic sweep are used.
Measured full-cue energy above 3 kHz fell from 55.4% to 2.8%, with zero-valued
edges and a 0.374 full-scale peak. Focused PCM tests guard its warm spectrum,
headroom and separated lift/body/landing contour. All other effect waveforms
are unchanged. These are signal checks, not a claim of human listening approval.
