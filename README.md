# Meditation

This is a meditation timer. Minimalistic, reliable, and truly elegant.

## Features
- Simple, elegant, and intuitive
- No distractions; only the essential features
- Reliable volume adjustment independent of system volume
- Reliable countdown timer
- Beautiful assortment of bell and gong sounds
- Free and open-source software

## About
This project was started with the goal of making a truly minimalistic no-fuss countdown timer for meditation, with a clean UI and no clutter, reflecting the actual purpose of meditation.

Another goal was to have the volume of the notification bells be consistent and reliable.
In other apps, the volume is tied to the system volume, implemented either as using the system volume setting directly, or as a modifier thereof.
Both approaches are flawed and will lead to inconsistent volumes if the system volume changes or if you had forgotten to set it to the desired level before starting the timer.
With my approach the app will use a configurable absolute value, so that the sounds play consistently at the same volume no matter what.
I found that having the reassurance of the sounds being reliable is very important for a worry-free and fiddle-free meditation experience. Just press the start button and go.

Another issue to solve was the reliability of the timer timeout event happening at exactly the right time.
For whatever reason, this is a ridiculously complex problem on mobile devices due to the continuous "improvements" to extend battery life.
This app will make use of all possible tricks to ensure it is reliable. What I finally found to be working was the combination of these techniques:
- Setting a system alarm with the highest possible priority
- Starting a foreground service to keep the app running
- Disabling battery optimization
- (optional) Keep screen on

This might or might not be friendly to battery life.
But once again I decided that reliability is of extreme importance to a meditation tool in order to eliminate all possible worries about the timer not behaving correctly.

## Sounds attribution
- bell_burma: https://freesound.org/people/LozKaye/sounds/94024/
- bell_indian: https://soundbible.com/1690-Indian-Bell.html
- bell_meditation: https://freesound.org/people/fauxpress/sounds/42095/
- bell_singing: https://freesound.org/people/ryancacophony/sounds/202017/
- bell_zen: https://soundbible.com/1491-Zen-Buddhist-Temple-Bell.html
- bowl_singing_big: https://freesound.org/people/Garuda1982/sounds/116315/
- bowl_singing: https://freesound.org/people/juskiddink/sounds/122647/
- bowl_tibetan: https://freesound.org/people/arnaud%20coutancier/sounds/47665/
- gong_bodhi: https://github.com/yuttadhammo/BodhiTimer (unclear origin)
- gong_generated: https://freesound.org/people/nkuitse/sounds/18654/
- gong_metal: https://soundbible.com/2062-Metal-Gong-1.html
- gong_watts: https://github.com/yuttadhammo/BodhiTimer (unclear origin; possibly from the "Alan Watts Guided Meditation" audio)
