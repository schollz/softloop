-- softloop demo

function init()
  local softloop_=include("softloop/lib/softloop")
  softloop=softloop_:new()
  -- softloop:load_file(_path.code.."softloop/samples/SO_ORIC_120_drum_loop_indiegroove__beats32_bpm120.wav")
  -- local breaks={24303,35857,49624,72054,96720,108824,120272,131781,144850,168633,181822,216214,228068,241646,265158,289329,301595,312277,323779,336851,360177,371454,383976,408786,421071,433599,457490,473648,492056,504243,515867,528160,551646,599763,612589,625329,648940,672462,684477,697057,707554,731226,744328,757239}

  -- local fname="/home/we/dust/audio/beats-spliced/015_a__Drum_Beat_174_beats64_bpm_-_RECOILDRUMBASS_Zenhiser_bpm174.wav"
  -- softloop:load_file(fname)
  -- local breaks=nil
  -- norns.system_cmd("aubioonset -i "..fname.." -O hfc -f -M 0.34482758 -s -60 -t 0.7 -B 256 -H 256 -T samples",function(x)
  --   local bs={}
  --   for s in x:gmatch("%S+") do
  --     table.insert(bs,tonumber(s))
  --   end
  --   breaks=bs
  -- end)
  -- clock.run(function()
  --   while true do
  --     clock.sync(8)
  --     if breaks~=nil then
  --       local new_pos=softloop.start+(breaks[math.random(#breaks)])/48000
  --       print("break "..new_pos)
  --       softloop:set_pos(new_pos)
  --     end
  --   end
  -- end)
end
