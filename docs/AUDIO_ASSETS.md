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
