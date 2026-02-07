# RIP
[Spotify killed their API](https://developer.spotify.com/blog/2026-02-06-update-on-developer-access-and-platform-security)

---

# Spotify Ad Ignorer

Spotify Ad Ignorer is for use with the windows desktop version of Spotify

## What it does

When Spotify plays an ad, Spotify Ad Ignorer will automatically restart Spotify

If Spotify is the active application, it will instead mute Spotify until the ad has finished or the user clicks away from Spotify to trigger the restart

## How it works

Simply run Spotify Ad Ignorer instead of Spotify, Spotify Ad Ignorer will then launch Spotify and restart when an ad plays

Uses the [Spotify API](https://developer.spotify.com/) to detect when an ad is playing

Upon running Spotify Ad Ignorer you will be prompted to create an API app

## Notes

If you have crossfade enabled in Spotify, it will crossfade into an ad & restart as soon as (or just before) the ad starts playing, this can cause a sudden cut-off of the last few seconds of music

All config settings are stored in the registry `HKCU\Software\Spotify Ad Ignorer`
