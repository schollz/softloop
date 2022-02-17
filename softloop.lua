-- softloop demo

function init()
  local softloop_=include("softloop/lib/softloop")
  softloop=softloop_:new()
  softloop:load_file("/home/we/dust/audio/jungle-sounds-spliced/004_c__Drum_Beat_172_beats127_bpm_-_NEWJUNGLE_Zenhiser_keyc_bpm172.wav")
end
